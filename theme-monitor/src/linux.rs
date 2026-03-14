use std::error::Error;

use zbus::blocking::Connection;
use zbus::proxy;
use zbus::zvariant::{OwnedValue, Value};

use crate::state::{Mode, ThemeStateWriter};

const APPEARANCE_NAMESPACE: &str = "org.freedesktop.appearance";
const COLOR_SCHEME_KEY: &str = "color-scheme";

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
    let connection = Connection::session()?;
    let proxy = SettingsProxyBlocking::new(&connection)?;

    sync_current(&proxy, &writer)?;

    let signals = proxy.receive_setting_changed()?;
    for signal in signals {
        let args = signal.args()?;
        if *args.namespace() != APPEARANCE_NAMESPACE || *args.key() != COLOR_SCHEME_KEY {
            continue;
        }

        apply_value(&writer, args.value().to_owned());
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

    use super::decode_mode;
    use crate::state::Mode;

    #[test]
    fn decodes_nested_portal_variants() {
        let value = Value::new(Value::new(Value::new(2_u32)));
        assert_eq!(decode_mode(&value), Some(Mode::Light));
    }
}
