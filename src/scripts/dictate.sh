#!/usr/bin/env bash
# ghost dictate [journal|cancel]  — start/stop voice dictation
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
case "$1" in
    cancel)  quickshell -p "$MAIN_QML" ipc call dictation cancel ;;
    journal) quickshell -p "$MAIN_QML" ipc call dictation toggle journal ;;
    *)       quickshell -p "$MAIN_QML" ipc call dictation toggle type ;;
esac
