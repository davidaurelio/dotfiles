function _postexec_hook --on-event fish_postexec
    set -l last_status $status
    if [ "$last_status" != 0 -a -n "$argv[1]" ]
        set_color --background red
        set_color --bold white
        printf "╰─⯈ % 3s: %s \n" $last_status \
          (string replace --regex '(.{59}).{4,}' '$1...' $argv[1])
        set_color normal
    end
end
