# Zsh Buddy Theme - Version 1.4.1
# A dynamic, humorous Vietnamese developer-focused Zsh theme
# Repository: https://github.com/hieudnm/zsh-buddy-theme

# zsh builtins for time/date (avoid forking `date`: ~130ms per fork on Windows/MSYS with AV)
zmodload zsh/datetime 2>/dev/null || \
    print -u2 "Zsh Buddy Theme: the zsh/datetime module is missing; time-based messages and timers will not work."

# History configuration
HISTFILE=$HOME/.zhistory
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY        # Append to history instead of overwriting
setopt SHARE_HISTORY         # Share history between sessions
setopt HIST_EXPIRE_DUPS_FIRST # Remove duplicates first when history file is full
setopt HIST_VERIFY           # Show command with history expansion before running it
setopt HIST_REDUCE_BLANKS    # Remove unnecessary blanks
setopt HIST_IGNORE_SPACE     # Don't record commands starting with space
setopt HIST_NO_STORE         # Don't store history commands
setopt HIST_NO_FUNCTIONS     # Don't store function definitions
setopt HIST_IGNORE_ALL_DUPS  # Remove older duplicate entries
setopt HIST_FIND_NO_DUPS     # Don't display duplicates when searching
setopt HIST_SAVE_BY_COPY     # Save history by copying instead of moving
setopt HIST_FCNTL_LOCK       # Use file locking for history file

# Skip "command not found" from history
zshaddhistory() {
    local cmd="${1%$'\n'}"
    local first_word="${${(z)cmd}[1]}"
    [[ -z "$first_word" ]] && return 0
    # Allow builtins, aliases, functions, and existing commands
    whence "$first_word" &>/dev/null && return 0
    # Allow env var assignments (FOO=bar)
    [[ "$first_word" == *=* ]] && return 0
    # Command not found — don't write to history file
    return 2
}

# Put the directory holding is-at-least/add-zsh-hook/colors first in fpath.
# autoload searches fpath linearly; on Windows/MSYS each directory probe costs
# several ms, so finding them at position 1 instead of ~14 saves ~100ms each.
[[ -d /usr/share/zsh/functions/Misc ]] && fpath=(/usr/share/zsh/functions/Misc $fpath)

# Load zsh-autosuggestions plugin
[[ -f "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"

# Aliases for manual updates
alias update-zsh="source ~/.zshrc"
alias update="update_zshrc"
alias update-history="fc -R"  # Reload history from file
alias uninstall="uninstall_zsh_buddy"
alias clean-backups="clean_backups"

# Version for update checking
ZSHRC_VERSION="1.4.1"
THEME_NAME="Zsh Buddy Theme"
troll_colors=(91 92 93 94 95 96) # red green yellow blue magenta cyan

# Current time in milliseconds, pure zsh (no fork). Sets REPLY.
_zbt_now_ms() {
    local -i ms
    (( ms = ${EPOCHREALTIME:-$EPOCHSECONDS} * 1000 ))   # EPOCHREALTIME needs zsh >= 5.0.6
    REPLY=$ms
}
_zbt_timer_now() { _zbt_now_ms; echo "$REPLY"; }

# Language system
typeset -A MESSAGES  # Associative array to store messages

# Ensure .troll_themer directory exists
[[ ! -d "$HOME/.troll_themer" ]] && mkdir -p "$HOME/.troll_themer"
[[ ! -d "$HOME/.troll_themer/lang" ]] && mkdir -p "$HOME/.troll_themer/lang"

# Load language configuration
load_language_config() {
    local config_file="$HOME/.troll_themer/config"
    local lang="vi"  # default language
    
    # Check environment variable first
    if [[ -n "$TROLL_LANG" ]]; then
        lang="$TROLL_LANG"
    # Then check config file
    elif [[ -f "$config_file" ]]; then
        local line found=""
        while IFS= read -r line; do
            if [[ "$line" == TROLL_LANG=* ]]; then
                found="${line#TROLL_LANG=}"
                found="${found%%#*}"              # drop trailing comment
                found="${found//[\"\' $'\t'$'\r']/}"  # drop quotes, blanks, CR
            fi
        done < "$config_file"
        [[ -n "$found" ]] && lang="$found"
    fi

    REPLY="$lang"
}

# Load messages from language file
load_messages() {
    local lang="${1:-vi}"
    local lang_file="$HOME/.troll_themer/lang/${lang}.txt"
    
    # Clear existing messages
    MESSAGES=()
    
    # Check if language file exists, fallback to Vietnamese
    if [[ ! -f "$lang_file" ]]; then
        lang_file="$HOME/.troll_themer/lang/vi.txt"
    fi
    
    if [[ ! -f "$lang_file" ]]; then
        echo -e "\e[91m⚠️  Language file not found: ${lang_file}\e[0m"
        echo -e "\e[93mRun 'update' to download language files.\e[0m"
        return
    fi

    if [[ -f "$lang_file" ]]; then
        local -A key_counts
        local store_key
        while IFS=':' read -r key value; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            key="${key//\"/}"
            key="${key// /}"
            value="${value# }"
            if [[ -n "${key_counts[$key]+x}" ]]; then
                key_counts[$key]=$((key_counts[$key] + 1))
                store_key="${key}_${key_counts[$key]}"
                MESSAGES[$store_key]="$value"
            else
                key_counts[$key]=0
                MESSAGES[$key]="$value"
            fi
        done < "$lang_file"
    fi
}

# Get message by key (returns first match for exact key). Sets REPLY.
_get_message() {
    REPLY="${MESSAGES[$1]:-${2:-}}"
}
get_message() { _get_message "$@"; echo "$REPLY"; }

# Get random message from category (collects all entries with same prefix). Sets REPLY.
_get_random_message() {
    local category="$1"
    local -a messages
    local key

    for key in "${(@k)MESSAGES}"; do
        if [[ "$key" == "$category" || "$key" == "${category}_"* ]]; then
            messages+=("${MESSAGES[$key]}")
        fi
    done

    REPLY=""
    if (( ${#messages[@]} > 0 )); then
        REPLY="${messages[$((RANDOM % ${#messages[@]} + 1))]}"
    fi
}
get_random_message() { _get_random_message "$@"; echo "$REPLY"; }

# Initialize language system
load_language_config
CURRENT_LANG="$REPLY"
load_messages "$CURRENT_LANG"

# Function to detect WSL
detect_wsl() {
    if [[ -n "$MSYSTEM" ]]; then
        echo -e "\e[91m🖥️  Windows (Git Bash)\e[0m"
    elif [[ -f /proc/version ]]; then
        if grep -qi microsoft /proc/version; then
            echo -e "\e[93m🐧 WSL\e[0m"
        else
            echo -e "\e[92m🐧 Linux\e[0m"
        fi
    else
        case "$OSTYPE" in
            darwin*) echo -e "\e[94m🍎 macOS\e[0m" ;;
            msys*|cygwin*) echo -e "\e[91m🪟 Windows\e[0m" ;;
            *) echo -e "\e[90m❓ Unknown\e[0m" ;;
        esac
    fi
}


# Time-based troll optimization
troll_by_time() {
    local hour minute
    strftime -s hour '%H' $EPOCHSECONDS
    strftime -s minute '%M' $EPOCHSECONDS

    # Set seed for RANDOM based on current time (seconds from epoch)
    RANDOM=$EPOCHSECONDS

    local random_color=${troll_colors[$((RANDOM % ${#troll_colors[@]}))]}
    local message
    local chance=$((RANDOM % 100))
    # Check if within 17:30-18:30
    local force_show=${1:-false}
    local force_show_by_time=false
    if [[ ("$hour" == 17 && "$minute" -ge 30) || ("$hour" == 18 && "$minute" -le 30) ]]; then
        force_show_by_time=true
    fi

    # Always show message when calling function (removed 10% probability logic for easier testing)
    if [[ "$force_show_by_time" == true ]]; then
        _get_random_message "overtime"; message=$REPLY
    elif (( chance < 10 )) || [[ "$force_show" == true ]]; then
        case $hour in
            00|01) _get_random_message "hour_00"; message=$REPLY ;;
            02|03) _get_random_message "hour_02"; message=$REPLY ;;
            04|05) _get_random_message "hour_04"; message=$REPLY ;;
            06|07) _get_random_message "hour_06"; message=$REPLY ;;
            08|09) _get_random_message "hour_08"; message=$REPLY ;;
            10|11) _get_random_message "hour_10"; message=$REPLY ;;
            12|13) _get_random_message "hour_12"; message=$REPLY ;;
            14|15) _get_random_message "hour_14"; message=$REPLY ;;
            16|17) _get_random_message "hour_16"; message=$REPLY ;;
            18|19) _get_random_message "hour_18"; message=$REPLY ;;
            20|21) _get_random_message "hour_20"; message=$REPLY ;;
            22|23) _get_random_message "hour_22"; message=$REPLY ;;
            *) _get_message "hour_other"; message=$REPLY ;;
        esac
    fi
    
    if [[ -n "$message" ]]; then
        echo -e "\e[95m${message}\e[0m"
    fi
}


# Optimized troll command
troll_cmd() {
    local cmd="$1" message color
    case "$cmd" in
        *git\ commit*) _get_message "cmd_git_commit"; message=$REPLY; color=93 ;;
        *git\ push*) _get_message "cmd_git_push"; message=$REPLY; color=94 ;;
        *git\ st*|*git\ status*) _get_message "cmd_git_status"; message=$REPLY; color=92 ;;
        *git\ pull*) _get_message "cmd_git_pull"; message=$REPLY; color=91 ;;
        *git\ merge*) _get_message "cmd_git_merge"; message=$REPLY; color=95 ;;
        *git\ rebase*) _get_message "cmd_git_rebase"; message=$REPLY; color=96 ;;
        *git\ log*) _get_message "cmd_git_log"; message=$REPLY; color=93 ;;
        *git\ diff*) _get_message "cmd_git_diff"; message=$REPLY; color=92 ;;
        *git\ reset*) _get_message "cmd_git_reset"; message=$REPLY; color=91 ;;
        *git\ cherry-pick*) _get_message "cmd_git_cherry_pick"; message=$REPLY; color=95 ;;
        *python*) _get_message "cmd_python"; message=$REPLY; color=95 ;;
        *pip*) _get_message "cmd_pip"; message=$REPLY; color=92 ;;
        *npm\ install*) _get_message "cmd_npm_install"; message=$REPLY; color=91 ;;
        *npm\ start*) _get_message "cmd_npm_start"; message=$REPLY; color=94 ;;
        *npm\ run\ build*) _get_message "cmd_npm_build"; message=$REPLY; color=95 ;;
        *yarn*) _get_message "cmd_yarn"; message=$REPLY; color=93 ;;
        *rm\ -rf*) _get_message "cmd_rm"; message=$REPLY; color=96 ;;
        *mv*) _get_message "cmd_mv"; message=$REPLY; color=92 ;;
        *cp*) _get_message "cmd_cp"; message=$REPLY; color=94 ;;
        *cd*) _get_message "cmd_cd"; message=$REPLY; color=93 ;;
        *ls*) _get_message "cmd_ls"; message=$REPLY; color=92 ;;
        *cat*) _get_message "cmd_cat"; message=$REPLY; color=94 ;;
        *vim*) _get_message "cmd_vim"; message=$REPLY; color=91 ;;
        *nano*) _get_message "cmd_nano"; message=$REPLY; color=95 ;;
        *docker\ build*) _get_message "cmd_docker_build"; message=$REPLY; color=94 ;;
        *docker\ run*) _get_message "cmd_docker_run"; message=$REPLY; color=95 ;;
        *docker\ ps*) _get_message "cmd_docker_ps"; message=$REPLY; color=92 ;;
        *docker\ stop*) _get_message "cmd_docker_stop"; message=$REPLY; color=91 ;;
        *sudo*) _get_message "cmd_sudo"; message=$REPLY; color=91 ;;
        *chmod*) _get_message "cmd_chmod"; message=$REPLY; color=93 ;;
        *chown*) _get_message "cmd_chown"; message=$REPLY; color=94 ;;
        *scp*) _get_message "cmd_scp"; message=$REPLY; color=92 ;;
        *rsync*) _get_message "cmd_rsync"; message=$REPLY; color=95 ;;
        *kill*) _get_message "cmd_kill"; message=$REPLY; color=91 ;;
        *ps\ aux*) _get_message "cmd_ps"; message=$REPLY; color=93 ;;
        *htop*) _get_message "cmd_htop"; message=$REPLY; color=94 ;;
        *df\ -h*) _get_message "cmd_df"; message=$REPLY; color=92 ;;
        *free\ -m*) _get_message "cmd_free"; message=$REPLY; color=95 ;;
        *whoami*) _get_message "cmd_whoami"; message=$REPLY; color=96 ;;
        *date*) _get_message "cmd_date"; message=$REPLY; color=91 ;;
        *uptime*) _get_message "cmd_uptime"; message=$REPLY; color=94 ;;
        *reboot*) _get_message "cmd_reboot"; message=$REPLY; color=93 ;;
        *shutdown*) _get_message "cmd_shutdown"; message=$REPLY; color=92 ;;
        *) return ;;
    esac
    [[ -n "$message" ]] && echo -e "\e[${color}m${message}\e[0m"
}

# Information functions (REPLY-based: no subshells, no `date`, single git call)
_zbt_venv_info() {
    REPLY=""
    [[ -n $VIRTUAL_ENV ]] && REPLY=$'\e[93m'"🐍 (${VIRTUAL_ENV:t})"$'\e[0m'
}
venv_info() { _zbt_venv_info; echo -n "$REPLY"; }

# Pure-zsh check: is there a .git (dir or worktree file) in $PWD or any parent?
# Lets us skip spawning git entirely outside repositories.
_zbt_in_git_repo() {
    [[ -n $GIT_DIR ]] && return 0
    local d=$PWD
    while [[ -n $d ]]; do
        [[ -e $d/.git ]] && return 0
        d=${d%/*}
    done
    [[ -e /.git ]]
}

_zbt_git_info() {
    REPLY=""
    _zbt_in_git_repo || return
    # One git call gives both branch (first line "## ...") and dirty state (remaining lines)
    local -a lines
    lines=("${(@f)$(git --no-optional-locks status --porcelain -b 2>/dev/null)}")
    [[ -z "${lines[1]}" ]] && return

    local branch="${lines[1]#\#\# }"
    branch="${branch%%...*}"
    branch="${branch%% \[*}"
    case "$branch" in
        "HEAD (no branch)") branch=$(git describe --tags --always 2>/dev/null) ;;
        "No commits yet on "*) branch="${branch#No commits yet on }" ;;
        "Initial commit on "*) branch="${branch#Initial commit on }" ;;
    esac

    if (( ${#lines[@]} > 1 )); then
        REPLY=$'\e[91m'"🌟(${branch}*)"$'\e[0m'
    else
        REPLY=$'\e[92m'"🌿(${branch})"$'\e[0m'
    fi
}
git_info() { _zbt_git_info; echo -n "$REPLY"; }

_zbt_time_icon() {
    local h
    strftime -s h '%H' $EPOCHSECONDS
    case $h in
        0[0-5]) REPLY="🌌" ;; 0[6-9]|1[0-1]) REPLY="🌞" ;;
        1[2-7]) REPLY="🌤️" ;; *) REPLY="🌙" ;;
    esac
}
time_icon() { _zbt_time_icon; echo "$REPLY"; }


check_internet() {
    curl --connect-timeout 3 -sf https://raw.githubusercontent.com >/dev/null 2>&1
}

# Compare semver versions. Returns 0 if $1 > $2
version_gt() {
    local v1=(${(s:.:)1})
    local v2=(${(s:.:)2})
    local i
    for i in 1 2 3; do
        if (( ${v1[$i]:-0} > ${v2[$i]:-0} )); then
            return 0
        elif (( ${v1[$i]:-0} < ${v2[$i]:-0} )); then
            return 1
        fi
    done
    return 1
}

# Function to check for and download zshrc updates
update_zshrc() {
    if ! check_internet; then
        echo -e "\e[91m Can't connect to the network. Please try again later.\e[0m"
        return 1
    fi
    
    # Get remote version
    local remote_version=$(curl -sf --connect-timeout 5 https://raw.githubusercontent.com/hieudnm/zsh-buddy-theme/main/version.txt 2>/dev/null)
    if [[ -z "$remote_version" ]]; then
        echo -e "\e[91mUnable to download version information.\e[0m"
        return 1
    fi

    # Validate version format (e.g. 1.0.0, 2.1.3)
    if [[ ! "$remote_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "\e[91mInvalid version format received: $remote_version\e[0m"
        return 1
    fi
    
    # Compare versions using semver (only update if remote > local)
    if version_gt "$remote_version" "$ZSHRC_VERSION"; then
        echo -e "\e[92mNew version available: $remote_version (Current: $ZSHRC_VERSION)\e[0m"
        echo -e "Downloading update..."
        
        # Clear old backups before creating new ones
        rm -f ~/.zshrc.backup 2>/dev/null
        rm -rf "$HOME/.troll_themer.backup" 2>/dev/null

        # Backup current files
        cp ~/.zshrc ~/.zshrc.backup
        echo -e "\e[93m📦 Backed up .zshrc to ~/.zshrc.backup\e[0m"
        
        if [[ -d "$HOME/.troll_themer" ]]; then
            cp -r "$HOME/.troll_themer" "$HOME/.troll_themer.backup"
            echo -e "\e[93m📦 Backed up .troll_themer to ~/.troll_themer.backup\e[0m"
        else
            echo -e "\e[94m📁 .troll_themer folder not found - will create new one\e[0m"
        fi
        
        # Extract user's custom config (everything after ZSH_BUDDY_THEME_END marker)
        local user_config=""
        if grep -q "ZSH_BUDDY_THEME_END" ~/.zshrc; then
            user_config=$(sed -n '/^# === ZSH_BUDDY_THEME_END ===/,$ p' ~/.zshrc | tail -n +2 | sed '/^# Everything below this line/d; /^# Add your custom PATH/d')
        fi

        # Preserve user's language setting
        local user_lang=""
        if [[ -f "$HOME/.troll_themer/config" ]]; then
            user_lang=$(grep '^TROLL_LANG=' "$HOME/.troll_themer/config" | tail -1 | cut -d'"' -f2)
        fi

        # Download ALL files to temp dir first (atomic)
        local tmp_dir=$(mktemp -d)
        local download_ok=true
        
        echo -e "\e[96m📥 Downloading update files...\e[0m"
        
        curl -sf -o "$tmp_dir/zshrc" https://raw.githubusercontent.com/hieudnm/zsh-buddy-theme/main/.zshrc || download_ok=false
        curl -sf -o "$tmp_dir/config" https://raw.githubusercontent.com/hieudnm/zsh-buddy-theme/main/.troll_themer/config || download_ok=false
        curl -sf -o "$tmp_dir/vi.txt" https://raw.githubusercontent.com/hieudnm/zsh-buddy-theme/main/.troll_themer/lang/vi.txt || download_ok=false
        curl -sf -o "$tmp_dir/en.txt" https://raw.githubusercontent.com/hieudnm/zsh-buddy-theme/main/.troll_themer/lang/en.txt || download_ok=false

        if [[ "$download_ok" == false ]]; then
            rm -rf "$tmp_dir"
            echo -e "\e[91m❌ Failed to download update files. Rolling back...\e[0m"
            cp ~/.zshrc.backup ~/.zshrc
            echo -e "\e[93m🔄 Restored .zshrc from backup\e[0m"
            if [[ -d "$HOME/.troll_themer.backup" ]]; then
                rm -rf "$HOME/.troll_themer"
                mv "$HOME/.troll_themer.backup" "$HOME/.troll_themer"
                echo -e "\e[93m🔄 Restored .troll_themer from backup\e[0m"
            fi
            echo -e "\e[91m❌ Update failed. All files have been restored to previous state.\e[0m"
            return 1
        fi

        # All files downloaded — apply update
        cp "$tmp_dir/zshrc" ~/.zshrc

        # Append user's custom config if it existed
        if [[ -n "$user_config" ]]; then
            printf '%s\n' "$user_config" >> ~/.zshrc
            echo -e "\e[92m✅ .zshrc updated! Your custom config has been preserved.\e[0m"
        else
            echo -e "\e[92m✅ .zshrc updated successfully!\e[0m"
        fi

        # Apply .troll_themer files
        mkdir -p "$HOME/.troll_themer/lang"
        cp "$tmp_dir/config" "$HOME/.troll_themer/config"
        cp "$tmp_dir/vi.txt" "$HOME/.troll_themer/lang/vi.txt"
        cp "$tmp_dir/en.txt" "$HOME/.troll_themer/lang/en.txt"

        # Restore user's language setting if it was customized
        if [[ -n "$user_lang" ]]; then
            local tmp_cfg=$(mktemp)
            sed "s/^TROLL_LANG=\".*\"/TROLL_LANG=\"$user_lang\"/" "$HOME/.troll_themer/config" > "$tmp_cfg" && mv "$tmp_cfg" "$HOME/.troll_themer/config"
        fi

        # Cleanup temp dir
        rm -rf "$tmp_dir"
        
        echo -e "\e[92m🎉 Update completed successfully!\e[0m"
        echo -e "\e[93m📦 Backups saved at ~/.zshrc.backup$([[ -d "$HOME/.troll_themer.backup" ]] && echo " and ~/.troll_themer.backup")\e[0m"
        echo -e "Restart Shell to apply changes, or run: source ~/.zshrc"
    else
        echo -e "\e[92m✅ You are already using the latest version ($ZSHRC_VERSION)\e[0m"
        
        # Check if .troll_themer folder exists and offer to repair if missing
        if [[ ! -d "$HOME/.troll_themer" ]]; then
            echo -e "\e[93m⚠️  .troll_themer folder is missing. Would you like to download it? (y/N)\e[0m"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                echo -e "\e[96m📥 Downloading .troll_themer configuration...\e[0m"
                mkdir -p "$HOME/.troll_themer/lang"
                curl -sf -o "$HOME/.troll_themer/config" https://raw.githubusercontent.com/hieudnm/zsh-buddy-theme/main/.troll_themer/config
                curl -sf -o "$HOME/.troll_themer/lang/vi.txt" https://raw.githubusercontent.com/hieudnm/zsh-buddy-theme/main/.troll_themer/lang/vi.txt
                curl -sf -o "$HOME/.troll_themer/lang/en.txt" https://raw.githubusercontent.com/hieudnm/zsh-buddy-theme/main/.troll_themer/lang/en.txt
                echo -e "\e[92m✅ .troll_themer folder downloaded successfully!\e[0m"
                echo -e "Run: source ~/.zshrc to reload configuration"
            fi
        fi
    fi
}

# Uninstall theme and restore original shell config
uninstall_zsh_buddy() {
    echo -e "\e[93m⚠️  This will remove Zsh Buddy Theme and restore your previous config.\e[0m"
    echo -e "Are you sure? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "\e[92mUninstall cancelled.\e[0m"
        return 0
    fi

    echo -e "\e[96m🔄 Uninstalling Zsh Buddy Theme...\e[0m"

    # Restore .zshrc from backup or extract user config
    if [[ -f "$HOME/.zshrc.backup" ]]; then
        cp "$HOME/.zshrc.backup" "$HOME/.zshrc"
        echo -e "\e[92m✅ Restored .zshrc from backup\e[0m"
    elif grep -q "ZSH_BUDDY_THEME_END" "$HOME/.zshrc" 2>/dev/null; then
        # No backup — extract user config after theme marker
        local user_config
        user_config=$(sed -n '/^# === ZSH_BUDDY_THEME_END ===/,$ p' "$HOME/.zshrc" | tail -n +2 | sed '/^# Everything below this line/d; /^# Add your custom PATH/d')
        if [[ -n "$user_config" ]]; then
            printf '%s\n' "$user_config" > "$HOME/.zshrc"
            echo -e "\e[92m✅ Restored your custom config (PATH, aliases, exports)\e[0m"
        else
            rm -f "$HOME/.zshrc"
            echo -e "\e[93m⚠️  No custom config found — removed .zshrc\e[0m"
        fi
    else
        rm -f "$HOME/.zshrc"
        echo -e "\e[93m⚠️  No backup or theme marker found — removed .zshrc\e[0m"
    fi

    # Remove theme data
    rm -rf "$HOME/.troll_themer" 2>/dev/null && echo -e "\e[92m✅ Removed ~/.troll_themer/\e[0m"
    rm -rf "$HOME/.troll_themer.backup" 2>/dev/null

    # Remove zsh-autosuggestions plugin
    rm -rf "$HOME/.zsh/zsh-autosuggestions" 2>/dev/null && echo -e "\e[92m✅ Removed zsh-autosuggestions plugin\e[0m"
    # Remove .zsh dir if empty
    rmdir "$HOME/.zsh" 2>/dev/null

    # Clean all backups
    rm -f "$HOME"/.zshrc.backup* 2>/dev/null && echo -e "\e[92m✅ Removed all .zshrc backups\e[0m"

    # Remove auto-start from .bashrc if present
    if grep -q "zsh-buddy-theme installer" "$HOME/.bashrc" 2>/dev/null; then
        local tmp_bashrc=$(mktemp)
        grep -v "zsh-buddy-theme installer\|exec zsh" "$HOME/.bashrc" | sed '/^$/N;/^\n$/d' > "$tmp_bashrc" && mv "$tmp_bashrc" "$HOME/.bashrc"
        echo -e "\e[92m✅ Removed zsh auto-start from .bashrc\e[0m"
    fi

    echo ""
    echo -e "\e[92m🎉 Zsh Buddy Theme has been uninstalled.\e[0m"
    echo -e "Restart your terminal to apply changes."
}

# Remove all .zshrc backup files
clean_backups() {
    local count=0
    local files=("$HOME"/.zshrc.backup*(N))
    count=${#files[@]}

    # Also check .troll_themer.backup
    local has_themer_backup=false
    [[ -d "$HOME/.troll_themer.backup" ]] && has_themer_backup=true

    if (( count == 0 )) && [[ "$has_themer_backup" == false ]]; then
        echo -e "\e[92mNo backup files found.\e[0m"
        return 0
    fi

    echo -e "\e[93mFound backups:\e[0m"
    for f in "${files[@]}"; do
        echo -e "  📦 $f"
    done
    [[ "$has_themer_backup" == true ]] && echo -e "  📦 $HOME/.troll_themer.backup/"

    echo -e "\e[93mRemove all? (y/N)\e[0m"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "\e[92mCancelled.\e[0m"
        return 0
    fi

    rm -f "$HOME"/.zshrc.backup* 2>/dev/null
    rm -rf "$HOME/.troll_themer.backup" 2>/dev/null
    echo -e "\e[92m✅ All backups removed.\e[0m"
}

# Add alias for easier updating
alias update-zshrc="update_zshrc"
last_troll_time=0
troll_interval=$((5 * 60))  # 5 minutes

# Mode management - Serious mode to disable trolling temporarily
check_serious_mode() {
    [[ "$TROLL_MODE" == "serious" || "$MODE" == "serious" ]]
}

# Aliases for mode switching
alias serious="export TROLL_MODE=serious && echo -e '\e[93m🔇 Serious mode activated. Trolling disabled.\e[0m'"
alias troll="unset TROLL_MODE && echo -e '\e[95m🎭 Troll mode activated. Let the fun begin!\e[0m'"
alias mode-status="[[ -n \$TROLL_MODE ]] && echo -e '\e[93mCurrent mode: \$TROLL_MODE\e[0m' || echo -e '\e[95mCurrent mode: troll (default)\e[0m'"

# Prompt hooks

preexec() {
    _zbt_now_ms; timer=$REPLY
    last_cmd="$1"

    # Skip trolling if in serious mode
    if check_serious_mode; then
        return
    fi

    # Call troll_by_time only after a certain time interval
    current_time=$EPOCHSECONDS
    if (( current_time - last_troll_time >= troll_interval )); then
        troll_by_time   # prints its own message (if any), no subshell
        last_troll_time=$current_time
    fi

    # Call troll_cmd (prints its own message, if any)
    troll_cmd "$last_cmd"
}

precmd() {
    local _exit_code=$?

    local _icon _venv _git
    _zbt_time_icon; _icon="$REPLY"
    _zbt_venv_info; _venv="$REPLY"
    _zbt_git_info;  _git="$REPLY"

    PS1="%F{green}╭─${_icon}%f %F{red}%D{%H:%M:%S}%f %F{green}─%f %F{cyan}%n@%m %F{magenta}%~%f ${_venv} ${_git}
%F{green}╰─➜  %f"

    if [[ -n $timer ]]; then
        _zbt_now_ms
        RPROMPT="%F{cyan}[$((REPLY-timer))ms]%f"
        unset timer
    fi

    # Remove "command not found" (exit 127) from history file
    if (( _exit_code == 127 )) && [[ -f "$HISTFILE" ]]; then
        local _tmp_hist
        _tmp_hist=$(mktemp)
        sed '$d' "$HISTFILE" > "$_tmp_hist" && mv "$_tmp_hist" "$HISTFILE"
        fc -R
    fi
    
    # Remove cpu_troll because it's time-consuming to process
    unset last_cmd
}

# Custom clear function
my_clear() {
    command clear
    detect_wsl
    _get_message welcome;  echo -e "\e[93m$REPLY\e[0m"
    _get_message tip_mode; echo -e "\e[95m$REPLY\e[0m"
    if ! check_serious_mode; then
        troll_by_time true
    fi
}

# Final configuration
autoload -U colors && colors

alias clear="my_clear"
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[[3~' delete-char
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[5~' history-search-backward
bindkey '^[[6~' history-search-forward
bindkey '^[[A' up-line-or-search
bindkey '\C-h' backward-kill-word
# Quick delete entire line (before and after cursor)
bindkey '^U' backward-kill-line  # Ctrl + U: Delete from cursor to beginning of line  
bindkey '^K' kill-line           # Ctrl + K: Delete from cursor to end of line 
# Move to beginning/end of line  
bindkey '^[a' beginning-of-line   # Alt + A: Jump to beginning of line  
bindkey '^[e' end-of-line         # Alt + E: Jump to end of line  

# zsh-autosuggestions is already sourced above. On Windows/MSYS and Cygwin its
# async mode forks a child process on EVERY keystroke (very slow with AV), so
# use the synchronous path there; the default 'history' strategy is pure zsh.
if [[ -n "$MSYSTEM" || "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]]; then
    unset ZSH_AUTOSUGGEST_USE_ASYNC
fi

# Initialization - check update first, then display quotes
init_theme() {
  # Skip welcome messages if in serious mode
  if check_serious_mode; then
    return
  fi
  
  # Get last update check time
  LAST_UPDATE_CHECK_FILE="$HOME/.troll_themer/update"
  LAST_CHECK=0
  [[ -f "$LAST_UPDATE_CHECK_FILE" ]] && LAST_CHECK=$(<"$LAST_UPDATE_CHECK_FILE")

  strftime -s CURRENT_DATE '%Y-%m-%d' $EPOCHSECONDS
  # Check if the date has changed
  if [[ "$CURRENT_DATE" != "$LAST_CHECK" ]]; then
    # remove .zsh_update_check file from home directory
    rm -f "$HOME/.zsh_update_check"
    
    # check and create .troll_themer directory structure if needed
    if [[ ! -d "$HOME/.troll_themer/lang" ]]; then
      mkdir -p "$HOME/.troll_themer/lang"
    fi
    
    # check if required language files exist, create empty files if missing
    if [[ ! -f "$HOME/.troll_themer/lang/vi.txt" ]]; then
      touch "$HOME/.troll_themer/lang/vi.txt"
    fi
    if [[ ! -f "$HOME/.troll_themer/lang/en.txt" ]]; then
      touch "$HOME/.troll_themer/lang/en.txt"
    fi
    
    # Display welcome message
    _get_message welcome; echo -e "\e[93m$REPLY\e[0m"
    # Update timestamp first to prevent frequent checks
    echo "$CURRENT_DATE" > "$LAST_UPDATE_CHECK_FILE"
    # Check for updates first
    update_zshrc
  else
    _get_message welcome;  echo -e "\e[93m$REPLY\e[0m"
    _get_message tip_mode; echo -e "\e[95m$REPLY\e[0m"
  fi
  
  # Display WSL info and troll message
  detect_wsl
  troll_by_time true
} 

# Call initialization only if this is an interactive shell
[[ $- == *i* ]] && init_theme

# === ZSH_BUDDY_THEME_END ===
# Everything below this line is preserved during theme updates.
# Add your custom PATH, aliases, exports, and other config here.
