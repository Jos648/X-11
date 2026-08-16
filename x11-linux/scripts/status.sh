#!/data/data/com.termux/files/usr/bin/bash
# status.sh — report current state of every subsystem without changing
# anything (read-only, safe to run anytime).

print_status() {
    run_full_detection
    check_xfce_installed
    dbus_session_active
    setup_display_env
    test_x11_connection; local x11_ok=$?

    echo "=================================================="
    echo "              X11 LINUX DESKTOP — STATUS"
    echo "=================================================="
    echo ""
    echo "Termux              : $([ "$IS_TERMUX" = "1" ] && echo OK || echo "NOT DETECTED")"
    echo "Android             : $([ "$IS_ANDROID" = "1" ] && echo detected || echo "NOT DETECTED")"
    echo "Architecture        : $ARCH $([ "$ARCH_SUPPORTED" = "1" ] && echo "(supported)" || echo "(UNSUPPORTED)")"
    echo "RAM                 : ${RAM_TOTAL_MB} MB $([ "$RAM_TOTAL_MB" -lt "${LOW_RAM_MB:-2048}" ] 2>/dev/null && echo "(low)")"
    echo "Free storage        : ${STORAGE_FREE_MB} MB"
    echo "Network             : $([ "$NETWORK_OK" = "1" ] && echo online || echo offline)"
    echo ""
    echo "proot-distro        : $([ "$PROOT_DISTRO_AVAILABLE" = "1" ] && echo installed || echo "NOT INSTALLED")"
    echo "Linux rootfs        : $([ "$LINUX_INSTALLED" = "1" ] && echo "$DISTRO_DISPLAY_NAME (installed)" || echo "NOT INSTALLED")"
    echo "XFCE                : $([ "$XFCE_INSTALLED" = "1" ] && echo installed || echo "NOT INSTALLED")"
    echo "XFCE session        : $([ "$XFCE_RUNNING" = "1" ] && echo running || echo "not running")"
    echo "DBus session        : $([ "$DBUS_SESSION_SET" = "1" ] && echo active || echo "not active")"
    echo "PulseAudio          : $([ "$PULSEAUDIO_RUNNING" = "1" ] && echo running || echo "not running")"
    echo "Storage access      : $([ "$STORAGE_ACCESS" = "1" ] && echo granted || echo "not granted")"
    echo "termux-x11 binary   : $([ "$TERMUX_X11_BINARY" = "1" ] && echo present || echo "NOT INSTALLED")"
    echo "DISPLAY             : ${DISPLAY:-unset}"
    echo "X11 connection      : $([ "$x11_ok" = "0" ] && echo CONNECTED || echo "NOT CONNECTED")"
    echo ""
    echo "Checkpoints reached:"
    local stage
    for stage in 01_termux 02_architecture 03_dependencies 04_linux \
                 05_base_system 06_xfce 07_dbus 08_audio 09_x11 \
                 10_desktop 11_verification; do
        if stage_done "$stage"; then
            echo "  [x] $stage"
        else
            echo "  [ ] $stage"
        fi
    done
    echo ""
    echo "=================================================="
}
