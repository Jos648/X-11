#!/data/data/com.termux/files/usr/bin/bash
# linux.sh — install / repair the Linux rootfs via proot-distro.
#
# HONESTY NOTE (do not remove): proot-distro's supported distro list does
# not include Linux Mint or LMDE. There is no official Mint ARM64 rootfs
# distributed for proot-distro. This script therefore always targets
# Debian ARM64 (DISTRO_ALIAS in config/x11.conf) and reports it as a
# fallback rather than mislabeling it as Mint anywhere in output or logs.

report_distro_choice() {
    echo "Linux distribution : $DISTRO_DISPLAY_NAME"
    echo "Desktop             : XFCE"
    echo "Mode                : $DISTRO_MODE"
    echo "Reason              : $DISTRO_FALLBACK_REASON"
}

proot_login() {
    # proot_login "command string to run as root inside the rootfs"
    proot-distro login "$DISTRO_ALIAS" -- bash -lc "$1"
}

install_linux_rootfs() {
    detect_linux_installed
    if [ "$LINUX_INSTALLED" = "1" ]; then
        ok "Linux environment already installed ($DISTRO_DISPLAY_NAME)."
        mark_stage_done "04_linux"
        return 0
    fi

    if detect_linux_incomplete; then
        step_repair "Previous $DISTRO_DISPLAY_NAME installation looks incomplete."
        step_repair "Removing broken rootfs before reinstalling..."
        run_logged "remove broken rootfs" proot-distro remove "$DISTRO_ALIAS"
    fi

    if [ "${PROOT_DISTRO_AVAILABLE:-0}" != "1" ]; then
        error "proot-distro is not installed; cannot install a Linux environment."
        return 1
    fi

    if [ "${NETWORK_OK:-0}" != "1" ]; then
        error "Cannot download $DISTRO_DISPLAY_NAME rootfs without internet access."
        return 1
    fi

    step_install "Installing Linux environment ($DISTRO_DISPLAY_NAME)..."
    if run_logged "proot-distro install $DISTRO_ALIAS" proot-distro install "$DISTRO_ALIAS"; then
        detect_linux_installed
        if [ "$LINUX_INSTALLED" = "1" ]; then
            ok "$DISTRO_DISPLAY_NAME installed."
            mark_stage_done "04_linux"
            return 0
        fi
    fi

    error "proot-distro install $DISTRO_ALIAS failed. See $LOG_FILE."
    return 1
}

update_base_system() {
    detect_linux_installed
    if [ "$LINUX_INSTALLED" != "1" ]; then
        error "Cannot update base system: Linux environment is not installed."
        return 1
    fi

    if [ "${NETWORK_OK:-0}" != "1" ]; then
        warn "No internet access — skipping apt update/upgrade this run."
        return 1
    fi

    step_check "Updating base system (apt update && apt upgrade)..."
    if run_logged "apt update" proot_login "apt update"; then
        run_logged "apt upgrade" proot_login "DEBIAN_FRONTEND=noninteractive apt upgrade -y"
        ok "Base system up to date."
        mark_stage_done "05_base_system"
        return 0
    else
        warn "apt update failed inside the Linux environment."
        step_repair "Attempting apt repair (fix-broken / clean)..."
        run_logged "apt --fix-broken install" proot_login "apt --fix-broken install -y"
        run_logged "apt clean" proot_login "apt clean"
        if run_logged "apt update retry" proot_login "apt update"; then
            ok "apt repaired successfully."
            mark_stage_done "05_base_system"
            return 0
        fi
        error "apt is still broken after repair attempt."
        return 1
    fi
}
