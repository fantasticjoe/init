#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[init]"

echo "$LOG_PREFIX Starting zsh/oh-my-zsh setup..."

if [[ -t 1 ]]; then
  BOLD="\033[1m"
  RESET="\033[0m"
else
  BOLD=""
  RESET=""
fi

log() {
  echo "$LOG_PREFIX $*"
}

err() {
  echo "$LOG_PREFIX ERROR: $*" >&2
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

SUDO=""
IS_ROOT=0
IS_SUDOER=0
INTERACTIVE=0

if [[ "$(id -u)" -eq 0 ]]; then
  IS_ROOT=1
fi

if [[ -t 0 ]]; then
  INTERACTIVE=1
fi

confirm() {
  local prompt="$1"
  local default_yes="${2:-1}"

  if [[ "$INTERACTIVE" -ne 1 ]]; then
    return 0
  fi

  local suffix="[Y/n]"
  if [[ "$default_yes" -eq 0 ]]; then
    suffix="[y/N]"
  fi

  while true; do
    read -r -p "$prompt $suffix " reply
    if [[ -z "$reply" ]]; then
      if [[ "$default_yes" -eq 1 ]]; then
        return 0
      fi
      return 1
    fi
    case "$reply" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

check_sudo() {
  if [[ "$IS_ROOT" -eq 1 ]]; then
    return 0
  fi

  if ! need_cmd sudo; then
    err "sudo not found; continuing without root privileges."
    return 1
  fi

  if sudo -n true 2>/dev/null; then
    IS_SUDOER=1
    SUDO="sudo"
    return 0
  fi

  if confirm "Sudo password may be required for package install. Try sudo now?" 1; then
    if sudo -v; then
      IS_SUDOER=1
      SUDO="sudo"
      return 0
    fi
  fi

  err "Not a sudoer or sudo authentication failed; continuing without root privileges."
  return 1
}

install_packages() {
  local pkgs=(zsh git curl wget ca-certificates)
  local pacman_full_upgrade="${1:-0}"
  local pm=""

  if need_cmd apt-get; then
    pm="apt-get"
  elif need_cmd dnf; then
    pm="dnf"
  elif need_cmd yum; then
    pm="yum"
  elif need_cmd pacman; then
    pm="pacman"
  elif need_cmd apk; then
    pm="apk"
  elif need_cmd zypper; then
    pm="zypper"
  elif need_cmd pkg; then
    pm="pkg"
  elif need_cmd port; then
    pm="port"
  elif need_cmd brew; then
    pm="brew"
  else
    pm="none"
  fi

  case "$pm" in
    apt-get|dnf|yum|pacman|apk|zypper|pkg|port)
      if [[ "$IS_ROOT" -eq 0 && "$IS_SUDOER" -eq 0 ]]; then
        err "Skipping package install (no root privileges)."
        return 0
      fi
      ;;
  esac

  if [[ "$pm" == "apt-get" ]]; then
    $SUDO apt-get update -y
    $SUDO apt-get install -y "${pkgs[@]}"
  elif [[ "$pm" == "dnf" ]]; then
    $SUDO dnf install -y "${pkgs[@]}"
  elif [[ "$pm" == "yum" ]]; then
    $SUDO yum install -y "${pkgs[@]}"
  elif [[ "$pm" == "pacman" ]]; then
    if [[ "$pacman_full_upgrade" -eq 1 ]]; then
      log "Arch/Manjaro: using pacman -Syu (full upgrade)."
      $SUDO pacman -Syu --noconfirm --needed "${pkgs[@]}"
    else
      log "Arch/Manjaro: using pacman -Sy (no full upgrade)."
      $SUDO pacman -Sy --noconfirm --needed "${pkgs[@]}"
    fi
  elif [[ "$pm" == "apk" ]]; then
    $SUDO apk add --no-cache "${pkgs[@]}"
  elif [[ "$pm" == "zypper" ]]; then
    $SUDO zypper refresh
    $SUDO zypper install -y "${pkgs[@]}"
  elif [[ "$pm" == "pkg" ]]; then
    $SUDO pkg update -f
    $SUDO pkg install -y "${pkgs[@]}"
  elif [[ "$pm" == "port" ]]; then
    $SUDO port selfupdate
    $SUDO port install "${pkgs[@]}"
  elif [[ "$pm" == "brew" ]]; then
    brew update
    brew install "${pkgs[@]}"
  else
    err "No supported package manager found. Install zsh, git, curl, wget, ca-certificates manually."
    return 0
  fi
}

inplace_sed() {
  local expr="$1"
  local file="$2"
  if sed --version >/dev/null 2>&1; then
    sed -i "$expr" "$file"
  else
    sed -i '' "$expr" "$file"
  fi
}

install_ohmyzsh() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log "Oh My Zsh already installed."
    return 0
  fi

  log "Installing Oh My Zsh..."
  export RUNZSH=no
  export CHSH=no
  export KEEP_ZSHRC=yes

  if need_cmd curl; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  elif need_cmd wget; then
    sh -c "$(wget -qO- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  else
    err "Neither curl nor wget found."
    return 1
  fi
}

install_miniforge() {
  local prefix="${MINIFORGE_PREFIX:-$HOME/miniforge3}"
  local os
  local arch
  local url
  local installer
  local run_init="${1:-1}"

  if [[ -d "$prefix" ]]; then
    log "Miniforge3 already installed at $prefix"
    if [[ "$run_init" -eq 1 ]]; then
      if [[ -x "$prefix/bin/conda" ]]; then
        log "Running conda init zsh..."
        "$prefix/bin/conda" init zsh
      else
        err "conda not found at $prefix/bin/conda"
      fi
    fi
    return 0
  fi

  if ! need_cmd curl && ! need_cmd wget; then
    err "Neither curl nor wget found; cannot install Miniforge3."
    return 1
  fi

  case "$(uname -s)" in
    Linux) os="Linux" ;;
    Darwin) os="MacOSX" ;;
    *) err "Unsupported OS for Miniforge3."; return 1 ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64|x64) arch="x86_64" ;;
    arm64) arch="arm64" ;;
    aarch64) arch="aarch64" ;;
    *) err "Unsupported CPU architecture for Miniforge3."; return 1 ;;
  esac

  if [[ "$os" == "Linux" && "$arch" == "arm64" ]]; then
    arch="aarch64"
  elif [[ "$os" == "MacOSX" && "$arch" == "aarch64" ]]; then
    arch="arm64"
  fi

  url="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-${os}-${arch}.sh"
  installer="$(mktemp -t miniforge3.XXXXXX.sh)"

  # Download and run the official Miniforge3 installer (user-space).
  log "Downloading Miniforge3 installer..."
  if need_cmd curl; then
    curl -fsSL "$url" -o "$installer"
  else
    wget -qO "$installer" "$url"
  fi

  log "Installing Miniforge3 to $prefix..."
  bash "$installer" -b -p "$prefix"
  rm -f "$installer"

  if [[ "$run_init" -eq 1 ]]; then
    log "Running conda init zsh..."
    "$prefix/bin/conda" init zsh
  else
    log "Miniforge3 installed. To enable conda: $prefix/bin/conda init zsh"
  fi
}

clone_plugin() {
  local name="$1"
  local repo="$2"
  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  local target="$zsh_custom/plugins/$name"

  if [[ -d "$target" ]]; then
    log "Plugin $name already installed."
    return 0
  fi

  log "Installing plugin $name..."
  git clone --depth=1 "$repo" "$target"
}

update_zshrc() {
  local zshrc="$HOME/.zshrc"
  local theme_line='ZSH_THEME="ys"'
  local update_plugins="${1:-1}"
  shift || true
  local plugins_line=""

  if [[ "$update_plugins" -eq 1 ]]; then
    if [[ "$#" -gt 0 ]]; then
      plugins_line="plugins=($*)"
    else
      plugins_line="plugins=()"
    fi
  fi

  if [[ ! -f "$zshrc" ]]; then
    log "Creating $zshrc"
    touch "$zshrc"
  fi

  if grep -q '^ZSH_THEME=' "$zshrc"; then
    inplace_sed 's/^ZSH_THEME=.*/ZSH_THEME="ys"/' "$zshrc"
  else
    echo "$theme_line" >> "$zshrc"
  fi

  if [[ "$update_plugins" -eq 1 ]]; then
    if grep -q '^plugins=' "$zshrc"; then
      inplace_sed "s/^plugins=.*/$plugins_line/" "$zshrc"
    else
      echo "$plugins_line" >> "$zshrc"
    fi
  fi

  log "Updated $zshrc"
}

set_default_shell() {
  if ! need_cmd zsh; then
    err "zsh not found; cannot set default shell."
    return 1
  fi

  if ! need_cmd chsh; then
    log "chsh not available; skipping default shell change."
    return 0
  fi

  local zsh_path
  zsh_path="$(command -v zsh)"

  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    log "zsh is already the default shell."
    return 0
  fi

  log "Setting default shell to $zsh_path for user $USER..."
  if ! chsh -s "$zsh_path" "$USER" 2>/dev/null; then
    log "chsh failed; you may need to run: chsh -s $zsh_path"
  fi
}

main() {
  local do_install_pkgs=1
  local do_install_omz=1
  local do_install_miniforge=0
  local do_install_plugins=1
  local do_update_zshrc=1
  local do_set_shell=1
  local do_conda_init=1
  # Arch/Manjaro default is no full upgrade.
  local pacman_full_upgrade=0
  local update_plugins_in_zshrc=0
  local selected_plugins=()

  if [[ "$INTERACTIVE" -eq 1 ]]; then
    confirm "Install system packages (zsh/git/curl/wget/ca-certificates)?" 1 || do_install_pkgs=0
    if [[ "$do_install_pkgs" -eq 1 && -x /usr/bin/pacman ]]; then
      confirm "Arch/Manjaro: run full upgrade with pacman -Syu (default: No)?" 0 && pacman_full_upgrade=1
    fi
    confirm "Install Oh My Zsh?" 1 || do_install_omz=0
    confirm "Install Miniforge3 (default: No)?" 0 && do_install_miniforge=1
    if [[ "$do_install_miniforge" -eq 1 ]]; then
      confirm "Run 'conda init zsh' after install (default: Yes)?" 1 || do_conda_init=0
    fi
    confirm "Install Zsh plugins?" 1 || do_install_plugins=0
    confirm "Update ~/.zshrc (theme/plugins)?" 1 || do_update_zshrc=0
    confirm "Set zsh as default shell?" 1 || do_set_shell=0
  else
    if [[ "${MINIFORGE_INSTALL:-0}" == "1" ]]; then
      do_install_miniforge=1
    fi
    if [[ "${MINIFORGE_CONDA_INIT:-1}" == "0" ]]; then
      do_conda_init=0
    fi
    if [[ "${PACMAN_FULL_UPGRADE:-0}" == "1" ]]; then
      pacman_full_upgrade=1
    fi
  fi

  if [[ "$do_install_pkgs" -eq 1 ]]; then
    # Only needed for package installs that require elevation.
    check_sudo || true
  fi

  if [[ "$do_install_pkgs" -eq 1 ]]; then
    if ! install_packages "$pacman_full_upgrade"; then
      err "Package install failed; continuing."
    fi
  fi

  if [[ "$do_install_omz" -eq 1 ]]; then
    install_ohmyzsh
  fi

  if [[ "$do_install_miniforge" -eq 1 ]]; then
    install_miniforge "$do_conda_init"
  fi

  if [[ "$do_install_plugins" -eq 1 ]]; then
    # Some plugins are built into oh-my-zsh (no repo); others are cloned.
    local plugin_names=(git z zsh-autosuggestions conda-zsh-completion extract zsh-syntax-highlighting)
    local plugin_repos=("" "" "https://github.com/zsh-users/zsh-autosuggestions.git" "https://github.com/conda-incubator/conda-zsh-completion.git" "" "https://github.com/zsh-users/zsh-syntax-highlighting.git")

    for i in "${!plugin_names[@]}"; do
      local name="${plugin_names[$i]}"
      local repo="${plugin_repos[$i]}"

      if [[ "$INTERACTIVE" -eq 1 ]]; then
        if ! confirm "Enable plugin: $name ?" 1; then
          continue
        fi
      fi

      selected_plugins+=("$name")
      if [[ -n "$repo" ]]; then
        clone_plugin "$name" "$repo"
      fi
    done

    update_plugins_in_zshrc=1
  fi

  if [[ "$do_update_zshrc" -eq 1 ]]; then
    update_zshrc "$update_plugins_in_zshrc" "${selected_plugins[@]}"
  fi

  if [[ "$do_set_shell" -eq 1 ]]; then
    set_default_shell
  fi

  log "Done. Open a new terminal or run: exec zsh"
}

main "$@"
