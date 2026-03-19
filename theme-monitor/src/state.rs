use std::env;
use std::fmt;
use std::fs;
use std::io;
use std::path::PathBuf;
use std::process;
use std::sync::Mutex;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Mode {
    Dark,
    Light,
}

impl Mode {
    pub fn from_portal_value(value: u32) -> Option<Self> {
        match value {
            1 => Some(Self::Dark),
            2 => Some(Self::Light),
            _ => None,
        }
    }

    #[cfg_attr(not(target_os = "macos"), allow(dead_code))]
    pub fn from_macos_style(style: Option<&str>) -> Self {
        match style {
            Some("Dark") => Self::Dark,
            _ => Self::Light,
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Dark => "dark",
            Self::Light => "light",
        }
    }
}

impl fmt::Display for Mode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

pub struct ThemeStateWriter {
    path: PathBuf,
    last_written: Mutex<Option<Mode>>,
}

impl ThemeStateWriter {
    pub fn new() -> io::Result<Self> {
        let path = theme_state_path()?;
        let last_written = read_mode_from_disk(&path);
        Ok(Self {
            path,
            last_written: Mutex::new(last_written),
        })
    }

    pub fn write_if_changed(&self, mode: Mode) -> io::Result<bool> {
        let mut last_written = self
            .last_written
            .lock()
            .map_err(|_| io::Error::other("theme state writer mutex poisoned"))?;

        if last_written.as_ref() == Some(&mode) && read_mode_from_disk(&self.path) == Some(mode) {
            return Ok(false);
        }

        let parent = self
            .path
            .parent()
            .ok_or_else(|| io::Error::other("theme state path has no parent directory"))?;
        write_atomically(&self.path, mode.as_str(), parent)?;

        println!("Switching to {mode} mode...");
        *last_written = Some(mode);
        Ok(true)
    }
}

fn theme_state_path() -> io::Result<PathBuf> {
    Ok(dotfiles_dir()?.join(".theme_state"))
}

fn dotfiles_dir() -> io::Result<PathBuf> {
    let home = env::var_os("HOME")
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "HOME is not set"))?;
    Ok(PathBuf::from(home).join(".dotfiles"))
}

fn write_atomically(path: &std::path::Path, content: &str, parent: &std::path::Path) -> io::Result<()> {
    let filename = path
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or_else(|| io::Error::other("path has no valid filename"))?;
    let temp_path = parent.join(format!(".{filename}.tmp-{}", process::id()));

    fs::write(&temp_path, content)?;
    fs::rename(&temp_path, path)?;
    Ok(())
}

fn read_mode_from_disk(path: &std::path::Path) -> Option<Mode> {
    let content = fs::read_to_string(path).ok()?;
    match content.trim() {
        "dark" => Some(Mode::Dark),
        "light" => Some(Mode::Light),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::Mode;

    #[test]
    fn portal_value_mapping() {
        assert_eq!(Mode::from_portal_value(1), Some(Mode::Dark));
        assert_eq!(Mode::from_portal_value(2), Some(Mode::Light));
        assert_eq!(Mode::from_portal_value(0), None);
        assert_eq!(Mode::from_portal_value(9), None);
    }

    #[test]
    fn macos_style_mapping() {
        assert_eq!(Mode::from_macos_style(Some("Dark")), Mode::Dark);
        assert_eq!(Mode::from_macos_style(Some("Light")), Mode::Light);
        assert_eq!(Mode::from_macos_style(None), Mode::Light);
    }
}
