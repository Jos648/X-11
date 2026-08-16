#!/data/data/com.termux/files/usr/bin/bash
# repair.sh — DETECT -> DIAGNOSE -> REPAIR -> VERIFY across every subsystem.
# This is what both `./x11.sh` (every run) and `x11-repair` call.

run_repair_cycle() {
    echo "=================================================="
    echo "              X11 LINUX DESKTOP — REPAIR"
    echo "=================================================="
    echo ""

    run_full_detection

    # --- Termux dependencies ---
    step_check "[1/11] Checking Termux ................."
    if [ "${IS_TERMUX:-0}" = "1" ]; then ok "Running inside Termux."; else die "This script must run inside Termux."; fi

    step_check "[2/11] Checking architecture ..........."
    detect_arch
    if [ "$ARCH_SUPPORTED" = "1" ]; then
        ok "Architecture $ARCH is supported."
    else
        die "Unsupported architecture: $ARCH. Only aarch64/arm64 is supported."
    fi

    step_check "[3/11] Checking dependencies ............"
    if ! install_termux_dependencies; then
        die "Required Termux dependencies could not be installed."
    fi

    step_check "[4/11] Checking Linux environment ......."
    if ! install_linux_rootfs; then
        die "Linux environment could not be installed or repaired."
    fi

    step_check "[5/11] Checking base system .............."
    update_base_system || warn "Base system update skipped or incomplete — continuing."

    step_check "[6/11] Checking XFCE ....................."
    if ! install_xfce; then
        die "XFCE could not be installed."
    fi

    step_check "[7/11] Checking DBus ....................."
    configure_dbus || warn "DBus configuration incomplete — the desktop may misbehave."

    step_check "[8/11] Checking audio ....................."
    configure_audio || true   # never fatal

    step_check "[9/11] Checking X11 ......................."
    ensure_x11_working
    X11_WORKING=$?

    if [ "$X11_WORKING" != "0" ]; then
        echo ""
        warn "X11 is not available. XFCE cannot be shown until this is fixed."
        return 1
    fi

    step_check "[10/11] Starting desktop .................."
    if ! launch_xfce_desktop; then
        error "Desktop failed to start."
        return 1
    fi

    step_check "[11/11] Final verification ................"
    final_verification
}
