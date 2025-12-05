#!/usr/bin/env python3

import subprocess
import sys
import os
import re
import time

# Configuration
DOTFILES_DIR = os.path.expanduser("~/.dotfiles")
KITTY_CONF_DIR = os.path.join(DOTFILES_DIR, "kitty")
THEMES_DIR = os.path.join(KITTY_CONF_DIR, "themes")
STATE_FILE = os.path.join(DOTFILES_DIR, ".theme_state")
NVIM_CMD = "nvim"

def set_kitty_theme(mode):
    theme_file = "dark.conf" if mode == "dark" else "light.conf"
    source = os.path.join(THEMES_DIR, theme_file)
    dest = os.path.join(KITTY_CONF_DIR, "theme.conf")
    
    # Update the config link/file for persistence
    try:
        subprocess.run(["cp", source, dest], check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error updating kitty config: {e}")

    # Live reload kitty
    # -a: all windows
    # -c: config file
    try:
        subprocess.run(["kitty", "@", "--to", "unix:@kitty", "set-colors", "-a", "-c", dest], check=False)
    except FileNotFoundError:
        pass # Kitty might not be in path or running

def set_nvim_theme(mode):
    # Find nvim sockets
    # Neovim sockets are usually in $XDG_RUNTIME_DIR/nvim.*.0 or /tmp/nvim*
    # We look for sockets
    sockets = []
    
    # Check XDG_RUNTIME_DIR
    xdg_runtime = os.environ.get("XDG_RUNTIME_DIR")
    if xdg_runtime:
        for f in os.listdir(xdg_runtime):
            if f.startswith("nvim") and f.endswith(".0"):
                 sockets.append(os.path.join(xdg_runtime, f))
    
    # Check /tmp just in case
    try:
        for f in os.listdir("/tmp"):
            if f.startswith("nvim") and f.endswith("0"): # Pattern may vary
                 sockets.append(os.path.join("/tmp", f))
    except FileNotFoundError:
        pass
             
    lua_cmd = f"require('colorscheme').set_theme('{mode}')"
    
    for sock in sockets:
        try:
            # Use --remote-send to execute lua command
            # We wrap in <cmd>...<cr> to ensure it executes from normal mode or similar
            cmd = [NVIM_CMD, "--server", sock, "--remote-send", f"<cmd>lua {lua_cmd}<cr>"]
            subprocess.run(cmd, check=False, capture_output=True)
        except Exception as e:
            print(f"Failed to update nvim {sock}: {e}")

def update_state_file(mode):
    try:
        with open(STATE_FILE, "w") as f:
            f.write(mode)
    except Exception as e:
        print(f"Error writing state file: {e}")

def handle_theme_change(is_dark):
    mode = "dark" if is_dark else "light"
    print(f"Switching to {mode} mode...")
    update_state_file(mode)
    set_kitty_theme(mode)
    set_nvim_theme(mode)

def monitor_dbus():
    # Monitor org.freedesktop.portal.Settings for 'color-scheme' changes
    # This works on modern KDE (Plasma 5.27+, 6.0) and GNOME
    cmd = [
        "dbus-monitor",
        "type='signal',interface='org.freedesktop.portal.Settings',member='SettingChanged'"
    ]
    
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    
    print("Monitoring for theme changes...")
    
    # Initial check might be needed, but let's rely on signals or user trigger for now.
    # Actually, better to check current state at startup.
    check_initial_state()

    try:
        while True:
            line = process.stdout.readline()
            if not line:
                break
            
            # We look for:
            # string "org.freedesktop.appearance"
            # string "color-scheme"
            # variant             uint32 1  (1=dark, 2=light, 0=unknown)
            
            if "org.freedesktop.appearance" in line:
                # The next few lines will contain the key and value
                # We need to parse statefully or just read ahead
                # dbus-monitor output is multi-line
                pass
            
            # A simpler hack for dbus-monitor output parsing without state machine:
            # If we see the signal, we can query the value using `dbus-send` or `gdbus` or `portal-check`
            # to be sure.
            if "SettingChanged" in line:
                # Wait a split second and query the actual state
                time.sleep(0.5) 
                check_initial_state()
                
    except KeyboardInterrupt:
        process.kill()

def check_initial_state(retries=3):
    # Query current state using dbus-send
    # method call time=... sender=... -> destination=... serial=... path=/org/freedesktop/portal/desktop; interface=org.freedesktop.portal.Settings; member=Read
    # string "org.freedesktop.appearance"
    # string "color-scheme"
    
    for attempt in range(retries):
        try:
            # Using gdbus if available (common on Fedora)
            result = subprocess.run([
                "busctl", "--user", "call", 
                "org.freedesktop.portal.Desktop", 
                "/org/freedesktop/portal/desktop", 
                "org.freedesktop.portal.Settings", 
                "Read", "ss", 
                "org.freedesktop.appearance", "color-scheme"
            ], capture_output=True, text=True)
            
            # Output format for busctl: "v" <type> <value>
            # e.g. v u 1
            output = result.stdout.strip()
            if "u 1" in output:
                handle_theme_change(True) # Dark
                return
            elif "u 2" in output:
                handle_theme_change(False) # Light
                return
            else:
                # Default fallback?
                print(f"Unexpected busctl output: {output}")
                
        except FileNotFoundError:
            # Try plasma specific if busctl/portal not working
            print("busctl not found")
            return
        except Exception as e:
            print(f"Error checking state (attempt {attempt+1}): {e}")
        
        # Wait before retry
        if attempt < retries - 1:
            time.sleep(2)

if __name__ == "__main__":
    # Run initial check
    check_initial_state()
    # Start monitor
    monitor_dbus()
