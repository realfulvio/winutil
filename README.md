# WinUtil – redesigned interface (personal fork)

**English** | [Italiano](README.it.md)

This is a personal fork of [ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil) with an optional, redesigned interface. It is **not** the official project and it is not affiliated with it. The tweaks, installs and updates still run on upstream's engine: the logic was not changed.

> **Status:** the interface was built and checked without access to a Windows test machine. It compiles, loads as a WPF window, and its logic was exercised against simulated data, but it has **not been run end to end as the real program**. See [Project status](#project-status) before you use it.

## What is this fork, and why does it exist

WinUtil is powerful, but its default window is a long list of terse checkboxes. This fork adds a second interface, built to be easier to read and safer to use for people who are new to this kind of tool:

- A modern dark interface with a sidebar, search, filters and cards.
- Every tweak explained in plain words: what it changes, what could go wrong, and whether it can be undone.
- A preview before you apply: what each change touches, counted from the tweak's own data.
- Visible progress while changes are applied.
- Italian and English, switchable from the sidebar.
- Text that follows WinUtil's font scaling (Ctrl +/-), tap targets of at least 44 px, visible keyboard focus and text contrast of at least 4.5:1.

It is a fork, compatible with upstream. The original interface is still there (it is the default build), and the redesign is opt-in. Upstream files were left alone as far as possible, so merging upstream updates stays simple. **The logic of the tweaks, the app installs and the updates was not changed**; the redesign only adds a new window, styles and the code that fills it.

## What is improved

> Screenshots of the real program are **coming soon**. None are shown here on purpose: a mockup would not be the program, and the interface has not been run on a Windows machine yet.

### Sidebar and navigation
One place to move between Programs, Tweaks, Repair, Updates, Windows apps and Create ISO, each with a one-line description, plus a status card, Settings, About and the language button. These are the same tabs as upstream (Repair is upstream's Config tab).

> 📷 *Screenshot coming soon (sidebar and navigation).*

### Filters and search
Four filter chips with counters (Recommended, Privacy, System, Advanced) and a search box that looks at every tweak by name and description, in the language you picked.

> 📷 *Screenshot coming soon (filters and search).*

### Cards with safety tags
Each tweak is a card with a checkbox, an icon, a plain-language name and description, and tags: its category plus *Recommended*, *Safe* or *Advanced*. *Recommended* means the tweak is in upstream's Standard preset; *Advanced* means it is in upstream's "CAUTION" category (for example removing Edge, OneDrive or the Windows AI components) or it is a risky change of its own: services, Widgets removal, turning BitLocker off.

> 📷 *Screenshot coming soon (cards with safety tags).*

### "Before you apply" panel
Click a card to see, on the right: what changes, possible effects, whether it can be undone, and a warning when there is one. Whether a tweak can be undone is read from its own data (an undo script, an original registry value or an original service type), not typed by hand.

> 📷 *Screenshot coming soon ("Before you apply" panel).*

### Estimated impact
For the selected tweaks, how many services and registry values they touch, against everything the cards touch. A bar is shown only when the selection has that kind of data. There are no figures for memory, disk space or a privacy score because the repository has no data for them, and none are invented.

> 📷 *Screenshot coming soon (estimated impact).*

### Progress
While tweaks are applied, the panel shows the real step the engine is on and a percentage, then a "New selection" button when it ends. The step name is the one the engine reports (it still uses the tweak's internal name).

> 📷 *Screenshot coming soon (progress).*

### Language switch
Italian or English from the sidebar. All labels, descriptions, warnings and steps of the redesign come from one dictionary, [`ui/redesign/strings.json`](ui/redesign/strings.json). It starts in your Windows display language.

> 📷 *Screenshot coming soon (language switch).*

### What was not redesigned
Only the Tweaks tab has the new card layout. Programs, Repair, Updates, Windows apps and Create ISO keep their upstream layout inside the new window and sidebar, with the new dark palette. Switches, buttons and the Multiplane Overlay list apply immediately as upstream does and appear under "Other settings"; the DNS list is applied with the Apply button.

## Install and run

You need Windows with PowerShell and Git. WinUtil asks to relaunch itself as Administrator.

```powershell
git clone -b ui-redesign https://github.com/realfulvio/winutil.git
cd winutil
.\Compile.ps1 -Interface Redesign -Run
```

`Compile.ps1` builds `winutil.ps1` from the sources (the file is generated and is not committed). If PowerShell refuses to run it, allow scripts for this window only with `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`, then run it again.

## Go back to the original interface

The redesign is opt-in. Build without the switch, or use the official command:

```powershell
.\Compile.ps1 -Run
```

```powershell
irm https://christitus.com/win | iex
```

## Warning

**Tweaks change your system**: the registry, services, installed components and, for some, how drives and the network work. Not all of them can be undone, and some need a restart. Create a **restore point** before you apply anything (the *Restore point* tweak does it) and read each description first. **You use this at your own risk**; the software is provided as is, without warranty.

## Project status

What was checked (on a Windows host, without applying any tweak):

- `Compile.ps1` builds both variants; the default build is byte for byte what it was before this fork's changes.
- The generated script parses in PowerShell 7 and Windows PowerShell 5.1, and is ASCII only.
- The window loads as a WPF window with every control of upstream's window still present.
- The tab logic ran against simulated data: the 38 cards, selection, filters, search, language switch, the Apply button state, the impact figures, and the progress panel states.
- Images of the window rendered in memory with sample data were used to review the layout.

What was not checked: a real run on a Windows machine (opening the window, applying a tweak, undoing it), the Pester suite (it needs Pester 5.8.0, not available here), Script Analyzer and the docs site build. Details and decisions are in [`NOTE-LAVORO.md`](NOTE-LAVORO.md).

## Credits and license

All the engine, the tweaks, the app list and the original interface are the work of **[Chris Titus Tech](https://github.com/ChrisTitusTech)** and the contributors of [ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil); see its [contributors](https://github.com/ChrisTitusTech/winutil/graphs/contributors) and the [official documentation](https://winutil.christitus.com/). This fork keeps the upstream license: [MIT](LICENSE), copyright (c) 2022 CT Tech Group LLC. The redesign adds files under `ui/redesign/` and a `-Interface` switch in `Compile.ps1`.

---

# About the upstream project

*The rest of this page is upstream's README, kept as it is. Its commands run the official, unmodified WinUtil, not this fork's interface.*

# Chris Titus Tech's Windows Utility

[![Version](https://img.shields.io/github/v/release/ChrisTitusTech/winutil?color=%230567ff&label=Latest%20Release&style=for-the-badge)](https://github.com/ChrisTitusTech/winutil/releases/latest)
![Downloads](https://img.shields.io/github/downloads/ChrisTitusTech/winutil/winutil.ps1?label=Total%20Downloads&style=for-the-badge)
[![Discord](https://dcbadge.limes.pink/api/server/https://discord.gg/RUbZUZyByQ?theme=default-inverted&style=for-the-badge)](https://discord.gg/RUbZUZyByQ)

A curated compilation of Windows system tasks streamline **installs**, debloat with **tweaks**, troubleshoot with **config**, and configure **Windows updates**. Run it fresh on every new Windows install.

![Title Screen](docs/src/assets/branding/title-screen.png)


---

## Quick Start

> **WinUtil must be run as Administrator** because it performs system-wide changes.

Open PowerShell or Terminal as admin, then run:

**Stable Branch (recommended)**
```ps1
irm https://christitus.com/win | iex
```

**Development Branch**
```ps1
irm https://christitus.com/windev | iex
```

### How to open an admin terminal

- **Start menu:** Right-click Start → *Windows PowerShell (Admin)* or *Terminal (Admin)*
- **Search:** Press the `Windows key`, and type `PowerShell` or `Terminal`, then `Ctrl + Shift + Enter`

---

## Automation / Presets

Apply a predefined configuration without manual selection:

```powershell
& ([ScriptBlock]::Create((irm https://christitus.com/win))) -Preset Standard
```

| Preset | Description |
|--------|-------------|
| `Standard` | Balanced defaults for most users |
| `Minimal` | Minimal changes to suit every user |
| `Advanced` | Deep tweaks for power users |

To view exactly what each preset does, see:
https://github.com/ChrisTitusTech/winutil/blob/main/config/preset.json

---

## Build & Develop

See https://github.com/ChrisTitusTech/winutil/blob/main/.github/CONTRIBUTING.md

---

## Resources

- [Official Documentation](https://winutil.christitus.com/)
- [YouTube Tutorial](https://www.youtube.com/watch?v=6UQZ5oQg8XA)
- [ChrisTitus.com Article](https://christitus.com/windows-tool/)
- [Known Issues](https://winutil.christitus.com/knownissues/)
- [Report an Issue](https://github.com/ChrisTitusTech/winutil/issues)

---

## Support

- Leave a ⭐ to show support!
- Faster Dotnet Implementation for sale here: https://www.cttstore.com/windows-toolbox

## Sponsors

These are the sponsors that help keep this project alive with monthly contributions.

<!-- sponsors --><a href="https://github.com/dwelfusius"><img src="https:&#x2F;&#x2F;github.com&#x2F;dwelfusius.png" width="60px" alt="User avatar: " /></a><a href="https://github.com/mews-se"><img src="https:&#x2F;&#x2F;github.com&#x2F;mews-se.png" width="60px" alt="User avatar: Martin" /></a><a href="https://github.com/jdiegmueller"><img src="https:&#x2F;&#x2F;github.com&#x2F;jdiegmueller.png" width="60px" alt="User avatar: Jason A. Diegmueller" /></a><a href="https://github.com/robertsandrock"><img src="https:&#x2F;&#x2F;github.com&#x2F;robertsandrock.png" width="60px" alt="User avatar: RMS" /></a><a href="https://github.com/paulsheets"><img src="https:&#x2F;&#x2F;github.com&#x2F;paulsheets.png" width="60px" alt="User avatar: Paul" /></a><a href="https://github.com/djones369"><img src="https:&#x2F;&#x2F;github.com&#x2F;djones369.png" width="60px" alt="User avatar: Dave J  (WhamGeek)" /></a><a href="https://github.com/anthonymendez"><img src="https:&#x2F;&#x2F;github.com&#x2F;anthonymendez.png" width="60px" alt="User avatar: Anthony Mendez" /></a><a href="https://github.com/FatBastard0"><img src="https:&#x2F;&#x2F;github.com&#x2F;FatBastard0.png" width="60px" alt="User avatar: " /></a><a href="https://github.com/DursleyGuy"><img src="https:&#x2F;&#x2F;github.com&#x2F;DursleyGuy.png" width="60px" alt="User avatar: DursleyGuy" /></a><a href="https://github.com/DwayneTheRockLobster1"><img src="https:&#x2F;&#x2F;github.com&#x2F;DwayneTheRockLobster1.png" width="60px" alt="User avatar: " /></a><a href="https://github.com/KieraKujisawa"><img src="https:&#x2F;&#x2F;github.com&#x2F;KieraKujisawa.png" width="60px" alt="User avatar: Kiera Meredith" /></a><a href="https://github.com/seanh1995"><img src="https:&#x2F;&#x2F;github.com&#x2F;seanh1995.png" width="60px" alt="User avatar: Sean (ANGRYxScotsman)" /></a><a href="https://github.com/josencarnacao"><img src="https:&#x2F;&#x2F;github.com&#x2F;josencarnacao.png" width="60px" alt="User avatar: José Encarnação" /></a><!-- sponsors -->

*<sub>Sponsors with a recurring subscription also get access to the .NET alternative.</sub>

---

## Contributors

[![Contributors](https://contrib.rocks/image?repo=ChrisTitusTech/winutil)](https://github.com/ChrisTitusTech/winutil/graphs/contributors)

Thanks to everyone who has contributed time and effort to this project. Keep rocking 🍻
