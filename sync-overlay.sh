#!/usr/bin/env bash
# Синхронизация файлов Gentoo-overlay (корень репозитория)
# и пересборка Manifest.
#
# Использование:
#   ./sync-overlay.sh           # обновить files/ и Manifest
#   ./sync-overlay.sh --check   # только проверить синхронизацию
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PKG="$ROOT/app-admin/tmux-login"
FILES="$PKG/files"

# src в репозитории → dst внутри files/
SOURCES=(
    "bin/tmux-login:tmux-login"
    "bin/tmux-login-enable:tmux-login-enable"
    "man/tmux-login.1:tmux-login.1"
    "man/tmux-login-enable.1:tmux-login-enable.1"
    "README.md:README.md"
    "LICENSE:LICENSE"
)

find_ebuild() {
    find "$PKG" -maxdepth 1 -type f -name '*.ebuild' -print -quit
}

manifest_entry() {
    local type=$1 file=$2
    local name size sha256 sha512
    name=$(basename "$file")
    size=$(stat -c %s "$file")
    sha256=$(sha256sum "$file" | cut -d' ' -f1)
    sha512=$(sha512sum "$file" | cut -d' ' -f1)
    printf '%s %s %s SHA256 %s SHA512 %s\n' \
        "$type" "$name" "$size" "$sha256" "$sha512"
}

generate_manifest() {
    local ebuild=$1
    manifest_entry EBUILD "$ebuild"
    local item name
    for item in "$FILES"/*; do
        manifest_entry AUX "$item"
    done
}

case ${1:-} in
    "")
        mode=sync
        ;;
    --check)
        mode=check
        ;;
    -h|--help)
        printf 'Использование: %s [--check]\n' "${0##*/}"
        exit 0
        ;;
    *)
        printf 'Ошибка: неизвестный аргумент: %s\n' "$1" >&2
        exit 1
        ;;
esac

ebuild=$(find_ebuild)
[[ -n $ebuild ]] || {
    printf 'Ошибка: ebuild не найден в %s\n' "$PKG" >&2
    exit 1
}

mkdir -p "$FILES"

rc=0
for entry in "${SOURCES[@]}"; do
    src=${entry%%:*}
    dst=${entry#*:}
    if ! cmp -s "$ROOT/$src" "$FILES/$dst"; then
        if [[ $mode == check ]]; then
            rc=1
            printf 'out of sync: %s\n' "$FILES/$dst"
        else
            cp -p "$ROOT/$src" "$FILES/$dst"
            printf 'обновлён: %s\n' "$FILES/$dst"
        fi
    fi
done

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
LC_ALL=C generate_manifest "$ebuild" > "$tmp"

if ! cmp -s "$tmp" "$PKG/Manifest"; then
    if [[ $mode == check ]]; then
        rc=1
        printf 'out of sync: %s\n' "$PKG/Manifest"
    else
        cp "$tmp" "$PKG/Manifest"
        printf 'обновлён: %s\n' "$PKG/Manifest"
    fi
fi

if [[ $mode == check ]]; then
    if (( rc == 0 )); then
        printf 'overlay: всё синхронизировано\n'
    else
        printf 'overlay: есть расхождения (запусти %s без --check)\n' "${0##*/}" >&2
    fi
else
    printf 'overlay: готово\n'
fi

exit "$rc"
