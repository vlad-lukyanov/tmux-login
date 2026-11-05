#!/usr/bin/env bash
# Сборка .deb-пакета без debhelper: staging + dpkg-deb.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PKG=tmux-login
ARCH=all

VERSION=$("$ROOT/bin/tmux-login" --version | awk '{print $2}')
DEB_VERSION=${DEB_VERSION:-${VERSION}-1}
MAINTAINER=${MAINTAINER:-spider <spider@localhost>}
DIST_DIR=${DIST_DIR:-$ROOT/dist}

usage() {
    cat <<EOF
Сборка .deb для tmux-login

Использование: ./packaging/build-deb.sh [--help]

Переменные окружения:
  DEB_VERSION   версия пакета (по умолчанию: <upstream>-1)
  MAINTAINER    строка Maintainer (по умолчанию: $MAINTAINER)
  DIST_DIR      каталог для .deb (по умолчанию: $ROOT/dist)
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

STAGE=$(mktemp -d "${TMPDIR:-/tmp}/tmux-login-deb.XXXXXX")
chmod 755 "$STAGE"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

install -d -m 755 "$STAGE/DEBIAN"
install -d -m 755 "$STAGE/usr/bin"
install -d -m 755 "$STAGE/usr/share/doc/$PKG"
install -d -m 755 "$STAGE/usr/share/man/man1"

# основные файлы
install -m 755 "$ROOT/bin/tmux-login" "$STAGE/usr/bin/tmux-login"
install -m 755 "$ROOT/bin/tmux-login-enable" "$STAGE/usr/bin/tmux-login-enable"

# документация
install -m 644 "$ROOT/README.md" "$STAGE/usr/share/doc/$PKG/README.md"
install -m 644 "$ROOT/LICENSE" "$STAGE/usr/share/doc/$PKG/copyright"

{
    printf '%s (%s) unstable; urgency=medium\n\n' "$PKG" "$DEB_VERSION"
    printf '  * Package built from upstream %s.\n\n' "$VERSION"
    printf ' -- %s  %s\n' "$MAINTAINER" "$(date -R)"
} | gzip -9n > "$STAGE/usr/share/doc/$PKG/changelog.Debian.gz"
chmod 644 "$STAGE/usr/share/doc/$PKG/changelog.Debian.gz"

# man-страницы
gzip -9n -c "$ROOT/man/tmux-login.1" > "$STAGE/usr/share/man/man1/tmux-login.1.gz"
gzip -9n -c "$ROOT/man/tmux-login-enable.1" > "$STAGE/usr/share/man/man1/tmux-login-enable.1.gz"
chmod 644 "$STAGE/usr/share/man/man1/"*.gz

# контрольные суммы файлов пакета
(
    cd "$STAGE"
    find usr -type f -print0 | sort -z | xargs -0 -r md5sum > DEBIAN/md5sums
)
chmod 644 "$STAGE/DEBIAN/md5sums"

cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG
Version: $DEB_VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: bash (>= 4.4), tmux
Recommends: whiptail
Installed-Size: $(du -sk "$STAGE/usr" | cut -f1)
Maintainer: $MAINTAINER
Description: interactive tmux session picker for SSH logins
 Shows a menu of tmux sessions when logging in over SSH. Allows
 attaching to an existing session, creating a new session, renaming
 or deleting sessions, and dropping to a normal shell. Works with
 whiptail or a plain-text fallback.
EOF
chmod 644 "$STAGE/DEBIAN/control"

mkdir -p "$DIST_DIR"
DEB_FILE="$DIST_DIR/${PKG}_${DEB_VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group --build "$STAGE" "$DEB_FILE" >/dev/null

printf 'Собран пакет: %s\n' "$DEB_FILE"
printf 'Размер: %s\n' "$(du -h "$DEB_FILE" | cut -f1)"
printf 'Установка: sudo dpkg -i %s\n' "$DEB_FILE"
printf 'Включить автозапуск: tmux-login-enable\n'
