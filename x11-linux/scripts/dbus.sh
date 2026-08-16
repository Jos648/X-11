#!/data/data/com.termux/files/usr/bin/bash
# dbus.sh — DBus session configuration for the XFCE session inside the rootfs.

configure_dbus() {
    detect_linux_installed
    if [ "$LINUX_INSTALLED" != "1" ]; then
        error "Cannot configure DBus: Linux environment is not installed."
        return 1
    fi

    if ! proot_login "command -v dbus-launch >/dev/null 2>&1"; then
        warn "dbus-x11 (dbus-launch) not found inside the Linux environment."
        step_repair "Installing dbus-x11..."
        if ! run_logged "install dbus-x11" proot_login "DEBIAN_FRONTEND=noninteractive apt install -y dbus dbus-x11"; then
            error "Failed to install DBus components."
            return 1
        fi
    fi

    # Ensure a machine-id exists; DBus refuses to run without one, and a
    # freshly debootstrapped rootfs sometimes lacks it.
    if ! proot_login "test -s /etc/machine-id"; then
        step_repair "Generating missing /etc/machine-id..."
        run_logged "dbus-uuidgen" proot_login "dbus-uuidgen --ensure"
    fi

    ok "DBus is configured."
    mark_stage_done "07_dbus"
    return 0
}

dbus_session_active() {
    detect_dbus_session
    [ "$DBUS_SESSION_SET" = "1" ]
}
