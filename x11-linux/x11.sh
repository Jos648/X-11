#!/data/data/com.termux/files/usr/bin/bash
# x11.sh — single entry point for the self-healing Termux + proot-distro +
# XFCE + Termux:X11 Linux desktop system.
#
# Usage:
#   ./x11.sh                 Full detect/install/repair/verify/launch flow
#   ./x11.sh --start          Alias for the full flow (used by x11-start)
#   ./x11.sh --stop            Stop the desktop (used by x11-stop)
#   ./x11.sh --restart         Restart the desktop (used by x11-restart)
#   ./x11.sh --status          Print status only, no changes (used by x11-status)
#   ./x11.sh --repair          Force a repair cycle (used by x11-repair)
#   ./x11.sh --uninstall       Remove the Linux desktop (used by x11-uninstall)
#   ./x11.sh --help            Show this help
#
# This script does NOT use `set -e`. Failures are handled explicitly and
# classified as CRITICAL, NON-CRITICAL, or WARNING — see scripts/common.sh.

set -uo pipefail

# Resolve the real directory this script lives in, even if invoked via a
# symlink or from another working directory.
resolve_root() {
    local src="${BASH_SOURCE[0]}"
    while [ -h "$src" ]; do
        local dir
        dir="$(cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd)"
        src="$(readlink "$src")"
        [[ "$src" != /* ]] && src="$dir/$src"
    done
    cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd
}

X11_LINUX_ROOT="$(resolve_root)"
export X11_LINUX_ROOT

# shellcheck source=scripts/common.sh
source "$X11_LINUX_ROOT/scripts/common.sh"
# shellcheck source=scripts/detect.sh
source "$X11_LINUX_ROOT/scripts/detect.sh"
# shellcheck source=scripts/dependencies.sh
source "$X11_LINUX_ROOT/scripts/dependencies.sh"
# shellcheck source=scripts/linux.sh
source "$X11_LINUX_ROOT/scripts/linux.sh"
# shellcheck source=scripts/xfce.sh
source "$X11_LINUX_ROOT/scripts/xfce.sh"
# shellcheck source=scripts/dbus.sh
source "$X11_LINUX_ROOT/scripts/dbus.sh"
# shellcheck source=scripts/audio.sh
source "$X11_LINUX_ROOT/scripts/audio.sh"
# shellcheck source=scripts/x11.sh
source "$X11_LINUX_ROOT/scripts/x11.sh"
# shellcheck source=scripts/desktop.sh
source "$X11_LINUX_ROOT/scripts/desktop.sh"
# shellcheck source=scripts/repair.sh
source "$X11_LINUX_ROOT/scripts/repair.sh"
# shellcheck source=scripts/status.sh
source "$X11_LINUX_ROOT/scripts/status.sh"
# shellcheck source=scripts/stop.sh
source "$X11_LINUX_ROOT/scripts/stop.sh"
# shellcheck source=scripts/uninstall.sh
source "$X11_LINUX_ROOT/scripts/uninstall.sh"

print_banner() {
    run_full_detection
    echo "=================================================="
    echo "              X11 LINUX DESKTOP"
    echo "=================================================="
    echo ""
    echo "Environment : $([ "${IS_TERMUX:-0}" = "1" ] && echo Termux || echo unknown)"
    echo "Android     : $([ "${IS_ANDROID:-0}" = "1" ] && echo detected || echo unknown)"
    echo "Architecture: ${ARCH:-unknown}"
    echo "Display     : ${DISPLAY_NUM:-:0}"
    echo "Desktop     : XFCE"
    echo "Mode        : Automatic"
    echo "=================================================="
    echo ""
}

# Installs the x11-start / x11-stop / ... wrapper commands into
# $PREFIX/bin so they're usable from anywhere, not just this directory.
install_wrapper_commands() {
    local bin_dir="$PREFIX/bin"
    [ -d "$bin_dir" ] || return 0

    local cmd flag
    while IFS=: read -r cmd flag; do
        cat > "$bin_dir/$cmd" <<EOF
#!$PREFIX/bin/bash
exec "$X11_LINUX_ROOT/x11.sh" $flag "\$@"
EOF
        chmod +x "$bin_dir/$cmd"
    done <<'MAP'
x11-start:--start
x11-stop:--stop
x11-restart:--restart
x11-status:--status
x11-repair:--repair
x11-uninstall:--uninstall
MAP
}

print_help() {
    cat <<'EOF'
x11.sh — self-healing Termux + proot-distro + XFCE + Termux:X11 desktop

  ./x11.sh              Full detect / install / repair / verify / launch
  ./x11.sh --start      Same as above (also available as: x11-start)
  ./x11.sh --stop       Stop the desktop, keep Termux running (x11-stop)
  ./x11.sh --restart    Restart the desktop session (x11-restart)
  ./x11.sh --status     Show status only, changes nothing (x11-status)
  ./x11.sh --repair     Force a full repair cycle (x11-repair)
  ./x11.sh --uninstall  Remove the Linux desktop, asks to confirm (x11-uninstall)
  ./x11.sh --help       Show this help
EOF
}

main() {
    local action="${1:---start}"

    case "$action" in
        --help|-h)
            print_help
            exit 0
            ;;
        --status)
            print_status
            exit $?
            ;;
        --stop)
            stop_everything
            exit $?
            ;;
        --restart)
            print_banner
            restart_xfce_desktop
            final_verification
            exit $?
            ;;
        --repair)
            reset_all_stages
            print_banner
            run_repair_cycle
            local rc=$?
            install_wrapper_commands
            exit $rc
            ;;
        --uninstall)
            run_uninstall
            exit $?
            ;;
        --start|"")
            print_banner
            run_repair_cycle
            local rc=$?
            install_wrapper_commands
            if [ "$rc" = "0" ]; then
                echo ""
                ok "You are now inside the graphical Linux desktop (check the Termux:X11 app)."
                echo "Manage it any time with: x11-status | x11-stop | x11-restart | x11-repair"
            else
                echo ""
                error "Setup did not complete successfully. See the messages above and $LOG_FILE."
                echo "Fix the reported issue, then run ./x11.sh again — completed steps will be skipped."
            fi
            exit $rc
            ;;
        *)
            error "Unknown option: $action"
            print_help
            exit 2
            ;;
    esac
}

main "$@"
