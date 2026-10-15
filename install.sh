#!/bin/bash
# Zsh Buddy Theme - Automatic Installer
# Usage: bash <(curl -sf https://raw.githubusercontent.com/hieudnm/zsh-buddy-theme/main/install.sh)

set -e

REPO_URL="https://raw.githubusercontent.com/hieudnm/zsh-buddy-theme/main"
THEME_DIR="$HOME/.troll_themer"

# Colors
RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;93m'
CYAN='\033[0;96m'
BOLD='\033[1m'
NC='\033[0m'

print_step() { echo -e "${CYAN}▶${NC} $1"; }
print_ok() { echo -e "${GREEN}✔${NC} $1"; }
print_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✖${NC} $1"; }

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == darwin* ]]; then
        echo "macos"
    elif [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [[ "$OSTYPE" == linux* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* || -n "$MSYSTEM" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Check if a command exists
has_cmd() { command -v "$1" &>/dev/null; }

# Install zsh if not present
install_zsh() {
    if has_cmd zsh; then
        print_ok "Zsh already installed: $(zsh --version)"
        return 0
    fi

    print_step "Installing Zsh..."
    case "$OS" in
        macos)
            if has_cmd brew; then
                brew install zsh
            else
                print_error "Homebrew not found. Install Homebrew first: https://brew.sh"
                exit 1
            fi
            ;;
        linux|wsl)
            if has_cmd apt-get; then
                sudo apt-get update -qq && sudo apt-get install -y -qq zsh
            elif has_cmd dnf; then
                sudo dnf install -y zsh
            elif has_cmd yum; then
                sudo yum install -y zsh
            elif has_cmd pacman; then
                sudo pacman -S --noconfirm zsh
            elif has_cmd zypper; then
                sudo zypper install -y zsh
            else
                print_error "Could not detect package manager. Please install zsh manually."
                exit 1
            fi
            ;;
        windows)
            print_warn "On Windows (Git Bash/MSYS2), install zsh from:"
            echo "  https://packages.msys2.org/packages/zsh"
            echo "  Or run: pacman -S zsh"
            if has_cmd pacman; then
                pacman -S --noconfirm zsh
            else
                exit 1
            fi
            ;;
        *)
            print_error "Unsupported OS. Please install zsh manually."
            exit 1
            ;;
    esac

    if has_cmd zsh; then
        print_ok "Zsh installed successfully: $(zsh --version)"
    else
        print_error "Zsh installation failed."
        exit 1
    fi
}

# Backup existing .zshrc if present
backup_zshrc() {
    if [[ -f "$HOME/.zshrc" ]]; then
        local backup="$HOME/.zshrc.backup.$(date +%s)"
        cp "$HOME/.zshrc" "$backup"
        print_warn "Existing .zshrc backed up to: $backup"
    fi
}

# Download theme files
download_theme() {
    print_step "Downloading theme files..."

    # Download .zshrc
    if ! curl -sf -o "$HOME/.zshrc" "$REPO_URL/.zshrc"; then
        print_error "Failed to download .zshrc"
        exit 1
    fi
    print_ok ".zshrc"

    # Create directories
    mkdir -p "$THEME_DIR/lang" "$THEME_DIR/font"

    # Download the theme itself (.zshrc is only a small loader)
    if ! curl -sf -o "$THEME_DIR/zsh-buddy-theme.zsh" "$REPO_URL/zsh-buddy-theme.zsh"; then
        print_error "Failed to download zsh-buddy-theme.zsh"
        exit 1
    fi
    print_ok "zsh-buddy-theme.zsh"

    # Download config
    if ! curl -sf -o "$THEME_DIR/config" "$REPO_URL/.troll_themer/config"; then
        print_error "Failed to download config"
        exit 1
    fi
    print_ok "config"

    # Download language files
    if ! curl -sf -o "$THEME_DIR/lang/vi.txt" "$REPO_URL/.troll_themer/lang/vi.txt"; then
        print_error "Failed to download vi.txt"
        exit 1
    fi
    print_ok "lang/vi.txt"

    if ! curl -sf -o "$THEME_DIR/lang/en.txt" "$REPO_URL/.troll_themer/lang/en.txt"; then
        print_error "Failed to download en.txt"
        exit 1
    fi
    print_ok "lang/en.txt"
}

# Install Nerd Font
install_font() {
    print_step "Installing Nerd Font (CaskaydiaMono)..."

    local font_file="CaskaydiaMonoNerdFontMono-SemiBold.ttf"
    local font_url="$REPO_URL/.troll_themer/font/$font_file"

    case "$OS" in
        macos)
            local font_dir="$HOME/Library/Fonts"
            mkdir -p "$font_dir"
            if [[ -f "$font_dir/$font_file" ]]; then
                print_ok "Font already installed"
            else
                curl -sf -o "$font_dir/$font_file" "$font_url" && print_ok "Font installed to ~/Library/Fonts/" || print_warn "Font download failed (optional)"
            fi
            ;;
        linux|wsl)
            local font_dir="$HOME/.local/share/fonts"
            mkdir -p "$font_dir"
            if [[ -f "$font_dir/$font_file" ]]; then
                print_ok "Font already installed"
            else
                curl -sf -o "$font_dir/$font_file" "$font_url" && fc-cache -f 2>/dev/null && print_ok "Font installed to ~/.local/share/fonts/" || print_warn "Font download failed (optional)"
            fi
            ;;
        windows)
            curl -sf -o "$THEME_DIR/font/$font_file" "$font_url" && print_warn "Font downloaded to $THEME_DIR/font/ — please install manually (double-click the .ttf file)" || print_warn "Font download failed (optional)"
            ;;
        *)
            print_warn "Skipping font install on unknown OS"
            ;;
    esac
}

# Set zsh as default shell
set_default_shell() {
    local current_shell
    current_shell=$(basename "$SHELL" 2>/dev/null || echo "")

    if [[ "$current_shell" == "zsh" ]]; then
        print_ok "Zsh is already default shell"
        return 0
    fi

    case "$OS" in
        macos|linux)
            local zsh_path
            zsh_path=$(which zsh)
            print_step "Setting zsh as default shell..."

            # Ensure zsh is in /etc/shells
            if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
                echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
            fi

            if chsh -s "$zsh_path" 2>/dev/null; then
                print_ok "Default shell changed to zsh (restart terminal to take effect)"
            else
                print_warn "Could not change default shell. Run manually: chsh -s $zsh_path"
            fi
            ;;
        wsl)
            local zsh_path
            zsh_path=$(which zsh)
            # On WSL, also add to .bashrc as fallback
            if ! grep -q "exec zsh" "$HOME/.bashrc" 2>/dev/null; then
                echo "" >> "$HOME/.bashrc"
                echo "# Auto-start zsh (added by zsh-buddy-theme installer)" >> "$HOME/.bashrc"
                echo 'if [ -t 1 ]; then exec zsh; fi' >> "$HOME/.bashrc"
                print_ok "Added zsh auto-start to .bashrc"
            else
                print_ok "Zsh auto-start already in .bashrc"
            fi

            if chsh -s "$zsh_path" 2>/dev/null; then
                print_ok "Default shell changed to zsh"
            fi
            ;;
        windows)
            if ! grep -q "exec zsh" "$HOME/.bashrc" 2>/dev/null; then
                echo "" >> "$HOME/.bashrc"
                echo "# Auto-start zsh (added by zsh-buddy-theme installer)" >> "$HOME/.bashrc"
                echo 'if [ -t 1 ]; then exec zsh; fi' >> "$HOME/.bashrc"
                print_ok "Added zsh auto-start to .bashrc"
            else
                print_ok "Zsh auto-start already in .bashrc"
            fi
            ;;
    esac
}

# Install zsh-autosuggestions plugin
install_autosuggestions() {
    local plugin_dir="$HOME/.zsh/zsh-autosuggestions"

    if [[ -d "$plugin_dir" ]]; then
        print_ok "zsh-autosuggestions already installed"
        return 0
    fi

    print_step "Installing zsh-autosuggestions plugin..."

    if has_cmd git; then
        mkdir -p "$HOME/.zsh"
        if git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir" 2>/dev/null; then
            print_ok "zsh-autosuggestions installed"
        else
            print_warn "Failed to clone zsh-autosuggestions (optional)"
        fi
    else
        print_warn "Git not found — skipping zsh-autosuggestions (install git and re-run)"
    fi
}

# Main
main() {
    echo ""
    echo -e "${BOLD}🎉 Zsh Buddy Theme Installer${NC}"
    echo -e "${CYAN}────────────────────────────${NC}"
    echo ""

    OS=$(detect_os)
    case "$OS" in
        macos)  print_step "Detected: 🍎 macOS" ;;
        linux)  print_step "Detected: 🐧 Linux" ;;
        wsl)    print_step "Detected: 🐧 WSL (Windows Subsystem for Linux)" ;;
        windows) print_step "Detected: 🪟 Windows (Git Bash/MSYS2)" ;;
        *)      print_warn "Detected: ❓ Unknown OS ($OSTYPE)" ;;
    esac
    echo ""

    install_zsh
    backup_zshrc
    download_theme
    install_font
    install_autosuggestions
    set_default_shell

    echo ""
    echo -e "${CYAN}────────────────────────────${NC}"
    echo -e "${GREEN}${BOLD}✔ Installation complete!${NC}"
    echo ""
    echo -e "  ${BOLD}Next steps:${NC}"
    echo -e "  1. Restart your terminal (or run: ${CYAN}exec zsh${NC})"
    echo -e "  2. Set your terminal font to ${BOLD}CaskaydiaMono Nerd Font${NC}"
    echo -e "  3. Enjoy! 🎉"
    echo ""
    echo -e "  ${BOLD}Commands:${NC}"
    echo -e "  ${CYAN}update${NC}       — Update theme to latest version"
    echo -e "  ${CYAN}serious${NC}      — Disable buddy messages"
    echo -e "  ${CYAN}troll${NC}        — Enable buddy messages"
    echo -e "  ${CYAN}mode-status${NC}  — Check current mode"
    echo ""
}

main
