function fish_prompt_real
    set -l color_cwd
    set -l suffix
    set -l user

    switch $USER
        case root toor
            if set -q fish_color_cwd_root
                set color_cwd $fish_color_cwd_root
            else
                set color_cwd $fish_color_cwd
            end
            set suffix '#'
        case '*'
            set color_cwd $fish_color_cwd
            set suffix '$'
    end

    if [ "$HOME" != (eval echo "~$USER") ]
        set user $USER
    end

    echo -n -s "$user" \
        @ (prompt_hostname) ' ' \
        (set_color yellow) \
        (vcs_tip '(%s)') \
        (set_color $color_cwd) \
        (prompt_pwd) \
        (set_color normal) "$suffix "

end
