#!/data/data/com.termux/files/usr/bin/bash
# uninstall.sh — safe, confirmation-gated removal. Only ever deletes
# precisely-targeted paths that this project itself created:
#   - the proot-distro rootfs for $DISTRO_ALIAS
#   - $HOME/.x11-installer (state/logs/cache/backup)
#   - the x11-start / x11-stop / ... wrapper commands this project installed
# It NEVER performs a recursive delete against $HOME, $PREFIX, or /storage.

run_uninstall() {
    echo "=================================================="
    echo "              X11 LINUX DESKTOP — UNINSTALL"
    echo "=================================================="
    echo ""
    echo "This will remove:"
    echo "  - The Linux environment ($DISTRO_DISPLAY_NAME) installed via proot-distro"
    echo "  - Installer state, logs, and cache in $INSTALLER_HOME"
    echo "  - The x11-start / x11-stop / x11-restart / x11-status / x11-repair / x11-uninstall commands"
    echo ""
    echo "This will NOT touch any other files in Termux or Android storage."
    echo ""
    printf "Type YES to confirm uninstall: "
    read -r confirm
    if [ "$confirm" != "YES" ]; then
        info "Uninstall cancelled."
        return 1
    fi

    info "Stopping any running desktop session first..."
    stop_everything

    detect_linux_installed
    if [ "$LINUX_INSTALLED" = "1" ]; then
        step_install "Removing Linux environment ($DISTRO_ALIAS)..."
        run_logged "proot-distro remove" proot-distro remove "$DISTRO_ALIAS"
    fi

    step_install "Removing installer state ($INSTALLER_HOME)..."
    rm -rf "${INSTALLER_HOME:?}"

    local bin_dir="$PREFIX/bin"
    local cmd
    for cmd in x11-start x11-stop x11-restart x11-status x11-repair x11-uninstall; do
        if [ -f "$bin_dir/$cmd" ]; then
            rm -f "$bin_dir/$cmd"
        fi
    done

    echo ""
    echo "Uninstall complete. Termux itself and all other files were left untouched."
}
