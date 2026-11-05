#!/usr/bin/env bash
# Установка tmux-login: скрипт в ~/.local/bin и хук в ~/.bashrc.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SOURCE="$SCRIPT_DIR/bin/tmux-login"

PREFIX=${PREFIX:-$HOME/.local}
case $PREFIX in
    /*) ;;
    *) PREFIX="$PWD/$PREFIX" ;;
esac
BIN_DIR="$PREFIX/bin"
TARGET="$BIN_DIR/tmux-login"
BASHRC=${BASHRC:-$HOME/.bashrc}
INSTALL_HOOK=1

MARK_BEGIN="# >>> tmux-login >>>"
MARK_END="# <<< tmux-login <<<"

usage() {
    cat <<EOF
Установка tmux-login

Использование: ./install.sh [--no-bashrc] [--help]

  --no-bashrc   не трогать ~/.bashrc (только установить скрипт)
  --help        эта справка

Переменные окружения:
  PREFIX   каталог установки      (по умолчанию: \$HOME/.local)
  BASHRC   файл конфигурации bash (по умолчанию: \$HOME/.bashrc)
EOF
}

die() {
    printf 'Ошибка: %s\n' "$*" >&2
    exit 1
}

remove_block() {
    [[ -f $BASHRC ]] || return 0
    grep -qF "$MARK_BEGIN" "$BASHRC" || return 0

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

append_block() {
    [[ -f $BASHRC ]] || : > "$BASHRC"

    # гарантировать перевод строки в конце файла
    if [[ -s $BASHRC ]] && [[ -n $(tail -c 1 "$BASHRC") ]]; then
        printf '\n' >> "$BASHRC"
    fi

    cat >> "$BASHRC" <<EOF
$MARK_BEGIN
# Интерактивный выбор tmux-сессии при входе по SSH.
# Удалить: $SCRIPT_DIR/uninstall.sh  (или make uninstall)
if [[ -x "$TARGET" && -n \${SSH_CONNECTION:-} && -z \${TMUX:-} && -z \${TMUX_PICKER_ACTIVE:-} ]]; then
    export TMUX_PICKER_ACTIVE=1
    "$TARGET"
    if (( \$? == 0 )); then
        exit 0   # отцепились от tmux — закрываем SSH-соединение
    fi
fi
$MARK_END
EOF
}

case ${1:-} in
    "")
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    --no-bashrc)
        INSTALL_HOOK=0
        ;;
    *)
        die "неизвестный аргумент: $1 (см. --help)"
        ;;
esac

[[ -f $SOURCE ]] || die "не найден исходный скрипт: $SOURCE"
[[ -x $SOURCE ]] || chmod +x "$SOURCE"

install -d -m 755 "$BIN_DIR"
install -m 755 "$SOURCE" "$TARGET"
printf 'Установлен: %s\n' "$TARGET"

if (( INSTALL_HOOK )); then
    if [[ -f $BASHRC ]]; then
        cp -p "$BASHRC" "${BASHRC}.bak.tmux-login"
    fi
    remove_block
    append_block
    printf 'Хук добавлен в %s\n' "$BASHRC"
    printf 'Проверка: открой новое SSH-подключение или запусти %s\n' "$TARGET"
else
    printf 'Хук в %s не изменялся (--no-bashrc)\n' "$BASHRC"
fi
