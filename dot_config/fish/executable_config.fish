fish_add_path "$HOME/.local/bin" "$HOME/.fly/bin" "$HOME/bin"

if command -q brew
    brew shellenv fish | source
else if test -x /opt/homebrew/bin/brew
    /opt/homebrew/bin/brew shellenv fish | source
else if test -x /home/linuxbrew/.linuxbrew/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew shellenv fish | source
end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

zoxide init fish | source

if test -x "$HOME/.local/bin/mise"
    "$HOME/.local/bin/mise" activate fish | source
end

if status is-interactive # Commands to run in interactive sessions can go here
    # No greeting
    set fish_greeting

    set -gx EDITOR nvim
    set -gx BROWSER brave

    # Aliases
    alias vi="nvim"
    alias vim="nvim"
    alias cat="batcat"
    alias ls="eza"
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias q 'qs -c ii'

    function boop
        set -l last $status
        if test $last -eq 0
            sfx good
        else
            sfx bad
        end
        return $last
    end
end

