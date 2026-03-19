# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

DISABLE_AUTO_TITLE="true"

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="afowler" # set by `omz`

setopt EXTENDED_HISTORY        # stores timestamps
setopt INC_APPEND_HISTORY      # write commands immediately
setopt SHARE_HISTORY           # share history across terminals
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS


# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zoxide tmux)

source $ZSH/oh-my-zsh.sh

function _wezterm-workspace-name-from-dir() {
  local dir="$1"
  local name

  if [[ "$dir" == "$HOME" ]]; then
    name="home"
  elif [[ "$dir" == "$HOME"/* ]]; then
    name="${dir#$HOME/}"
  else
    name="${dir:t}"
  fi

  name="${name//\//:}"
  print -r -- "$name"
}

function _wezterm-workspace-list() {
  wezterm cli --prefer-mux list --format json 2>/dev/null | jq -r '
    map(select(.workspace != null))
    | sort_by(.workspace)
    | group_by(.workspace)[]
    | ["workspace", .[0].workspace, (.[] | .cwd? // empty | tostring | select(length > 0) | .)][0:3]
    | @tsv
  ' 2>/dev/null
}

function _wezterm-directory-list() {
  local dir workspace
  while IFS= read -r dir; do
    workspace=$(_wezterm-workspace-name-from-dir "$dir")
    printf 'directory\t%s\t%s\n' "$workspace" "$dir"
  done < <(fd -H -d 2 -t d -E .Trash . ~)
}

function _wezterm-workspace-entries() {
  _wezterm-workspace-list
  _wezterm-directory-list
}

function wezterm-workspaces() {
  exec </dev/tty
  exec <&1

  local entry kind workspace target
  entry=$(
    _wezterm-workspace-entries | fzf-tmux -p 55%,60% \
      --no-sort --ansi \
      --delimiter=$'\t' \
      --with-nth=2,3 \
      --border-label ' wezterm ' \
      --prompt '🪟  ' \
      --header '  enter attach/create workspace' \
      --bind 'tab:down,btab:up' \
      --preview 'printf "%s\n" {3}'
  )

  [[ -z "$entry" ]] && return

  IFS=$'\t' read -r kind workspace target <<< "$entry"

  if [[ "$kind" == "workspace" ]]; then
    setsid wezterm start --workspace "$workspace" >/dev/null 2>&1 </dev/null
    return
  fi

  setsid wezterm start --cwd "$target" --workspace "$workspace" >/dev/null 2>&1 </dev/null
}

zle     -N             wezterm-workspaces
bindkey -M emacs '\es' wezterm-workspaces
bindkey -M vicmd '\es' wezterm-workspaces
bindkey -M viins '\es' wezterm-workspaces

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# Compilation flags
export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias ls='ls -C -t -U -A -p --color=auto'
alias grep='grep --color=auto'
alias vi='nvim'
alias codex-desktop="~/codex-desktop-linux/codex-app/start.sh"
# Moved to a script file in $HOME/.local/bin/commit
# alias commit='commitmsg --grok-code-fast-1 | git commit -F -'

easandroidlocal() {
    mkdir -p "$HOME/tmp/eas" "$HOME/tmp/gradle" "$HOME/tmp/eas-build-local"
    local workdir
    workdir="$(mktemp -d "$HOME/tmp/eas-build-local.XXXXXX")"

    EAS_LOCAL_BUILD_WORKINGDIR="$workdir" \
    TMPDIR="$HOME/tmp/eas" TMP="$HOME/tmp/eas" TEMP="$HOME/tmp/eas" \
    GRADLE_USER_HOME="$HOME/tmp/gradle" \
    ORG_GRADLE_PROJECT_org_gradle_jvmargs="-Xmx6g -XX:MaxMetaspaceSize=1g
    -Dkotlin.daemon.jvm.options=-Xmx2g -Dfile.encoding=UTF-8" \
    ORG_GRADLE_PROJECT_org_gradle_workers_max=2 \
    eas build --local --platform android --profile apk
}

fzf-history-widget() {
  local selected cmd

  selected=$(
    fc -l -i -r 1 |
    awk '
      {
        # Expected fc -l -i output shape is roughly:
        # <num>  <date> <time>  <command...>
        sub(/^[[:space:]]*[0-9]+[[:space:]]+/, "", $0)

        # Grab date+time
        ts = $1 " " $2
        $1 = ""; $2 = ""
        sub(/^[[:space:]]+/, "", $0)
        cmd = $0

        # Dedup: keep first occurrence (newest)
        if (!seen[cmd]++) {
          printf "%s │ %s\n", ts, cmd
        }
      }
    ' |
    fzf-tmux -p 55%,60% --prompt='history> '
  ) || return

  # Strip the timestamp prefix; keep only the command
  cmd="${selected#* │ }"
  LBUFFER="$cmd"
  RBUFFER=""
  zle redisplay
}

zle -N fzf-history-widget
bindkey '^R' fzf-history-widget

export GALLIUM_DRIVER=d3d12
export LIBVA_DRIVER_NAME=d3d12
export MESA_LOADER_DRIVER_OVERRIDE=d3d12
export WEBKIT_DISABLE_DMABUF_RENDERER=1
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_D3D12_DEFAULT_ADAPTER_NAME="NVIDIA"
export PATH=$PATH:$HOME/.local/share/bob/nvim-bin
export PATH=$PATH:$HOME/.local/bin

export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

eval "$(mise activate zsh)"

precmd() {
  print -Pn "\e]2;%~\e\\"
}
