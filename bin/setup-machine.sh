#!/bin/bash
#
# Sets up environment. Must be run after bootstrap-dotfiles.sh. Can be run multiple times;
# it won't do things that have already been done.

set -xueE -o pipefail

# '1' if running under Windows Subsystem for Linux, '0' otherwise.
readonly WSL=$(grep -q Microsoft /proc/version && echo 1 || echo 0)

# Install a bunch of debian packages.
function install_packages() {
  local PACKAGES=(
    ascii
    build-essential
    clang-format
    command-not-found
    curl
    dos2unix
    g++-8
    gawk
    git
    htop
    jq
    meld
    nano
    p7zip-full
    p7zip-rar
    perl
    tree
    unrar
    wget
    x11-utils
    xsel
    zsh
  )

  if [[ "$WSL" == 1 ]]; then
    PACKAGES+=(dbus-x11)
  else
    PACKAGES+=(gnome-tweak-tool iotop unoconv)
  fi
  
  sudo apt update
  sudo apt upgrade -y
  sudo apt install -y "${PACKAGES[@]}"
  sudo apt autoremove -y
}

# If this user's login shell is not already "zsh", attempt to switch.
function change_shell() {
  test "${SHELL##*/}" != "zsh" || return 0
  chsh -s "$(grep -E '/zsh$' /etc/shells | tail -1)"
}

# Install oh-my-zsh.
function install_ohmyzsh() {
  local REPO="$HOME"/.oh-my-zsh
  [[ -d "$REPO" ]] || git clone --depth=1 https://github.com/robbyrussell/oh-my-zsh.git "$REPO"
  git --git-dir="$REPO"/.git --work-tree="$REPO" pull
}

# Install oh-my-zsh plugin or theme.
function install_ohmyzsh_extension() {
  local REPO="$HOME/.oh-my-zsh/custom/${1}s/$2"
  shift 2
  [[ -d "$REPO" ]] || git clone "$@" "$REPO"
  git --git-dir="$REPO"/.git --work-tree="$REPO" pull
}

# Install Visual Studio Code.
function install_vscode() {
  test $WSL -eq 0 || return 0
  test ! -f /usr/bin/code || return 0
  local VSCODE_DEB=$(mktemp)
  curl -L 'https://go.microsoft.com/fwlink/?LinkID=760868' >"$VSCODE_DEB"
  sudo apt install "$VSCODE_DEB"
  rm "$VSCODE_DEB"
}

function win_install_fonts() {
  local DST_DIR
  DST_DIR=$(wslpath $(cmd.exe /c "echo %LOCALAPPDATA%\Microsoft\\Windows\\Fonts" | sed 's/\r$//'))
  mkdir -p "$DST_DIR"
  for SRC in "$@"; do
    local FILE=$(basename "$SRC")
    test -f "$DST_DIR/$FILE" || cp -f "$SRC" "$DST_DIR/"
    local WIN_PATH
    WIN_PATH=$(wslpath -w "$DST_DIR/$FILE")
    # Install fond for the current user. It'll appear in "Font settings".
    reg.exe add \
      "HKCU\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" \
      /v "${FILE%.*} (TrueType)"  /t REG_SZ /d "$WIN_PATH" /f
  done
  # Install font for the use with Windows Command Prompt. Requires reboot.
  reg.exe add \
    "HKCU\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Console\\TrueTypeFont" \
    /v 1337 /t REG_SZ /d "MesloLGLDZ NF" /f

}

# Install a decent monospace font.
function install_fonts() {
  if [[ $WSL == 1 ]]; then
    win_install_fonts "$HOME"/.local/share/fonts/NerdFonts/*"Windows Compatible.ttf"
  fi
}

function fix_dbus() {
  test $WSL -eq 1 || return 0
  sudo dbus-uuidgen --ensure
}

function fix_gcc() {
  sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 8
  sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-8 8
}

function with_dbus() {
  [[ -z "${DBUS_SESSION_BUS_ADDRESS+X}" ]] && set -- dbus-launch "$@"
  "$@"
}

# Set preferences for various applications.
function set_preferences() {
  if [[ $WSL == 0 ]]; then
    # It doesn't work on WSL.
    gsettings set org.gnome.desktop.interface monospace-font-name 'MesloLGS Nerd Font Mono 11'
  fi
  if [[ "${DISPLAY+X}" == "" ]]; then
    export DISPLAY=:0
  fi
  if ! xprop -root &>/dev/null; then
    # No X server at $DISPLAY.
    return
  fi
}

function disable_fucking_magic() {
  # Disable the retarded shit that Oh My Zsh peddles. It makes paste into terminal painfully slow
  # and fucks up useful plugins like zsh-autosuggestions.
  mkdir -p "$HOME"/.oh-my-zsh/custom/lib
  touch "$HOME"/.oh-my-zsh/custom/lib/misc.zsh
}

if [[ "$(id -u)" == 0 ]]; then
  echo "setup-machine.sh: please run as non-root" >&2
  exit 1
fi

umask g-w,o-w

install_packages
install_vscode
install_fonts
install_ohmyzsh

install_ohmyzsh_extension plugin \
  zsh-prompt-benchmark git@github.com:romkatv/zsh-prompt-benchmark.git
install_ohmyzsh_extension plugin \
  zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
install_ohmyzsh_extension plugin \
  zsh-autosuggestions -b faster-counts git@github.com:romkatv/zsh-autosuggestions.git
install_ohmyzsh_extension theme \
  powerlevel10k git@github.com:romkatv/powerlevel10k.git

disable_fucking_magic

fix_shm
fix_gcc

set_preferences

change_shell

echo SUCCESS
