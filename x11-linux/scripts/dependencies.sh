#!/data/data/com.termux/files/usr/bin/bash
# dependencies.sh — install/verify Termux-side (host) packages.

# Packages considered essential to even attempt the rest of the install.
# If these fail to install, we treat it as critical.
CRITICAL_TERMUX_PKGS="proot-distro"

check_termux_dependencies() {
    # Returns 0 if everything in TERMUX_PACKAGES is installed, 1 otherwise.
    local missing=""
    local pkg
    for pkg in $TERMUX_PACKAGES; do
        if ! pkg_installed "$pkg"; then
            missing="$missing $pkg"
        fi
    done
    MISSING_TERMUX_PKGS="$(echo "$missing" | sed 's/^ *//')"
    [ -z "$MISSING_TERMUX_PKGS" ]
}

install_termux_dependencies() {
    check_termux_dependencies
    if [ -z "$MISSING_TERMUX_PKGS" ]; then
        ok "Termux dependencies already installed."
        mark_stage_done "03_dependencies"
        return 0
    fi

    step_install "Missing Termux packages:$MISSING_TERMUX_PKGS"

    if [ "${NETWORK_OK:-0}" != "1" ]; then
        error "Cannot install Termux packages without internet access."
        return 1
    fi

    step_install "Updating package index (pkg update)..."
    if ! run_logged "pkg update" pkg update -y; then
        warn "pkg update reported problems; continuing with existing index."
    fi

    # x11-repo must be added before termux-x11-nightly can be installed.
    if echo "$MISSING_TERMUX_PKGS" | grep -q "x11-repo"; then
        step_install "Installing x11-repo (required for Termux:X11 packages)..."
        if run_logged "install x11-repo" pkg install -y x11-repo; then
            run_logged "pkg update after x11-repo" pkg update -y
        else
            warn "Could not install x11-repo. Termux:X11 server package may be unavailable."
        fi
    fi

    local pkg failed=""
    for pkg in $MISSING_TERMUX_PKGS; do
        [ "$pkg" = "x11-repo" ] && continue
        if pkg_installed "$pkg"; then
            continue
        fi
        step_install "Installing $pkg..."
        if run_logged "install $pkg" pkg install -y "$pkg"; then
            ok "$pkg installed."
        else
            failed="$failed $pkg"
        fi
    done

    if [ -n "$failed" ]; then
        local pkg critical_failed=""
        for pkg in $failed; do
            case " $CRITICAL_TERMUX_PKGS " in
                *" $pkg "*) critical_failed="$critical_failed $pkg" ;;
            esac
        done
        if [ -n "$critical_failed" ]; then
            error "Critical Termux package(s) failed to install:$critical_failed"
            return 1
        else
            warn "Non-critical Termux package(s) failed to install:$failed"
            warn "Continuing — related features will be degraded or unavailable."
        fi
    fi

    check_termux_dependencies
    if [ -z "$MISSING_TERMUX_PKGS" ]; then
        ok "All Termux dependencies installed."
    else
        warn "Some optional dependencies are still missing:$MISSING_TERMUX_PKGS"
    fi
    mark_stage_done "03_dependencies"
    return 0
}
