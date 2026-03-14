mod state;

#[cfg(target_os = "linux")]
mod linux;
#[cfg(target_os = "macos")]
mod macos;

use std::process::ExitCode;

use state::ThemeStateWriter;

#[cfg(not(any(target_os = "linux", target_os = "macos")))]
compile_error!("theme-monitor only supports Linux and macOS");

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let writer = ThemeStateWriter::new()?;

    #[cfg(target_os = "linux")]
    {
        return linux::run(writer);
    }

    #[cfg(target_os = "macos")]
    {
        return macos::run(writer);
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("{err}");
            ExitCode::from(1)
        }
    }
}
