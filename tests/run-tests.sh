#!/usr/bin/env bash
# Автотесты tmux-login.
# Используют отдельный tmux-сервер (-L), реальные сессии не затрагиваются.
set -uo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/bin/tmux-login"

PASS=0
FAIL=0

ok()  { PASS=$((PASS + 1)); printf 'ok   %s\n' "$*"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$*"; }

assert_eq() {
    local desc=$1 want=$2 got=$3
    if [[ $got == "$want" ]]; then
        ok "$desc"
    else
        bad "$desc (ожидали [$want], получили [$got])"
    fi
}

assert_contains() {
    local desc=$1 needle=$2 haystack=$3
    if [[ $haystack == *"$needle"* ]]; then
        ok "$desc"
    else
        bad "$desc (нет [$needle])"
    fi
}

REAL_TMUX=$(command -v tmux || true)
if [[ -z $REAL_TMUX ]]; then
    printf 'tmux не установлен — тесты невозможны\n' >&2
    exit 1
fi

TDIR=$(mktemp -d "${TMPDIR:-/tmp}/tmux-login-test.XXXXXX")
SOCKET="tmux-login-test-$$"
export PATH="$TDIR/bin:$PATH"
mkdir -p "$TDIR/bin"

# shim: все вызовы tmux из тестируемого скрипта идут на изолированный сервер
cat > "$TDIR/bin/tmux" <<EOF
#!/usr/bin/env bash
exec "$REAL_TMUX" -L "$SOCKET" "\$@"
EOF
chmod +x "$TDIR/bin/tmux"

cleanup() {
    "$REAL_TMUX" -L "$SOCKET" kill-server 2>/dev/null || true
    rm -rf "$TDIR"
}
trap cleanup EXIT

tmux_test() { "$REAL_TMUX" -L "$SOCKET" "$@"; }

# ── синтаксис ────────────────────────────────────────────────────────────────
for f in "$SCRIPT" "$ROOT/install.sh" "$ROOT/uninstall.sh" "${BASH_SOURCE[0]}"; do
    if bash -n "$f" 2>/dev/null; then
        ok "синтаксис: ${f##*/}"
    else
        bad "синтаксис: ${f##*/}"
    fi
done

# ── CLI ──────────────────────────────────────────────────────────────────────
out=$("$SCRIPT" --version 2>&1)
assert_contains "--version" "1.0.0" "$out"

out=$("$SCRIPT" --help 2>&1)
assert_contains "--help" "Использование" "$out"

"$SCRIPT" --bogus >/dev/null 2>&1
assert_eq "неизвестный аргумент → код 2" 2 $?

out=$("$SCRIPT" --list 2>&1)
assert_eq "--list без сессий" "нет сессий" "$out"

tmux_test new-session -d -s t1 'sleep 300'
out=$("$SCRIPT" --list 2>&1)
assert_contains "--list показывает t1" "t1" "$out"

env -u TMUX "$SCRIPT" </dev/null >/dev/null 2>&1
assert_eq "без tty → код 10" 10 $?

# ── установка/удаление в песочнице ───────────────────────────────────────────
THOME="$TDIR/home"
mkdir -p "$THOME"
printf '# test bashrc\n' > "$THOME/.bashrc"

BASHRC="$THOME/.bashrc" PREFIX="$THOME/.local" "$ROOT/install.sh" >/dev/null 2>&1
assert_eq "install.sh rc" 0 $?
[[ -x "$THOME/.local/bin/tmux-login" ]] && ok "install: скрипт установлен" || bad "install: скрипт установлен"
grep -qF '# >>> tmux-login >>>' "$THOME/.bashrc" && ok "install: хук добавлен" || bad "install: хук добавлен"

BASHRC="$THOME/.bashrc" PREFIX="$THOME/.local" "$ROOT/install.sh" >/dev/null 2>&1
count=$(grep -cF '# >>> tmux-login >>>' "$THOME/.bashrc")
assert_eq "install идемпотентен" 1 "$count"

if bash -n "$THOME/.bashrc" 2>/dev/null; then
    ok "install: сгенерированный .bashrc валиден"
else
    bad "install: сгенерированный .bashrc валиден"
fi

BASHRC="$THOME/.bashrc" PREFIX="$THOME/.local" "$ROOT/uninstall.sh" >/dev/null 2>&1
grep -qF '# >>> tmux-login >>>' "$THOME/.bashrc" && bad "uninstall: хук удалён" || ok "uninstall: хук удалён"
[[ -e "$THOME/.local/bin/tmux-login" ]] && bad "uninstall: скрипт удалён" || ok "uninstall: скрипт удалён"

# ── интерактивные сценарии (pty, изолированный сервер) ───────────────────────
# Принудительно маленький терминал → детерминированное текстовое меню.
pty() { # $1 — таймаут; вход подаётся снаружи через pipe
    local timeout_s=$1
    shift
    timeout "$timeout_s" script -qec "stty rows 10 cols 50; exec env -u TMUX '$SCRIPT'" /dev/null
}

# attach + detach: меню 1=t1, 2=new, 3=rename, 4=kill, 5=shell
( sleep 1; printf '1\n'; sleep 2; printf '\002d'; sleep 1 ) \
    | pty 30 >"$TDIR/attach.out" 2>&1
assert_eq "pty attach: rc" 0 $?
if tmux_test has-session -t '=t1' 2>/dev/null; then
    ok "pty attach: сессия жива"
else
    bad "pty attach: сессия жива"
fi

# create t2: 2=new → ввод имени → attach → detach
( sleep 1; printf '2\n'; sleep 1; printf 't2\n'; sleep 2; printf '\002d'; sleep 1 ) \
    | pty 40 >"$TDIR/create.out" 2>&1
assert_eq "pty create: rc" 0 $?
if tmux_test has-session -t '=t2' 2>/dev/null; then
    ok "pty create: сессия создана"
else
    bad "pty create: сессия создана"
fi

# выход в shell: whiptail (стрелки) или текстовое меню (номер 6)
if command -v whiptail >/dev/null 2>&1; then
    keys='\033[B\033[B\033[B\033[B\033[B\r'
else
    keys='6\n'
fi
( sleep 1; printf '%b' "$keys"; sleep 1 ) \
    | timeout 30 script -qec "exec env -u TMUX '$SCRIPT'" /dev/null >"$TDIR/shell.out" 2>&1
assert_eq "shell/whiptail: выход в shell → код 10" 10 $?

# rename t1 → t1r: 4=rename, 1=t1, новое имя, 6=shell
( sleep 1; printf '%b' '4\n1\nt1r\n6\n'; sleep 1 ) \
    | pty 40 >"$TDIR/rename.out" 2>&1
assert_eq "pty rename: rc" 10 $?
if tmux_test has-session -t '=t1r' 2>/dev/null; then
    ok "pty rename: t1r существует"
else
    bad "pty rename: t1r существует"
fi
if tmux_test has-session -t '=t1' 2>/dev/null; then
    bad "pty rename: t1 исчез"
else
    ok "pty rename: t1 исчез"
fi

# kill t1r: 5=kill, 1=t1r, y, 5=shell (остаётся только t2)
( sleep 1; printf '%b' '5\n1\ny\n5\n'; sleep 1 ) \
    | pty 40 >"$TDIR/kill.out" 2>&1
assert_eq "pty kill: rc" 10 $?
if tmux_test has-session -t '=t1r' 2>/dev/null; then
    bad "pty kill: сессия удалена"
else
    ok "pty kill: сессия удалена"
fi

out=$("$SCRIPT" --list 2>&1)
assert_contains "итоговый список содержит t2" "t2" "$out"
if [[ $out == *t1* ]]; then
    bad "итоговый список: лишние сессии"
else
    ok "итоговый список: лишних сессий нет"
fi

# ── итог ─────────────────────────────────────────────────────────────────────
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
