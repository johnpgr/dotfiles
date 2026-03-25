use std::error::Error;
use std::ptr::NonNull;
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use block2::RcBlock;
use objc2_core_foundation::CFRunLoopRun;
use objc2_foundation::{
    NSDistributedNotificationCenter, NSNotification, NSUserDefaults, ns_string,
};

use crate::state::{Mode, ThemeStateWriter};

const APPLE_INTERFACE_THEME_CHANGED_NOTIFICATION: &str = "AppleInterfaceThemeChangedNotification";
const APPLE_INTERFACE_STYLE_KEY: &str = "AppleInterfaceStyle";
const POLL_INTERVAL: Duration = Duration::from_secs(2);

pub fn run(writer: ThemeStateWriter) -> Result<(), Box<dyn Error>> {
    let writer = Arc::new(writer);
    sync_current_mode(&writer);

    thread::spawn({
        let writer = Arc::clone(&writer);
        move || loop {
            thread::sleep(POLL_INTERVAL);
            sync_current_mode(&writer);
        }
    });

    let center = NSDistributedNotificationCenter::defaultCenter();
    let observer_block = RcBlock::new({
        let writer = Arc::clone(&writer);
        move |_notification: NonNull<NSNotification>| {
            sync_current_mode(&writer);
        }
    });

    let observer = unsafe {
        center.addObserverForName_object_queue_usingBlock(
            Some(ns_string!(APPLE_INTERFACE_THEME_CHANGED_NOTIFICATION)),
            None,
            None,
            &observer_block,
        )
    };

    let _keep_alive = (center, observer_block, observer);
    CFRunLoopRun();
    Ok(())
}

fn sync_current_mode(writer: &ThemeStateWriter) {
    let mode = current_mode();

    if let Err(err) = writer.write_if_changed(mode) {
        eprintln!("failed to write theme state: {err}");
    }
}

fn current_mode() -> Mode {
    let defaults = NSUserDefaults::standardUserDefaults();
    let _ = defaults.synchronize();
    let style = defaults.stringForKey(ns_string!(APPLE_INTERFACE_STYLE_KEY));
    let style = style.as_ref().map(|value| value.to_string());
    Mode::from_macos_style(style.as_deref())
}
