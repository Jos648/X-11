#!/data/data/com.termux/files/usr/bin/bash
# desktop.sh — start / stop / verify the actual XFCE desktop session.

XFCE_LOG="$LOG_DIR/xfce-session.log"
XFCE_PID_FILE="$CACHE_DIR/xfce-session.pid"

launch_xfce_desktop() {
    detect_xfce_session_running
    if [ "$XFCE_RUNNING" = "1" ]; then
        ok "XFCE session already running."
        return 0
    fi

    detect_linux_installed
    if [ "$LINUX_INSTALLED" != "1" ]; then
        error "Cannot start XFCE: Linux environment is not installed."
        return 1
    fi

    if ! check_xfce_installed; then
        error "Cannot start XFCE: XFCE is not installed."
        return 1
    fi

    setup_display_env

    local gpu_line="LIBGL_ALWAYS_SOFTWARE=1"
    step_install "Starting XFCE desktop session (this can take a minute on first launch)..."

    local audio_exports=""
    if [ "${AUDIO_STATUS:-WARN}" = "READY" ]; then
        audio_exports="$(audio_env_exports)"
    fi

    local session_cmd
    session_cmd="export DISPLAY=${DISPLAY_NUM:-:0}; export $gpu_line; $audio_exports; dbus-launch --exit-with-session startxfce4"

    nohup proot-distro login "$DISTRO_ALIAS" \
        --bind "$X11_SOCK_DIR:/tmp/.X11-unix" \
        -- bash -lc "$session_cmd" >> "$XFCE_LOG" 2>&1 &
    local pid=$!
    echo "$pid" > "$XFCE_PID_FILE"

    local waited=0
    while [ "$waited" -lt 20 ]; do
        detect_xfce_session_running
        if [ "$XFCE_RUNNING" = "1" ]; then
            ok "XFCE desktop session is running."
            mark_stage_done "10_desktop"
            return 0
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi
        sleep 1
        waited=$((waited + 1))
    done

    error "XFCE session did not come up. Check $XFCE_LOG for details."
    return 1
}

stop_xfce_desktop() {
    # Safe, targeted process management — only touches processes that
    # actually belong to the XFCE session, never a broad kill.
    local killed=0
    local pid
    for pid in $(pgrep -f "xfce4-session" 2>/dev/null); do
        kill "$pid" 2>/dev/null && killed=1
    done
    for pid in $(pgrep -f "^startxfce4" 2>/dev/null); do
        kill "$pid" 2>/dev/null && killed=1
    done
    if [ -f "$XFCE_PID_FILE" ]; then
        pid="$(cat "$XFCE_PID_FILE" 2>/dev/null)"
        [ -n "$pid" ] && kill "$pid" 2>/dev/null
        rm -f "$XFCE_PID_FILE"
    fi

    if [ "$killed" = "1" ]; then
        ok "XFCE desktop session stopped."
    else
        info "No running XFCE session found."
    fi
}

restart_xfce_desktop() {
    stop_xfce_desktop
    sleep 1
    launch_xfce_desktop
}

final_verification() {
    step_check "Running final verification..."

    detect_linux_installed
    check_xfce_installed
    dbus_session_active
    detect_display_var
    test_x11_connection; local x11_ok=$?
    detect_pulseaudio
    detect_storage_access
    detect_xfce_session_running

    local x11_state="UNAVAILABLE"
    [ "$x11_ok" = "0" ] && x11_state="CONNECTED"

    local audio_state="WARN"
    [ "$PULSEAUDIO_RUNNING" = "1" ] && audio_state="READY"

    local storage_state="WARN"
    [ "$STORAGE_ACCESS" = "1" ] && storage_state="AVAILABLE"

    local desktop_state="NOT RUNNING"
    [ "$XFCE_RUNNING" = "1" ] && desktop_state="RUNNING"

    echo "=================================================="
    echo "              DESKTOP READY"
    echo "=================================================="
    echo ""
    echo "Linux       : $DISTRO_DISPLAY_NAME"
    echo "Desktop     : XFCE"
    echo "Display     : ${DISPLAY_NUM:-:0}"
    echo "X11         : $x11_state"
    echo "DBus        : $([ "$DBUS_SESSION_SET" = "1" ] && echo READY || echo UNAVAILABLE)"
    echo "Audio       : $audio_state"
    echo "Storage     : $storage_state"
    echo "Desktop     : $desktop_state"
    echo ""
    echo "=================================================="

    if [ "$x11_ok" = "0" ] && [ "$XFCE_RUNNING" = "1" ]; then
        mark_stage_done "11_verification"
        return 0
    fi
    return 1
}
