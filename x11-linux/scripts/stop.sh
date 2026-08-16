#!/data/data/com.termux/files/usr/bin/bash
# stop.sh — stop the Linux desktop and the Termux:X11 server without
# ever touching Termux itself. No broad pkill of Termux is ever used.

stop_everything() {
    info "Stopping XFCE desktop session..."
    stop_xfce_desktop

    info "Stopping Termux:X11 server..."
    local stopped=0
    if [ -f "$TERMUX_X11_PID_FILE" ]; then
        local pid
        pid="$(cat "$TERMUX_X11_PID_FILE" 2>/dev/null)"
        if [ -n "$pid" ] && kill "$pid" 2>/dev/null; then
            stopped=1
        fi
        rm -f "$TERMUX_X11_PID_FILE"
    fi
    local pid
    for pid in $(pgrep -f "termux-x11 ${DISPLAY_NUM:-:0}" 2>/dev/null); do
        kill "$pid" 2>/dev/null && stopped=1
    done

    if [ "$stopped" = "1" ]; then
        ok "Termux:X11 server stopped."
    else
        info "Termux:X11 server was not running."
    fi

    ok "Desktop stopped. Termux itself is untouched."
}
