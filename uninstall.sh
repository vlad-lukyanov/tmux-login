#!/usr/bin/env bash
# Удаление tmux-login: хук из ~/.bashrc и скрипт из ~/.local/bin.
set -euo pipefail

PREFIX=${PREFIX:-$HOME/.local}
case $PREFIX in
    /*) ;;
    *) PREFIX="$PWD/$PREFIX" ;;
esac
TARGET="$PREFIX/bin/tmux-login"
BASHRC=${BASHRC:-$HOME/.bashrc}

MARK_BEGIN="# >>> tmux-login >>>"
MARK_END="# <<< tmux-login <<<"

usage() {
    cat <<EOF
Удаление tmux-login

Использование: ./uninstall.sh [--help]

Переменные окружения:
  PREFIX   каталог установки      (по умолчанию: \$HOME/.local)
  BASHRC   файл конфигурации bash (по умолчанию: \$HOME/.bashrc)
EOF
}

remove_block() {
    local tmp
    tmp=$(mktemp "${BASHRC}.tmp.XXXXXX")
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
        $0 == b { skip = 1; next }
        $0 == e { skip = 0; next }
        !skip   { print }
    ' "$BASHRC" > "$tmp"
    cat "$tmp" > "$BASHRC"
    rm -f "$tmp"
}

case ${1:-} in
    "")
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        printf 'Ошибка: неизвестный аргумент: %s (см. --help)\n' "$1" >&2
        exit 1
        ;;
esac

if [[ -f $BASHRC ]] && grep -qF "$MARK_BEGIN" "$BASHRC"; then
    cp -p "$BASHRC" "${BASHRC}.bak.tmux-login"
    remove_block
    printf 'Хук удалён из %s\n' "$BASHRC"
else
    printf 'Хук в %s не найден — пропуск\n' "$BASHRC"
fi

if [[ -e $TARGET ]]; then
    rm -f "$TARGET"
    printf 'Удалён %s\n' "$TARGET"
else
    printf '%s не найден — пропуск\n' "$TARGET"
fi
