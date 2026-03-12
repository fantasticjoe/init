# init
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

Copyright (c) 2026 Zhouyue Zhu

One-shot setup script for a new server: installs zsh, Oh My Zsh, and a curated plugin set, then updates `~/.zshrc`.

# Usage

```bash
./init.sh
```

Non-interactive mode runs all steps by default (except Miniforge3). Interactive mode asks for each step and each plugin (default is Yes).

# Features

- Install system packages: zsh, git, curl, wget, ca-certificates
- Install Oh My Zsh
- Optional Miniforge3 install (default: No)
- Install Zsh plugins
- Update `~/.zshrc` with theme and plugins
- Optionally set zsh as the default shell

# Plugins

- git
- zsh-syntax-highlighting
- z
- zsh-autosuggestions
- conda-zsh-completion
- extract

Note: `zsh-syntax-highlighting` is placed last in the plugin list to avoid rendering issues.

# Permissions

- Root: installs system packages directly.
- Non-root sudoer: prompts for sudo password and installs system packages.
- Non-root non-sudoer: skips system package install and continues with user-space steps.

# Supported package managers

- apt-get
- dnf
- yum
- pacman
- apk
- zypper
- pkg (FreeBSD)
- port (MacPorts)
- brew (Homebrew)

# Supported systems

- macOS (Homebrew or MacPorts)
- Linux (common distros):
- Ubuntu / Debian (apt-get)
- CentOS / RHEL / Rocky / AlmaLinux (yum)
- Fedora (dnf)
- Arch / Manjaro (pacman)
- Alpine (apk)
- openSUSE (zypper)

Notes:
- FreeBSD is supported for package install via `pkg`, but Miniforge3 is not available on FreeBSD
- Arch/Manjaro uses `pacman -Sy` (no full upgrade) by default
- Interactive mode can opt into `pacman -Syu` (full upgrade)

# CPU architectures

- x86_64 / amd64
- arm64 / aarch64

# Miniforge3

- Default install path: `~/miniforge3`
- Override with `MINIFORGE_PREFIX=/your/path`
- After install, the script can run `conda init zsh` (default: Yes in interactive mode)

Non-interactive overrides:

- `MINIFORGE_INSTALL=1` to enable Miniforge3 install
- `MINIFORGE_CONDA_INIT=0` to skip `conda init zsh`
- `PACMAN_FULL_UPGRADE=1` to allow `pacman -Syu` on Arch/Manjaro

# Safety notes

- System package installs require root/sudo; if not available, the script skips that step and continues user-space setup.
- Remote installs (Oh My Zsh, Miniforge3, plugins) are fetched from official sources; review or pin versions if you need stricter supply-chain controls.

# License

MIT. See `LICENSE`.
