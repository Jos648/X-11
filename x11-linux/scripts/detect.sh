#!/data/data/com.termux/files/usr/bin/bash
# detect.sh — environment detection. Sourced, not executed.
# Every function here is read-only: it inspects the system and sets
# variables / returns status codes. It never installs or changes anything.

detect_termux() {
    if [ -n "${PREFIX:-}" ] && [[ "$PREFIX" == *com.termux* ]]; then
        IS_TERMUX=1
        return 0
    fi
    IS_TERMUX=0
    return 1
}

detect_android() {
    if [ -d /system ] && [ -f /system/build.prop -o -d /system/app ]; then
        IS_ANDROID=1
        return 0
    fi
    # Termux itself only exists on Android, so being in Termux is already
    # strong evidence, but we keep this check independent and honest.
    if [ "${IS_TERMUX:-0}" = "1" ]; then
        IS_ANDROID=1
        return 0
    fi
    IS_ANDROID=0
    return 1
}

detect_arch() {
    ARCH="$(uname -m)"
    case "$ARCH" in
        aarch64|arm64)
            ARCH_SUPPORTED=1
            ;;
        *)
            ARCH_SUPPORTED=0
            ;;
    esac
}

detect_ram_mb() {
    if [ -r /proc/meminfo ]; then
        RAM_TOTAL_MB=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 1024 ))
    else
        RAM_TOTAL_MB=0
    fi
}

detect_storage_mb() {
    # Free space on $HOME's filesystem, in MB.
    STORAGE_FREE_MB=$(df -Pm "$HOME" 2>/dev/null | awk 'NR==2{print $4}')
    [ -z "$STORAGE_FREE_MB" ] && STORAGE_FREE_MB=0
}

detect_network() {
    if have_cmd curl; then
        if with_timeout "${NET_CHECK_TIMEOUT:-6}" curl -fsS -o /dev/null "https://deb.debian.org"; then
            NETWORK_OK=1
            return 0
        fi
    fi
    if have_cmd wget; then
        if with_timeout "${NET_CHECK_TIMEOUT:-6}" wget -q --spider "https://deb.debian.org"; then
            NETWORK_OK=1
            return 0
        fi
    fi
    NETWORK_OK=0
    return 1
}

detect_proot_distro() {
    if have_cmd proot-distro; then
        PROOT_DISTRO_AVAILABLE=1
        return 0
    fi
    PROOT_DISTRO_AVAILABLE=0
    return 1
}

# Path where proot-distro stores an installed rootfs for a given alias.
proot_rootfs_path() {
    echo "$PREFIX/var/lib/proot-distro/installed-rootfs/$1"
}

detect_linux_installed() {
    local alias="${DISTRO_ALIAS:-debian}"
    local path
    path="$(proot_rootfs_path "$alias")"
    if [ -d "$path" ] && [ -x "$path/bin/bash" -o -x "$path/usr/bin/bash" ]; then
        LINUX_INSTALLED=1
        return 0
    fi
    LINUX_INSTALLED=0
    return 1
}

# Detects whether the rootfs directory exists but looks incomplete/corrupt
# (e.g. interrupted install left a partial directory tree).
detect_linux_incomplete() {
    local alias="${DISTRO_ALIAS:-debian}"
    local path
    path="$(proot_rootfs_path "$alias")"
    if [ -d "$path" ] && [ ! -x "$path/bin/bash" ] && [ ! -x "$path/usr/bin/bash" ]; then
        return 0
    fi
    return 1
}

# Termux-side termux-x11 binary (from termux-x11-nightly package). This is
# NOT the same thing as the Termux:X11 Android application — the binary can
# be present while the companion app is missing, and vice versa in theory.
# There is no supported API from inside Termux to query which Android apps
# are installed, so the only honest way to confirm the Termux:X11 app is
# reachable is to actually try starting a display and testing the
# connection (done in scripts/x11.sh). This function only checks the
# Termux-side prerequisite.
detect_termux_x11_binary() {
    if have_cmd termux-x11; then
        TERMUX_X11_BINARY=1
        return 0
    fi
    TERMUX_X11_BINARY=0
    return 1
}

detect_display_var() {
    if [ -n "${DISPLAY:-}" ]; then
        DISPLAY_SET=1
    else
        DISPLAY_SET=0
    fi
}

detect_xfce_session_running() {
    if pgrep -f "xfce4-session" >/dev/null 2>&1; then
        XFCE_RUNNING=1
        return 0
    fi
    # Also check inside the proot rootfs process namespace is not possible
    # cleanly from the host with pgrep alone since proot processes still
    # show up in the shared Android process table, so the host-side pgrep
    # above is actually sufficient in the vast majority of proot-distro
    # setups (no separate PID namespace).
    XFCE_RUNNING=0
    return 1
}

detect_dbus_session() {
    if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        DBUS_SESSION_SET=1
        return 0
    fi
    if pgrep -x "dbus-daemon" >/dev/null 2>&1; then
        DBUS_SESSION_SET=1
        return 0
    fi
    DBUS_SESSION_SET=0
    return 1
}

detect_pulseaudio() {
    if pgrep -x "pulseaudio" >/dev/null 2>&1; then
        PULSEAUDIO_RUNNING=1
        return 0
    fi
    PULSEAUDIO_RUNNING=0
    return 1
}

detect_storage_access() {
    if [ -d "$HOME/storage/shared" ]; then
        STORAGE_ACCESS=1
        return 0
    fi
    STORAGE_ACCESS=0
    return 1
}

# Runs every read-only detector and populates the variables used elsewhere.
# Does not print anything — callers decide how to present the results.
run_full_detection() {
    detect_termux
    detect_android
    detect_arch
    detect_ram_mb
    detect_storage_mb
    detect_network
    detect_proot_distro
    detect_linux_installed
    detect_termux_x11_binary
    detect_display_var
    detect_xfce_session_running
    detect_dbus_session
    detect_pulseaudio
    detect_storage_access
}
