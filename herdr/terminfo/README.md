Herdr uses `xterm-256color` inside panes, but the system entry can omit
`Smulx`, causing Neovim to fall back to straight underlines.

Compile the override after installing these dotfiles:

```sh
mkdir -p "$HOME/.local/share/herdr/terminfo"
tic -x -o "$HOME/.local/share/herdr/terminfo" "$HOME/.dotfiles/herdr/terminfo/xterm-256color.terminfo"
```

Start a new fish shell inside Herdr, then restart Neovim. The fish configuration
selects this database only inside Herdr panes using `xterm-256color`.

Herdr can still lose underline colors and temporarily flatten curls while
displaying overlays; those require changes to Herdr's renderer.
