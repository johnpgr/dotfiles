# ~/.profile
# Linux standard file for login shell environment variables

# Added by Toolbox App
export PATH="$PATH:/home/joao/.local/share/JetBrains/Toolbox/scripts"

# Graphic drivers (Mesa / NVIDIA / WSL D3D12)
export GALLIUM_DRIVER=d3d12
export LIBVA_DRIVER_NAME=d3d12
export MESA_LOADER_DRIVER_OVERRIDE=d3d12
export WEBKIT_DISABLE_DMABUF_RENDERER=1
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_D3D12_DEFAULT_ADAPTER_NAME="NVIDIA"

# Editor configuration (conditional based on SSH)
if [ -n "$SSH_CONNECTION" ]; then
    export EDITOR='vim'
else
    export EDITOR='nvim'
fi

# CPU Architecture flag
export ARCHFLAGS="-arch $(uname -m)"

# Android SDK configurations
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

# PATH extensions (added sequentially to ensure clean precedence)
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export PATH="$PATH:$HOME/.local/share/bob/nvim-bin"
export PATH="$PATH:$HOME/.local/bin"
