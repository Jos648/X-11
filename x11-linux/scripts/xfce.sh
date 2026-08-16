#!/data/data/com.termux/files/usr/bin/bash
# xfce.sh — install / verify the XFCE desktop environment inside the rootfs.

check_xfce_installed() {
    # A meaningful check: the core xfce4 metapackage AND the session binary
    # both need to be present — a half-finished apt run can leave the
    # metapackage "installed" in dpkg's eyes while startxfce4 is missing.
    if proot_login "dpkg -s xfce4 >/dev/null 2>&1 && command -v startxfce4 >/dev/null 2>&1" >/dev/null 2>&1; then
        XFCE_INSTALLED=1
        return 0
    fi
    XFCE_INSTALLED=0
    return 1
}

install_xfce() {
    detect_linux_installed
    if [ "$LINUX_INSTALLED" != "1" ]; then
        error "Cannot install XFCE: Linux environment is not installed."
        return 1
    fi

    if check_xfce_installed; then
        ok "XFCE already installed."
        mark_stage_done "06_xfce"
        return 0
    fi

    if [ "${NETWORK_OK:-0}" != "1" ]; then
        error "Cannot install XFCE without internet access."
        return 1
    fi

    step_repair "XFCE installation incomplete."
    step_install "Installing XFCE components: $LINUX_PACKAGES"

    if run_logged "apt install xfce" proot_login "DEBIAN_FRONTEND=noninteractive apt install -y $LINUX_PACKAGES"; then
        if check_xfce_installed; then
            ok "XFCE installed successfully."
            mark_stage_done "06_xfce"
            return 0
        fi
    fi

    error "XFCE installation failed or is still incomplete. See $LOG_FILE."
    return 1
}

xfce_process_running() {
    detect_xfce_session_running
    [ "$XFCE_RUNNING" = "1" ]
}
