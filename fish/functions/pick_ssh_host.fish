function pick_ssh_host --description "Pick a host from ~/.ssh/config via fzf (or a numbered menu fallback)"
    if not test -f $HOME/.ssh/config
        echo pick_ssh_host: no $HOME/.ssh/config found >&2
        return 1
    end

    # Alias names from 'Host x y z' blocks, one per line.
    # Whitelists plain names so wildcards (* ? ! [) and negations are skipped.
    set -l hosts (awk '
        tolower($1) == "host" && NF > 1 {
            for (i = 2; i <= NF; i++)
                if ($i ~ /^[A-Za-z0-9._:@-]+$/) print $i
        }' $HOME/.ssh/config)

    if test (count $hosts) -eq 0
        echo pick_ssh_host: no hosts in $HOME/.ssh/config >&2
        return 1
    end

    set -l fzf_command fzf
    if set -q TMUX; and command -q fzf-tmux
        set fzf_command fzf-tmux -p 40%,70%
    end

    if command -q fzf; or command -q $fzf_command
        printf '%s\n' $hosts | $fzf_command --prompt 'ssh host ⮀ ' --header-first \
            --header 'choose a host from ~/.ssh/config (esc to cancel)'
        return $status
    end

    # No fzf available: numbered menu fallback.
    for i in (seq (count $hosts))
        echo "$i) $hosts[$i]"
    end
    read -l --prompt-str 'ssh host #: ' choice
    if string match -qr '^\d+$' -- $choice; and test $choice -ge 1; and test $choice -le (count $hosts)
        printf '%s\n' $hosts[$choice]
    else
        echo pick_ssh_host: invalid choice >&2
        return 1
    end
end
