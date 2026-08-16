#!/data/data/com.termux/files/usr/bin/bash
# scripts/x11.sh — Termux:X11 server startup + connection verification.
#
# IMPORTANT HONESTY NOTE: there are two different things both called
# "Termux:X11":
#   1. The `termux-x11` binary (from the termux-x11-nightly Termux package)
#      — this runs an X server INSIDE Termux.
#   2. The Termux:X11 Android APPLICATION — a separate app that renders
#      what that X server produces on screen.
# Termux has no supported API to ask Android "is package X installed",
# so this script cannot directly confirm the app is present. The only
# honest way to know is to start the server and test whether a real X11
# client can connect and get a display. If that fails, we say so plainly
# and point the user at installing the Termux:X11 app — we never claim
# X11 is connected without having actually verified it.

X11_SOCK_DIR="$PREFIX/tmp/.X11-unix"
TERMUX_X11_PID_FILE="$CACHE_DIR/termux-x11.pid"

setup_display_env() {
    export DISPLAY="${DISPLAY_NUM:-:0}"
    export XDG_RUNTIME_DIR="/tmp/runtime-$(id -un 2>/dev/null || echo termux)"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null
    mkdir -p "$X11_SOCK_DIR" 2>/dev/null
}

termux_x11_binary_present() {
    have_cmd termux-x11
}

termux_x11_server_running() {
    if [ -f "$TERMUX_X11_PID_FILE" ]; then
        local pid
        pid="$(cat "$TERMUX_X11_PID_FILE" 2>/dev/null)"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    pgrep -f "termux-x11 ${DISPLAY_NUM:-:0}" >/dev/null 2>&1
}

start_termux_x11_server() {
    setup_display_env

    if ! termux_x11_binary_present; then
        not_supported "termux-x11 binary is missing (package termux-x11-nightly not installed)."
        return 2
    fi

    if termux_x11_server_running; then
        ok "Termux:X11 server already running on ${DISPLAY_NUM:-:0}."
        return 0
    fi

    # Clear a stale lock file from a previous crashed/killed server before
    # trying to bind the display again.
    rm -f "$PREFIX/tmp/.X${DISPLAY_NUM#:}-lock" 2>/dev/null

    step_install "Starting Termux:X11 server on ${DISPLAY_NUM:-:0}..."
    nohup termux-x11 "${DISPLAY_NUM:-:0}" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$TERMUX_X11_PID_FILE"
    sleep "${X11_SERVER_STARTUP_WAIT:-5}"

    if kill -0 "$pid" 2>/dev/null; then
        return 0
    fi

    error "termux-x11 exited immediately — the Termux:X11 Android app is likely not installed or could not be reached."
    return 1
}

# Real connection test: tries to actually query the X server, not just
# check that a process exists.
test_x11_connection() {
    setup_display_env
    if have_cmd xdpyinfo; then
        if with_timeout "${X11_CONNECT_TIMEOUT:-8}" xdpyinfo -display "$DISPLAY" >/dev/null 2>>"$LOG_FILE"; then
            return 0
        fi
        return 1
    fi
    if have_cmd xset; then
        if with_timeout "${X11_CONNECT_TIMEOUT:-8}" xset -display "$DISPLAY" q >/dev/null 2>>"$LOG_FILE"; then
            return 0
        fi
        return 1
    fi
    # Neither diagnostic tool is present — we genuinely cannot verify the
    # connection, so we must not report success.
    warn "Neither xdpyinfo nor xset is available to verify the X11 connection."
    return 2
}

print_termux_x11_required_notice() {
    cat <<'EOF'
==================================================
TERMUX:X11 REQUIRED
==================================================

The Termux:X11 Android application is required
to display the Linux desktop.

Install Termux:X11 and run:

    ./x11.sh

again.
==================================================
EOF
}

# Full DETECT -> DIAGNOSE -> REPAIR -> VERIFY flow for X11.
ensure_x11_working() {
    setup_display_env
    step_check "Checking X11 (Termux:X11)..."

    if ! termux_x11_binary_present; then
        not_supported "termux-x11 server binary is not installed."
        print_termux_x11_required_notice
        return 1
    fi

    start_termux_x11_server
    local start_rc=$?
    if [ "$start_rc" = "2" ]; then
        print_termux_x11_required_notice
        return 1
    fi

    if test_x11_connection; then
        ok "X11 connected on $DISPLAY."
        mark_stage_done "09_x11"
        return 0
    fi

    step_repair "X11 connection failed — attempting repair..."
    rm -f "$PREFIX/tmp/.X${DISPLAY_NUM#:}-lock" 2>/dev/null
    if [ -f "$TERMUX_X11_PID_FILE" ]; then
        local pid
        pid="$(cat "$TERMUX_X11_PID_FILE" 2>/dev/null)"
        [ -n "$pid" ] && kill "$pid" 2>/dev/null
        rm -f "$TERMUX_X11_PID_FILE"
    fi
    sleep 1
    start_termux_x11_server >/dev/null

    if test_x11_connection; then
        ok "X11 connected after repair."
        mark_stage_done "09_x11"
        return 0
    fi

    error "X11 connection unavailable after repair attempt."
    print_termux_x11_required_notice
    return 1
}
