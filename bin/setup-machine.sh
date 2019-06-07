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
    libxml2-utils
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
    PACKAGES+=(gnome-tweak-tool iotop)
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

if [[ "$(id -u)" == 0 ]]; then
  echo "setup-machine.sh: please run as non-root" >&2
  exit 1
fi

umask g-w,o-w

install_packages
install_vscode
install_fonts

# fix_shm
fix_gcc

set_preferences

change_shell

[[ -f "$HOME"/.z ]] || touch "$HOME"/.z

echo SUCCESS
