# Colours

# fish_color_normal: default color
set -U fish_color_normal normal

# fish_color_command: commands like echo
set -U fish_color_command normal --bold

# fish_color_keyword: keywords like if - this falls back on the command color if unset
set -U fish_color_keyword green --bold

# fish_color_quote: quoted text like "abc"
set -U fish_color_quote cyan

# fish_color_redirection: IO redirections like >/dev/null
set -U fish_color_redirection magenta --italics

# fish_color_end: process separators like ; and &
set -U fish_color_end yellow

# fish_color_error: syntax errors
set -U fish_color_error red

# fish_color_param: ordinary command parameters
set -U fish_color_param normal

# fish_color_valid_path: parameters that are filenames (if the file exists)
set -U fish_color_valid_path --underline

# fish_color_option: options starting with “-”, up to the first “--” parameter
set -U fish_color_option --italics

# fish_color_comment: comments like ‘# important’
set -U fish_color_comment --dim

# fish_color_selection: selected text in vi visual mode
set -U fish_color_selection --reverse

# fish_color_operator: parameter expansion operators like * and ~
set -U fish_color_operator blue --italics

# fish_color_escape: character escapes like \n and \x70
set -U fish_color_escape red --italics

# fish_color_autosuggestion: autosuggestions (the proposed rest of a command)
set -U fish_color_autosuggestion --dim --italics

# fish_color_cwd: the current working directory in the default prompt
set -U fish_color_cwd blue

# fish_color_cwd_root: the current working directory in the default prompt for the root user
set -U fish_color_cwd_root red

# fish_color_user: the username in the default prompt
set -U fish_color_user green

# fish_color_host: the hostname in the default prompt
set -U fish_color_host normal

# fish_color_host_remote: the hostname in the default prompt for remote sessions (like ssh)
set -U fish_color_host_remote yellow

# fish_color_status: the last command’s nonzero exit code in the default prompt
set -U fish_color_status red

# fish_color_cancel: the ‘^C’ indicator on a canceled command
set -U fish_color_cancel --reverse

# fish_color_search_match: history search matches and selected pager items (background only)
set -U fish_color_search_match --reverse

# dirh current entry
set -U fish_color_history_current yellow --bold


# Pager
set -U fish_pager_color_completion yellow --underline
set -U fish_pager_color_description green
set -U fish_pager_color_prefix normal
set -U fish_pager_color_progress blue --dim
set -U fish_pager_color_selected_background --reverse
