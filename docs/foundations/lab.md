---
title: 'Lab 1: set up your tools'
description: Install Git, OpenTofu and the Azure CLI, and verify each one.
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 1: set up your tools

Time: about 30 minutes. Cost: nothing. Cloud account: not needed yet.

You will install and verify the three command-line tools the course uses, and make sure your GitHub account is ready.

## 1. Git and a GitHub account

You likely have both. To verify Git:

```bash
git --version
```

Any version from the last few years is fine. If it is missing, install it from [git-scm.com](https://git-scm.com/downloads) or your package manager.

If you do not have a GitHub account, create a free one at [github.com/signup](https://github.com/signup). The free plan covers everything in this course, including private repositories and enough Actions minutes, though the labs use a public repository (that choice matters later; Module 5 explains why).

Set your identity if this machine has never used Git:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

## 2. OpenTofu

<Tabs groupId="os">
<TabItem value="windows" label="Windows" default>

Using WinGet, the package manager built into Windows 10 and 11:

```powershell
winget install --exact --id=OpenTofu.Tofu
```

Then **open a new terminal window** (the installer edits the PATH, and already-open terminals do not see the change). If `tofu` is still not found in a new window, check that `%LOCALAPPDATA%\Microsoft\WinGet\Links` is on your PATH; the WinGet installer places its shims there.

</TabItem>
<TabItem value="macos" label="macOS">

Using Homebrew:

```bash
brew update
brew install opentofu
```

</TabItem>
<TabItem value="linux" label="Linux">

The portable method that works on any distribution is the official installer script:

```bash
curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
chmod +x install-opentofu.sh
./install-opentofu.sh --install-method standalone
rm -f install-opentofu.sh
```

Debian/Ubuntu apt repositories, RPM repositories, Snap and Homebrew for Linux are also available; see the [official install page](https://opentofu.org/docs/intro/install/) if you prefer a native package.

</TabItem>
</Tabs>

Verify, on any platform:

```bash
tofu -version
```

Expected output looks like this (your patch version may be newer):

```text
OpenTofu v1.12.5
on windows_amd64
```

The course targets the 1.12 series. Anything 1.12.0 or later is fine. If your package manager gives you an older version, use the standalone installer instead.

## 3. Azure CLI

The Azure CLI (`az`) is Microsoft's command-line tool for managing Azure. You will use it for one-time setup tasks that should be done by a human: creating your identity federation, the state storage, and role assignments. The pipeline itself will not use it to authenticate.

<Tabs groupId="os">
<TabItem value="windows" label="Windows" default>

```powershell
winget install --exact --id=Microsoft.AzureCLI
```

Then open a new terminal window.

</TabItem>
<TabItem value="macos" label="macOS">

```bash
brew update
brew install azure-cli
```

</TabItem>
<TabItem value="linux" label="Linux">

On Debian/Ubuntu, Microsoft's documented one-line installer:

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

For RPM-based distributions and others, follow the [official install page](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli).

</TabItem>
</Tabs>

Verify:

```bash
az version
```

You should see JSON output with an `azure-cli` version of 2.88.0 or later. Do **not** run `az login` yet; that is part of Module 3, after you have an account worth logging into.

## 4. Optional but recommended: a code editor

Any editor works. If you use Visual Studio Code, syntax highlighting for HCL and YAML makes the labs pleasant, and the built-in Git integration helps. No specific extension is required for the course.

## Checklist

You can now:

- [ ] Run `git --version`, `tofu -version` and `az version` successfully in one terminal.
- [ ] Sign in to a GitHub account that can create public repositories.
- [ ] Explain the difference between imperative and declarative infrastructure automation.
- [ ] Name the four systems in the target pipeline and the single job each one does.
- [ ] Say why no long-lived cloud credential will ever appear in this course.

## Common failure modes

**`tofu` (or `az`) is not recognized after installing on Windows.**
The installer updated PATH, but your terminal predates the change. Close every terminal window and open a fresh one. Still failing: check `%LOCALAPPDATA%\Microsoft\WinGet\Links` is on PATH for WinGet-installed tools.

**`winget` itself is not found.**
WinGet ships with the "App Installer" package from the Microsoft Store. Install or update "App Installer", then retry. On locked-down corporate machines you may need the MSI installers from each tool's website instead.

**Homebrew installs an old OpenTofu.**
Run `brew update` before `brew install`. If the version is still below 1.12, use the standalone installer script, which always fetches a current release.

**The Linux installer script fails with a TLS or proxy error.**
Corporate proxies that intercept TLS break the `--proto '=https' --tlsv1.2` protections on purpose. Talk to whoever runs your proxy, or download a release binary manually from the OpenTofu releases page and place it on your PATH.

Module 1 done. Continue to Module 2, where you write your first workflows.
