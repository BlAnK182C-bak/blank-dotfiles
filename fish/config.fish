source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
set -x HYPRSHOT_DIR $HOME/Pictures/Screenshots
alias reset-master "git checkout master && git fetch origin && git reset --hard master"
alias reset-main "git checkout main && git fetch origin && git reset --hard main"

function y
    set tmp (mktemp -t yazi-cwd.XXXXXX)
    yazi $argv --cwd-file="$tmp"

    if test -f "$tmp"
        set cwd (cat "$tmp")
        if test -n "$cwd"; and test "$cwd" != "$PWD"
            cd "$cwd"
        end
        rm -f "$tmp"
    end
end
