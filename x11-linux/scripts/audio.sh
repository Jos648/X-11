#!/data/data/com.termux/files/usr/bin/bash
# audio.sh — PulseAudio bridging. Audio is explicitly NON-CRITICAL:
# failure here must never block the graphical desktop from starting.

AUDIO_STATUS="WARN"   # becomes READY on success

configure_audio() {
    if ! have_cmd pulseaudio; then
        warn "Audio unavailable"
        info "Continuing with graphical desktop..."
        AUDIO_STATUS="WARN"
        return 1
    fi

    if ! pgrep -x "pulseaudio" >/dev/null 2>&1; then
        step_install "Starting Termux PulseAudio server..."
        run_logged "start pulseaudio" pulseaudio --start \
            --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
            --exit-idle-time=-1
        sleep 1
    fi

    if pgrep -x "pulseaudio" >/dev/null 2>&1; then
        ok "PulseAudio running."
        AUDIO_STATUS="READY"
        mark_stage_done "08_audio"
        return 0
    fi

    warn "Audio unavailable"
    info "Continuing with graphical desktop..."
    AUDIO_STATUS="WARN"
    return 1
}

# Environment to export inside the proot session so Linux-side apps can
# reach the Termux-side PulseAudio server over TCP loopback.
audio_env_exports() {
    echo "export PULSE_SERVER=127.0.0.1"
}
