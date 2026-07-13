#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly -a PACKAGES=(
  cava
  hyprland
  kitty
  matugen
  qt6ct-kde
  qt5ct-kde
  zsh
  kde-material-you-colors
  quickshell-git
  hypridle
  adw-gtk-theme
  matugen
  vesktop
  visual-studio-code-bin
)

if [[ ! -r /etc/arch-release ]] || ! command -v pacman >/dev/null 2>&1; then
  printf 'Error: this installer only supports Arch Linux and its derivatives.\n' >&2
  exit 1
fi

if ! command -v gum >/dev/null 2>&1; then
  echo "Installing Gum"
  sudo pacman -S --needed gum
fi

gum style \
  --foreground FFF --border-foreground FFF --border rounded \
  --align center --width 50 --margin "1 2" --padding "2 4" \
  'Comic Dotfiles'

echo "Welcome to Comic Dotfiles"
echo "This installer supports Arch Linux and its derivatives only."
echo "Existing dotfiles will be backed up before the new ones are installed."

if ! gum confirm "Continue with the installation?"; then
  echo "Installation cancelled."
  exit 0
fi

echo "Before installing, sudo permission is required."
sudo -v
echo "Sudo permission granted."

install_yay() {
  local build_dir
  build_dir="$(mktemp -d --tmpdir comic-yay.XXXXXX)"
  trap 'rm -rf -- "$build_dir"' RETURN

  sudo pacman -S --needed git base-devel
  git clone https://aur.archlinux.org/yay-bin.git "$build_dir"
  (
    cd -- "$build_dir"
    makepkg -si
  )
}

install_packages() {
  local package

  for package in "$@"; do
    if pacman -Q -- "$package" >/dev/null 2>&1; then
      printf '%s is already installed.\n' "$package"
      continue
    fi

    if ! gum spin \
      --spinner dot \
      --title "Installing $package" \
      --show-error \
      -- yay -S --needed --noconfirm -- "$package"; then
      printf 'Error: failed to install %s.\n' "$package" >&2
      return 1
    fi
  done
}

install_dotfiles() {
  local dots_dir="$SCRIPT_DIR/dots"
  local backup_dir="$HOME/.comic-dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
  local source relative target
  local backed_up=false

  if [[ ! -d "$dots_dir" ]]; then
    printf 'Error: dotfiles directory not found: %s\n' "$dots_dir" >&2
    return 1
  fi

  while IFS= read -r -d '' source; do
    relative="${source#"$dots_dir"/}"
    target="$HOME/$relative"

    if [[ -e "$target" || -L "$target" ]]; then
      mkdir -p -- "$backup_dir/$(dirname -- "$relative")"
      cp -a -- "$target" "$backup_dir/$relative"
      backed_up=true
    fi

    mkdir -p -- "$(dirname -- "$target")"
    cp -a -- "$source" "$target"
  done < <(find "$dots_dir" -type f -print0)

  if [[ "$backed_up" == true ]]; then
    printf 'Existing dotfiles were backed up to %s\n' "$backup_dir"
  fi
  echo "Comic Dotfiles installed successfully."
}

if command -v yay >/dev/null 2>&1; then
  echo "Yay is already installed."
else
  echo "Installing Yay"
  install_yay
fi

install_packages "${PACKAGES[@]}"
install_dotfiles
