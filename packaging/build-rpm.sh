#!/usr/bin/env bash
# Сборка .rpm-пакета через rpmbuild (spec-файл + source tarball).
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PKG=tmux-login
ARCH=noarch

VERSION=$("$ROOT/bin/tmux-login" --version | awk '{print $2}')
RPM_RELEASE=${RPM_RELEASE:-1}
MAINTAINER=${MAINTAINER:-spider <spider@localhost>}
DIST_DIR=${DIST_DIR:-$ROOT/dist}

usage() {
    cat <<EOF
Сборка .rpm для tmux-login

Использование: ./packaging/build-rpm.sh [--help]

Требуется rpmbuild (пакет rpm / rpm-build).

Переменные окружения:
  RPM_RELEASE   номер релиза пакета (по умолчанию: 1)
  MAINTAINER    строка Packager/Maintainer (по умолчанию: $MAINTAINER)
  DIST_DIR      каталог для .rpm (по умолчанию: $ROOT/dist)
EOF
}

case ${1:-} in
    "")
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        printf 'Ошибка: неизвестный аргумент: %s\n' "$1" >&2
        exit 1
        ;;
esac

[[ -n $VERSION ]] || {
    printf 'Ошибка: не удалось определить версию\n' >&2
    exit 1
}

if ! command -v rpmbuild >/dev/null 2>&1; then
    printf 'Ошибка: rpmbuild не найден (установи пакет rpm или rpm-build)\n' >&2
    exit 1
fi

TOPDIR=$(mktemp -d "${TMPDIR:-/tmp}/tmux-login-rpm.XXXXXX")
cleanup() { rm -rf "$TOPDIR"; }
trap cleanup EXIT

mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS,src}

# исходный архив для spec-файла
SRCNAME="$PKG-$VERSION"
mkdir -p "$TOPDIR/src/$SRCNAME"
cp -a "$ROOT/bin" "$ROOT/man" "$ROOT/README.md" "$ROOT/LICENSE" "$TOPDIR/src/$SRCNAME/"
tar -C "$TOPDIR/src" --owner=0 --group=0 --numeric-owner \
    -czf "$TOPDIR/SOURCES/$SRCNAME.tar.gz" "$SRCNAME"

# spec из шаблона
sed -e "s/@VERSION@/$VERSION/g" \
    -e "s/@RELEASE@/$RPM_RELEASE/g" \
    -e "s|@MAINTAINER@|$MAINTAINER|g" \
    -e "s|@DATE@|$(LC_ALL=C date '+%a %b %d %Y')|g" \
    "$ROOT/packaging/tmux-login.spec.in" > "$TOPDIR/SPECS/$PKG.spec"

rpmbuild \
    --define "_topdir $TOPDIR" \
    --define "packager $MAINTAINER" \
    --define "_build_id_links none" \
    -bb "$TOPDIR/SPECS/$PKG.spec"

RPM_FILE=$(find "$TOPDIR/RPMS" -type f -name '*.rpm' -print -quit)
[[ -n $RPM_FILE ]] || {
    printf 'Ошибка: rpmbuild не создал пакет\n' >&2
    exit 1
}

mkdir -p "$DIST_DIR"
cp "$RPM_FILE" "$DIST_DIR/"
RPM_FILE="$DIST_DIR/$(basename "$RPM_FILE")"

printf 'Собран пакет: %s\n' "$RPM_FILE"
printf 'Размер: %s\n' "$(du -h "$RPM_FILE" | cut -f1)"
printf 'Установка: sudo dnf install %s\n' "$RPM_FILE"
printf '        или: sudo rpm -i %s\n' "$RPM_FILE"
printf 'Включить автозапуск: tmux-login-enable\n'
