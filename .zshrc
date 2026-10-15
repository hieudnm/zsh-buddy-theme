# Zsh Buddy Theme - loader (Version 1.5.1)
# Repository: https://github.com/hieudnm/zsh-buddy-theme
#
# The theme itself lives in ~/.troll_themer/zsh-buddy-theme.zsh and is updated
# atomically by `update`. This file stays tiny on purpose: a shell may still be
# reading ~/.zshrc while an update replaces it, and zsh keeps reading a replaced
# file from its old byte offset. A small file simply ends there.
ZBT_THEME_FILE="${ZBT_THEME_FILE:-$HOME/.troll_themer/zsh-buddy-theme.zsh}"
if [[ ! -f "$ZBT_THEME_FILE" ]]; then
    mkdir -p "${ZBT_THEME_FILE:h}"
    print -u2 "Zsh Buddy Theme: theme file missing, downloading it..."
    if curl -sf --connect-timeout 5 --max-time 20 -o "$ZBT_THEME_FILE.tmp" \
            https://raw.githubusercontent.com/hieudnm/zsh-buddy-theme/main/zsh-buddy-theme.zsh; then
        mv -f "$ZBT_THEME_FILE.tmp" "$ZBT_THEME_FILE"
    else
        rm -f "$ZBT_THEME_FILE.tmp"
        print -u2 "Zsh Buddy Theme: download failed (offline?). Open a new shell to retry."
    fi
fi
[[ -f "$ZBT_THEME_FILE" ]] && source "$ZBT_THEME_FILE"

# === ZSH_BUDDY_THEME_END ===
# Everything below this line is preserved during theme updates.
# Add your custom PATH, aliases, exports, and other config here.
