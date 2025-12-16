function fish_prompt -d "Write out the prompt"
    # This shows up as USER@HOST /home/user/ >, with the directory colored
    # $USER and $hostname are set by fish, so you can just use them
    # instead of using `whoami` and `hostname`
    printf '%s@%s %s%s%s > ' $USER $hostname \
        (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
end

if status is-interactive # Commands to run in interactive sessions can go here

    # No greeting
    set fish_greeting

    # Use starship
    starship init fish | source
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    set -gx EDITOR nvim
    set -gx BROWSER brave

    # Aliases
    alias pamcan pacman
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
    
    # ASDF configuration code
    if test -z $ASDF_DATA_DIR
	set _asdf_shims "$HOME/.asdf/shims"
    else
	set _asdf_shims "$ASDF_DATA_DIR/shims"
    end

    # Do not use fish_add_path (added in Fish 3.2) because it
    # potentially changes the order of items in PATH
    if not contains $_asdf_shims $PATH
	set -gx --prepend PATH $_asdf_shims
    end
    set --erase _asdf_shims
end
