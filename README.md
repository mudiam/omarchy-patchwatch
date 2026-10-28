# omarchy-patchwatch

Tells you when an [Omarchy](https://github.com/omacom/omarchy) update undoes a PR patch you installed by hand, or when that PR merges.

If you test an open PR by copying its version of a file over the packaged one (say `/usr/share/omarchy/shell/plugins/lock/LockView.qml`), the next `omarchy update` silently puts the packaged file back and the bug returns. patchwatch keeps a ledger of those patches and checks them after every update and at login.

It runs locally and never posts anything to GitHub. `gh` is only used, read-only, to ask whether a PR has merged.

## Install

```bash
git clone https://github.com/mudiam/omarchy-patchwatch.git
cd omarchy-patchwatch
./install.sh
```

This installs `~/.local/bin/omarchy-patchwatch` and two hooks:

- `~/.config/omarchy/hooks/post-update.d/patchwatch.hook` runs after `omarchy update`.
- `~/.config/omarchy/hooks/post-boot.d/patchwatch.hook` runs at login, so updates made with plain `pacman`/`yay` are caught too.

Both only show a notification when something new turns up. Clicking it opens your default agent (`omarchy agent prompt`) to go through the findings.

Requires `jq`. `gh` is optional (signed in, for PR merge status).

## Usage

Track a patch: give the PR number, the package file, a copy of the patched file and, ideally, a copy of the original. Optional trailing words are a note on how to re-test it.

```bash
omarchy-patchwatch add 8560 /usr/share/omarchy/shell/plugins/lock/LockView.qml \
  ~/pr8560/LockView.qml ~/pr8560/LockView.qml.orig \
  "Lock, suspend, wake: the password field takes typing without a click"
```

The copies are stored under `~/.config/omarchy-patchwatch/patches/`, so the originals you downloaded can go.

Check at any time:

```bash
omarchy-patchwatch check          # human-readable
omarchy-patchwatch check --json   # machine-readable
```

| Finding | Level | Meaning |
| --- | --- | --- |
| patch in place | ok | The live file matches your patched copy. |
| overwritten | warn | An update put the original back. Prints the `sudo install` line to restore your patch. |
| overwritten, file changed upstream | warn | The new packaged file differs from the one you patched. Copying your old patch back would undo upstream changes, so re-apply the PR diff instead (`gh pr diff`). |
| missing | warn | The packaged file no longer exists. |
| PR merged and shipped | info | The fix is upstream. Re-test on your hardware, then `retire` it. |
| merged, patch still installed | info | The PR merged but your copy is still in place; the next update replaces it. |
| untracked local edit | info | `pacman -Qkk omarchy omarchy-settings` reports a size or checksum change to a file the ledger doesn't know about. No sudo needed. |

Other commands:

```bash
omarchy-patchwatch ack <key>      # "It's fine": stay quiet until the finding changes
omarchy-patchwatch retire <key>   # stop tracking a patch (saved copies are kept)
```

## Files

- `~/.config/omarchy-patchwatch/ledger.json`: tracked patches.
- `~/.config/omarchy-patchwatch/patches/`: saved patched and original files. Worth keeping in your dotfiles, so a reinstall can restore them.
- `~/.local/state/omarchy-patchwatch/`: acknowledged findings and the last notification.

## Findings format

Each finding uses the same shape as [omarchy-doctor](https://github.com/nixfred/omarchy-doctor) checks:

```json
{"key": "...", "state": "...", "title": "...", "advice": "...", "details": "...",
 "command": "...", "level": "ok|info|warn", "signature": "..."}
```

`ack` works off `key` and `signature` like Doctor's "It's fine", so this could later become a Doctor check or a bar widget.

## Background

This started as an [idea on the Omarchy discussions](https://github.com/omacom/omarchy/discussions/16333). This is the local part of it, which needs no GitHub posting.

## License

MIT
