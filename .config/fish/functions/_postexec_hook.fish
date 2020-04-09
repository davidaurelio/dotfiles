function _postexec_hook --on-event fish_postexec
    set -l last_status $pipestatus[1..-2] $status
    if begin; test -n $argv[1]; and string match --quiet --invert 0 $last_status; end
        if not set -l status_string (string join " | " $last_status)
            set status_string (printf "% 3d" $last_status[1])
        end

        # 70 = 79 - arrow/punct/spaces
        set -l remaining_space (math 70 - (string length $status_string))

        set_color --background red
        set_color --bold white
        echo -n "╰─⯈ $status_string: "
        set_color normal
        set_color --background red
        set_color white
        echo -s (string replace --regex "(.{$remaining_space}).{4,}" '$1...' $argv[1]) " "
        set_color normal
    end
end
