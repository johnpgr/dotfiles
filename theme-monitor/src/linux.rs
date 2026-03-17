use std::error::Error;
use std::io::{self, BufRead, BufReader};
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;

use zbus::blocking::Connection;
use zbus::proxy;
use zbus::zvariant::{OwnedValue, Value};

use crate::state::{Mode, ThemeStateWriter};

const APPEARANCE_NAMESPACE: &str = "org.freedesktop.appearance";
const COLOR_SCHEME_KEY: &str = "color-scheme";
const GSETTINGS_BIN: &str = "/usr/bin/gsettings";
const GNOME_INTERFACE_SCHEMA: &str = "org.gnome.desktop.interface";
const GTK_THEME_KEY: &str = "gtk-theme";

#[proxy(
    interface = "org.freedesktop.portal.Settings",
    default_service = "org.freedesktop.portal.Desktop",
    default_path = "/org/freedesktop/portal/desktop"
)]
trait Settings {
    fn read(&self, namespace: &str, key: &str) -> zbus::Result<OwnedValue>;

    #[zbus(signal)]
    fn setting_changed(&self, namespace: &str, key: &str, value: OwnedValue) -> zbus::Result<()>;
}

pub fn run(writer: ThemeStateWriter) -> Result<(), Box<dyn Error>> {
    match run_portal(&writer) {
        Ok(()) => Ok(()),
        Err(err) if is_portal_setting_not_found(err.as_ref()) => {
            eprintln!("portal color-scheme unavailable; falling back to gsettings");
            run_gsettings(&writer)
        }
        Err(err) => Err(err),
    }
}

fn run_portal(writer: &ThemeStateWriter) -> Result<(), Box<dyn Error>> {
    let connection = Connection::session()?;
    let proxy = SettingsProxyBlocking::new(&connection)?;

    sync_current(&proxy, writer)?;

    let signals = proxy.receive_setting_changed()?;
    for signal in signals {
        let args = signal.args()?;
        if *args.namespace() != APPEARANCE_NAMESPACE || *args.key() != COLOR_SCHEME_KEY {
            continue;
        }

        thread::sleep(Duration::from_millis(300));
        if let Err(err) = sync_current(&proxy, writer) {
            if is_portal_setting_not_found(err.as_ref()) {
                eprintln!("portal color-scheme became unavailable; keeping current theme state");
                continue;
            }

            return Err(err);
        }
    }

    Err("theme monitor signal stream ended unexpectedly".into())
}

fn sync_current(
    proxy: &SettingsProxyBlocking<'_>,
    writer: &ThemeStateWriter,
) -> Result<(), Box<dyn Error>> {
    let value = proxy.read(APPEARANCE_NAMESPACE, COLOR_SCHEME_KEY)?;
    apply_value(writer, value);
    Ok(())
}

fn run_gsettings(writer: &ThemeStateWriter) -> Result<(), Box<dyn Error>> {
    sync_current_gsettings(writer)?;

    let mut child = Command::new(GSETTINGS_BIN)
        .arg("monitor")
        .arg(GNOME_INTERFACE_SCHEMA)
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()?;

    let stdout = child
        .stdout
        .take()
        .ok_or_else(|| io::Error::other("failed to capture gsettings monitor output"))?;

    let reader = BufReader::new(stdout);
    for line in reader.lines() {
        line?;
        thread::sleep(Duration::from_millis(300));

        if let Err(err) = sync_current_gsettings(writer) {
            eprintln!("failed to sync gsettings theme state: {err}");
        }
    }

    let status = child.wait()?;
    Err(format!("gsettings monitor exited with status {status}").into())
}

fn sync_current_gsettings(writer: &ThemeStateWriter) -> Result<(), Box<dyn Error>> {
    let mode = read_gsettings_mode()?
        .ok_or_else(|| io::Error::other("unable to determine theme mode from gsettings"))?;
    writer.write_if_changed(mode)?;
    Ok(())
}

fn read_gsettings_mode() -> Result<Option<Mode>, Box<dyn Error>> {
    if let Some(value) = gsettings_get(COLOR_SCHEME_KEY)? {
        if let Some(mode) = decode_gsettings_color_scheme(&value) {
            return Ok(Some(mode));
        }
    }

    if let Some(value) = gsettings_get(GTK_THEME_KEY)? {
        return Ok(decode_gtk_theme(&value));
    }

    Ok(None)
}

fn gsettings_get(key: &str) -> Result<Option<String>, Box<dyn Error>> {
    let output = Command::new(GSETTINGS_BIN)
        .arg("get")
        .arg(GNOME_INTERFACE_SCHEMA)
        .arg(key)
        .output()?;

    if !output.status.success() {
        return Ok(None);
    }

    Ok(Some(String::from_utf8_lossy(&output.stdout).trim().to_owned()))
}

fn decode_gsettings_color_scheme(value: &str) -> Option<Mode> {
    match value.trim().trim_matches('\'') {
        "prefer-dark" => Some(Mode::Dark),
        "default" | "prefer-light" => Some(Mode::Light),
        _ => None,
    }
}

fn decode_gtk_theme(value: &str) -> Option<Mode> {
    let value = value.trim().trim_matches('\'');
    if value.is_empty() {
        return None;
    }

    if value.to_ascii_lowercase().contains("dark") {
        return Some(Mode::Dark);
    }

    Some(Mode::Light)
}

fn is_portal_setting_not_found(err: &dyn Error) -> bool {
    err.to_string()
        .contains("org.freedesktop.portal.Error.NotFound")
}

fn apply_value(writer: &ThemeStateWriter, value: OwnedValue) {
    let Some(mode) = decode_mode(&value) else {
        eprintln!("failed to decode portal color-scheme value");
        return;
    };

    if let Err(err) = writer.write_if_changed(mode) {
        eprintln!("failed to write theme state: {err}");
    }
}

fn decode_mode(value: &Value<'_>) -> Option<Mode> {
    match value {
        Value::Value(inner) => decode_mode(inner.as_ref()),
        _ => value
            .downcast_ref::<u32>()
            .ok()
            .and_then(Mode::from_portal_value),
    }
}

#[cfg(test)]
mod tests {
    use zbus::zvariant::Value;

    use super::{decode_gsettings_color_scheme, decode_gtk_theme, decode_mode};
    use crate::state::Mode;

    #[test]
    fn decodes_nested_portal_variants() {
        let value = Value::new(Value::new(Value::new(2_u32)));
        assert_eq!(decode_mode(&value), Some(Mode::Light));
    }

    #[test]
    fn decodes_gsettings_color_scheme() {
        assert_eq!(decode_gsettings_color_scheme("'prefer-dark'"), Some(Mode::Dark));
        assert_eq!(decode_gsettings_color_scheme("'default'"), Some(Mode::Light));
        assert_eq!(decode_gsettings_color_scheme("'prefer-light'"), Some(Mode::Light));
        assert_eq!(decode_gsettings_color_scheme("'unknown'"), None);
    }

    #[test]
    fn decodes_gtk_theme_name() {
        assert_eq!(decode_gtk_theme("'BreezeDark'"), Some(Mode::Dark));
        assert_eq!(decode_gtk_theme("'Breeze'"), Some(Mode::Light));
        assert_eq!(decode_gtk_theme("''"), None);
    }
}
