# x11-linux

A self-healing installer that turns Termux on Android into a graphical
Linux XFCE desktop, using `proot-distro` for the Linux userspace and
**Termux:X11** to display it.

```
Android → Termux → proot-distro → Linux ARM64 userspace → XFCE Desktop → Termux:X11 → Graphical desktop
```

One command does everything:

```bash
cd x11-linux
chmod +x x11.sh
./x11.sh
```

`./x11.sh` detects your environment, installs whatever is missing, repairs
anything broken, verifies every subsystem, and starts the XFCE desktop. Run
it again any time — it's idempotent and will skip what's already done.

---

## Requirements

- Android device, **arm64/aarch64 only** (checked via `uname -m`; anything
  else stops with a clear error — there is no fallback for other
  architectures)
- [Termux](https://termux.dev) (F-Droid build recommended)
- The **Termux:X11** Android app, installed separately from the Play
  Store / F-Droid / GitHub releases
- A working internet connection for the first run (subsequent runs work
  offline once everything is installed)
- A few GB of free storage (a Debian XFCE rootfs is roughly 1–2 GB)

---

## Important: there is no Linux Mint here, on purpose

The original goal was Linux Mint. `proot-distro` — the tool this project
uses to run a Linux userspace inside Termux — **does not publish a Mint or
LMDE rootfs**. There is no official, verifiable Mint ARM64 image that
plugs into `proot-distro install`. Rather than fake it, this project:

- always installs **Debian ARM64 + XFCE** as the real target
- reports it honestly, every time, e.g.:

  ```
  Linux distribution : Debian ARM64
  Desktop             : XFCE
  Mode                : Fallback
  Reason              : Linux Mint ARM64 rootfs unavailable
  ```

- never labels Debian as "Mint" anywhere in output, logs, or status

If you want a Mint-like experience on top of this, you could layer Mint's
XFCE theme/panel layout onto the Debian+XFCE install afterward — that's a
cosmetic change you can do by hand and is outside what this installer
claims to do.

---

## Commands

Installed into `$PREFIX/bin` after the first successful run, so they work
from anywhere:

| Command          | Purpose                                                |
|-------------------|---------------------------------------------------------|
| `x11-start`       | Full detect/install/repair/verify/launch (same as `./x11.sh`) |
| `x11-stop`        | Stop the desktop + Termux:X11 server. **Never touches Termux itself.** |
| `x11-restart`     | Stop, then start the desktop again                      |
| `x11-status`      | Read-only status report — changes nothing                |
| `x11-repair`      | Force a full repair cycle, even if checkpoints say it's done |
| `x11-uninstall`   | Remove the Linux environment (asks for typed `YES` confirmation) |

`./x11.sh --help` lists the same options if you prefer running from the
project directory directly.

---

## What each run actually checks

```
[1/11]  Termux             [2/11]  Architecture        [3/11]  Dependencies
[4/11]  Linux environment  [5/11]  Base system          [6/11]  XFCE
[7/11]  DBus               [8/11]  Audio                [9/11]  X11
[10/11] Desktop start      [11/11] Final verification
```

Every stage follows: **DETECT → DIAGNOSE → REPAIR → VERIFY**. Nothing is
reported as working unless it was actually tested — e.g. "X11: CONNECTED"
only appears after `xdpyinfo`/`xset` genuinely confirms the connection,
not just because a process is running.

Progress is checkpointed under `~/.x11-installer/state/`, so an
interrupted run resumes intelligently instead of restarting from scratch.
Full logs (`INFO`/`OK`/`WARN`/`ERROR`/`CHECK`/`INSTALL`/`REPAIR`) go to
`~/.x11-installer/logs/x11.log`.

### Critical vs. non-critical failures

- **Critical** (stop the run): unsupported architecture, Linux rootfs
  can't install, XFCE can't install, X11 can't connect after repair
- **Non-critical** (warn, then continue): optional package missing,
  PulseAudio unavailable, storage access not granted

The script never uses `set -e` for this reason — it needs to distinguish
these cases rather than dying on the first non-zero exit code anywhere.

---

## Project layout

```
x11-linux/
├── x11.sh                  # single entry point — orchestrates everything
├── scripts/
│   ├── common.sh            # logging, checkpoints, shared helpers
│   ├── detect.sh             # read-only environment detection
│   ├── dependencies.sh       # Termux-side package installation
│   ├── linux.sh               # proot-distro rootfs install/repair
│   ├── xfce.sh                 # XFCE package install/verify
│   ├── dbus.sh                  # DBus session setup/repair
│   ├── audio.sh                  # PulseAudio bridge (non-critical)
│   ├── x11.sh                     # Termux:X11 server + connection test
│   ├── desktop.sh                  # launch/stop/verify the XFCE session
│   ├── repair.sh                    # the 11-step self-healing cycle
│   ├── status.sh                     # read-only status report
│   ├── stop.sh                        # safe, targeted shutdown
│   └── uninstall.sh                    # confirmation-gated removal
├── config/
│   └── x11.conf              # package lists, distro choice, thresholds
├── logs/                     # (runtime logs also live in ~/.x11-installer/logs)
└── README.md
```

---

## Known, honest limitations

- **Termux cannot query which Android apps are installed.** There is no
  supported API for Termux to ask "is the Termux:X11 app present". This
  script cannot detect the app directly — it starts the X server and
  actually tests the connection with `xdpyinfo`/`xset`. If that fails, it
  shows the `TERMUX:X11 REQUIRED` notice rather than guessing.
- **Hardware acceleration is not assumed.** The desktop launches with
  `LIBGL_ALWAYS_SOFTWARE=1` (software rendering). Whether your specific
  device/driver stack supports anything better through
  Termux+proot+Termux:X11 varies too much to claim GPU acceleration
  generically, so this project doesn't claim it.
- **Audio depends on your device's PulseAudio support.** It's treated as
  fully optional: `[WARN] Audio unavailable` never blocks the desktop.

---

## Uninstalling

```bash
x11-uninstall
```

Removes only what this project created: the `proot-distro` Debian rootfs,
`~/.x11-installer/`, and the `x11-*` wrapper commands. It asks you to type
`YES` to confirm and never runs a recursive delete against `$HOME`,
`$PREFIX`, or `/storage`.

---

## Testing status — read this before trusting "PASS"

This project was built and reviewed in a Linux (not Android/Termux)
development sandbox with no access to `proot-distro`, `termux-x11`, or a
real Termux:X11 app. Being honest about what was and wasn't verified here
matters more than a clean-looking table, so:

**Actually verified in this environment:**
- `bash -n` syntax check on every script: **PASS** (all 14 files)
- `shellcheck -S style` (strictest level) on the full sourced chain from
  `x11.sh`: **PASS**, zero warnings
- Logic of `common.sh` (checkpoints, logging, idempotent `mark_stage_done`):
  exercised directly, behaves as designed
- `ensure_x11_working()` with no `termux-x11` binary present: correctly
  reports `[NOT SUPPORTED]`, shows the `TERMUX:X11 REQUIRED` notice, and
  returns failure — **never fakes a CONNECTED state**
- `run_uninstall()` with a non-`YES` response: correctly cancels and
  changes nothing
- `install_wrapper_commands()`: generates correct, working wrapper scripts
- Architecture gate: a mocked `x86_64` `uname -m` correctly triggers a
  critical `die()` with a clear message and non-zero exit, no fake success
- Distro reporting: confirmed it always prints "Debian ARM64 / Fallback /
  Linux Mint ARM64 rootfs unavailable" and never says "Mint"

**Not verified here, because it requires a real device (TEST 1–5, 7, 9,
10, 12, 13, 16–18 from the original spec fall in this bucket):**
- Actual `proot-distro install debian` completing on a real device
- Actual `termux-x11 :0` binding to a real Termux:X11 app and a real
  `xdpyinfo`/`xset` connection succeeding
- Actual `startxfce4` producing a usable desktop through that connection
- Real low-RAM device behavior, real APT failure/retry behavior, and
  real interrupted-install resume behavior

If you run this on an actual Termux install, `x11-status` after a run
will tell you exactly which of the 11 stages succeeded and which didn't —
please report back anything that fails so it can be fixed rather than
assumed working.
