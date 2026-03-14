use std::error::Error;
use std::ptr::NonNull;
use std::sync::Arc;

use block2::RcBlock;
use objc2_core_foundation::CFRunLoopRun;
use objc2_foundation::{
    NSDistributedNotificationCenter, NSNotification, NSUserDefaults, ns_string,
};

use crate::state::{Mode, ThemeStateWriter};

const APPLE_INTERFACE_THEME_CHANGED_NOTIFICATION: &str = "AppleInterfaceThemeChangedNotification";
const APPLE_INTERFACE_STYLE_KEY: &str = "AppleInterfaceStyle";

pub fn run(writer: ThemeStateWriter) -> Result<(), Box<dyn Error>> {
    let writer = Arc::new(writer);
    sync_current_mode(&writer);

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
    let defaults = NSUserDefaults::standardUserDefaults();
    let style = defaults.stringForKey(ns_string!(APPLE_INTERFACE_STYLE_KEY));
    let style = style.as_ref().map(|value| value.to_string());
    let mode = Mode::from_macos_style(style.as_deref());

    if let Err(err) = writer.write_if_changed(mode) {
        eprintln!("failed to write theme state: {err}");
    }
}
