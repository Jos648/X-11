#!/data/data/com.termux/files/usr/bin/bash
# common.sh — shared logging, checkpoint state, and utility functions.
# This file is meant to be SOURCED, not executed directly.

if [ -z "${X11_LINUX_ROOT:-}" ]; then
    echo "common.sh must be sourced with X11_LINUX_ROOT already set." >&2
    return 1 2>/dev/null || exit 1
fi

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
INSTALLER_HOME="$HOME/.x11-installer"
STATE_DIR="$INSTALLER_HOME/state"
LOG_DIR="$INSTALLER_HOME/logs"
CACHE_DIR="$INSTALLER_HOME/cache"
BACKUP_DIR="$INSTALLER_HOME/backup"
LOG_FILE="$LOG_DIR/x11.log"
CONFIG_FILE="$X11_LINUX_ROOT/config/x11.conf"
LOCATION_FILE="$INSTALLER_HOME/install_location"

mkdir -p "$STATE_DIR" "$LOG_DIR" "$CACHE_DIR" "$BACKUP_DIR" 2>/dev/null
touch "$LOG_FILE" 2>/dev/null

# Record where this project lives so the installed x11-start / x11-stop /
# etc. wrapper commands can find it later, even from a different cwd.
echo "$X11_LINUX_ROOT" > "$LOCATION_FILE" 2>/dev/null

# ---------------------------------------------------------------------------
# Colors (disabled automatically when not attached to a terminal)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
    C_RED=$'\033[0;31m'; C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[0;33m'
    C_BLUE=$'\033[0;34m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_BOLD=""; C_RESET=""
fi

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
_ts() { date '+%Y-%m-%d %H:%M:%S'; }

log_line() {
    local level="$1"; shift
    printf '[%s] [%s] %s\n' "$(_ts)" "$level" "$*" >> "$LOG_FILE" 2>/dev/null
}

info()  { echo "${C_BLUE}[INFO]${C_RESET} $*";  log_line "INFO"  "$*"; }
ok()    { echo "${C_GREEN}[OK]${C_RESET} $*";   log_line "OK"    "$*"; }
warn()  { echo "${C_YELLOW}[WARN]${C_RESET} $*"; log_line "WARN"  "$*"; }
error() { echo "${C_RED}[ERROR]${C_RESET} $*" >&2; log_line "ERROR" "$*"; }
step_check()   { echo "${C_BLUE}[CHECK]${C_RESET} $*";     log_line "CHECK"   "$*"; }
step_install() { echo "${C_BLUE}[INSTALL]${C_RESET} $*";   log_line "INSTALL" "$*"; }
step_repair()  { echo "${C_YELLOW}[REPAIR]${C_RESET} $*";  log_line "REPAIR"  "$*"; }
not_supported(){ echo "${C_RED}[NOT SUPPORTED]${C_RESET} $*"; log_line "NOT_SUPPORTED" "$*"; }
degraded()     { echo "${C_YELLOW}[DEGRADED]${C_RESET} $*"; log_line "DEGRADED" "$*"; }

# die: for CRITICAL errors only (rootfs unavailable, XFCE cannot install,
# X11 cannot connect at all). Never call this for optional/non-critical
# failures — those should warn() and continue.
die() {
    error "$*"
    log_line "CRITICAL" "$*"
    echo ""
    echo "${C_RED}${C_BOLD}A critical error stopped the process.${C_RESET}"
    echo "Full log: $LOG_FILE"
    exit 1
}

# ---------------------------------------------------------------------------
# Checkpoint / stage state system
#   Stages: 01_termux 02_architecture 03_dependencies 04_linux
#           05_base_system 06_xfce 07_dbus 08_audio 09_x11
#           10_desktop 11_verification
# ---------------------------------------------------------------------------
mark_stage_done() {
    date '+%Y-%m-%d %H:%M:%S' > "$STATE_DIR/${1}.done" 2>/dev/null
    log_line "STATE" "stage $1 complete"
}

stage_done() { [ -f "$STATE_DIR/${1}.done" ]; }

clear_stage() { rm -f "$STATE_DIR/${1}.done" 2>/dev/null; }

reset_all_stages() {
    rm -f "$STATE_DIR"/*.done 2>/dev/null
    log_line "STATE" "all stage checkpoints cleared"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
have_cmd() { command -v "$1" >/dev/null 2>&1; }

# run_logged "description" cmd arg1 arg2 ...
# Runs a command, sends all output to the log file, returns the command's
# exit code. Never aborts the script on failure — caller decides severity.
run_logged() {
    local desc="$1"; shift
    log_line "RUN" "$desc :: $*"
    if "$@" >> "$LOG_FILE" 2>&1; then
        return 0
    else
        local rc=$?
        log_line "ERROR" "$desc failed (exit $rc)"
        return "$rc"
    fi
}

# with_timeout SECONDS cmd args...
with_timeout() {
    local secs="$1"; shift
    if have_cmd timeout; then
        timeout "$secs" "$@"
    else
        "$@"
    fi
}

pkg_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    else
        die "Missing configuration file: $CONFIG_FILE"
    fi
}
load_config
