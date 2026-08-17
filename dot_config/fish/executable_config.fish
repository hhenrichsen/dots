fish_add_path "$HOME/.local/bin" "$HOME/.fly/bin" "$HOME/bin"

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

zoxide init fish | source

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
    alias ls 'eza --icons'
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

