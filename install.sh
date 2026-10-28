#!/bin/bash

# Installs omarchy-patchwatch for the current user: the script into ~/.local/bin
# and the post-update / post-boot hooks into ~/.config/omarchy/hooks.

set -euo pipefail

cd "$(dirname "$0")"

for cmd in jq pacman; do
  command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2; exit 1; }
done
command -v gh >/dev/null || echo "Note: gh not found; PR merge status will show as unknown."

install -Dm755 omarchy-patchwatch "$HOME/.local/bin/omarchy-patchwatch"
install -Dm755 hooks/post-update.hook "$HOME/.config/omarchy/hooks/post-update.d/patchwatch.hook"
install -Dm755 hooks/post-boot.hook "$HOME/.config/omarchy/hooks/post-boot.d/patchwatch.hook"

echo "Installed. Track a patch with:"
echo "  omarchy-patchwatch add <pr> <package-file> <patched-copy> [original-copy] [test steps...]"
