# tmux-login

Интерактивное меню tmux при входе по SSH: показывает существующие сессии,
позволяет подключиться к ним, создать новую, переименовать или удалить,
а также выйти в обычный shell.

После `Ctrl+b d` (detach) SSH-соединение закрывается, а сессия продолжает
жить на сервере — при следующем входе она снова будет в списке.

```
┌─ tmux ────────────────────────────────────────────────┐
│  1  job      1 окн. | detached | 05.11 14:32          │
│  2  work     3 окн. | attached | 04.11 09:10          │
│  3  +  Создать новую сессию                           │
│  4  ~  Переименовать сессию                           │
│  5  x  Удалить сессию                                 │
│  6  >  Выйти в обычный shell                          │
└───────────────────────────────────────────────────────┘
```

## Возможности

- список сессий: имя, число окон, `attached`/`detached`, дата создания;
- подключение по точному имени (`tmux attach -t "=name"`);
- создание сессии с проверкой имени и дублей (пустое имя генерируется);
- переименование и удаление с подтверждением;
- выход в обычный shell без разрыва соединения;
- `whiptail`-меню, а при его отсутствии или маленьком терминале — текстовое;
- не влияет на `scp`, `sftp`, `rsync`, `ssh host command`, ansible;
- автотесты на изолированном tmux-сервере.

## Требования

- Linux (проверено на Ubuntu 24.04);
- bash 4.4+;
- tmux;
- `whiptail` — опционально (пакет `whiptail`/`newt`);
- GNU coreutils (`date`, `timeout`, `install`).

## Установка

```bash
cd ~/projects/tmux-login
make install
# если make не установлен:
./install.sh
```

Установщик:

1. копирует `bin/tmux-login` в `~/.local/bin/tmux-login`;
2. добавляет в `~/.bashrc` блок между маркерами `# >>> tmux-login >>>` и
   `# <<< tmux-login <<<` (перед изменением делается бэкап
   `~/.bashrc.bak.tmux-login`);
3. повторный запуск безопасен — блок заменяется, а не дублируется.

Параметры:

```bash
make install PREFIX=~/.local BASHRC=~/.bashrc
./install.sh --no-bashrc      # только скрипт, без хука
./install.sh --help
```

Удаление:

```bash
make uninstall
```

## Сборка и установка .deb

Пакет собирается штатным `dpkg-deb` — `debhelper`, `fakeroot` и `make` не
нужны.

```bash
./packaging/build-deb.sh
# или, если установлен make:
make deb
```

Результат — `dist/tmux-login_<версия>_all.deb`.

```bash
sudo dpkg -i dist/tmux-login_1.3.0-1_all.deb
sudo apt-get -f install     # при необходимости доустановить зависимости
```

Пакет ставит:

| Путь | Назначение |
|------|------------|
| `/usr/bin/tmux-login` | основной скрипт |
| `/usr/bin/tmux-login-enable` | включение/выключение хука в `~/.bashrc` |
| `/usr/share/man/man1/*.1.gz` | man-страницы |
| `/usr/share/doc/tmux-login/` | README, copyright, changelog |

Параметры сборки:

```bash
DEB_VERSION=1.3.0-1 ./packaging/build-deb.sh   # версия пакета
MAINTAINER='Имя <mail@example.com>' ./packaging/build-deb.sh
DIST_DIR=/tmp/debs ./packaging/build-deb.sh    # куда положить .deb
```

## Сборка и установка .rpm

Для сборки нужен `rpmbuild`:

```bash
# Debian/Ubuntu
sudo apt-get install rpm
# Fedora/RHEL
sudo dnf install rpm-build
```

```bash
./packaging/build-rpm.sh
# или, если установлен make:
make rpm
```

Результат — `dist/tmux-login-<версия>-<релиз>.noarch.rpm`.

```bash
sudo dnf install dist/tmux-login-1.3.0-1.noarch.rpm
# или:
sudo rpm -i dist/tmux-login-1.3.0-1.noarch.rpm
```

Пакет ставит те же файлы, что и `.deb`: `/usr/bin/tmux-login`,
`/usr/bin/tmux-login-enable`, man-страницы и документацию в
`/usr/share/doc/tmux-login/`.

Параметры сборки:

```bash
RPM_RELEASE=2 ./packaging/build-rpm.sh                    # номер релиза
MAINTAINER='Имя <mail@example.com>' ./packaging/build-rpm.sh
DIST_DIR=/tmp/rpms ./packaging/build-rpm.sh               # куда положить .rpm
```

## Gentoo (overlay)

Весь репозиторий является Gentoo-overlay с пакетом
`app-admin/tmux-login`. Подробная инструкция — [`GENTOO.md`](GENTOO.md).

Кратко:

```bash
sudo emerge --ask app-eselect/eselect-repository
sudo eselect repository add tmux-login git https://github.com/vlad-lukyanov/tmux-login.git
sudo emaint sync -r tmux-login

sudo mkdir -p /etc/portage/package.accept_keywords
echo 'app-admin/tmux-login ~amd64' | sudo tee /etc/portage/package.accept_keywords/tmux-login
sudo emerge -av app-admin/tmux-login
```

Ebuild ставит готовые скрипты и man-страницы, сборка не требуется.
После изменения `bin/`, `man/` или документации обнови overlay:

```bash
./sync-overlay.sh          # или make overlay
./sync-overlay.sh --check
```

## Включение автозапуска

Пакеты **не** меняют `~/.bashrc` автоматически (это per-user настройка).
После установки включи автозапуск от своего пользователя:

```bash
tmux-login-enable              # добавить хук в ~/.bashrc
tmux-login-enable --remove     # убрать хук
tmux-login-enable --bashrc ~/.bashrc
```

Перед изменением создаётся `~/.bashrc.bak.tmux-login`; повторный запуск
безопасен — блок заменяется, а не дублируется. Удаление пакета:

```bash
sudo dpkg -r tmux-login        # Debian/Ubuntu
sudo rpm -e tmux-login         # Fedora/RHEL
sudo emerge --unmerge app-admin/tmux-login   # Gentoo
```

Хук в `~/.bashrc` при этом остаётся (пакеты не трогают домашний каталог);
убери его командой `tmux-login-enable --remove` до удаления пакета.

## Использование

Новое SSH-подключение сразу показывает меню. Текущие открытые сессии
не затрагиваются.

```bash
ssh user@server        # → меню
# Enter — подключиться к выбранной сессии
# Ctrl+b d — отцепиться (SSH закроется)
```

Esc или пункт «Выйти в обычный shell» оставляют тебя в обычном shell.

CLI:

```bash
tmux-login            # меню
tmux-login --list     # список сессий без интерактива
tmux-login --version
tmux-login --help
```

Коды возврата:

| Код | Значение |
|-----|----------|
| `0` | отцепился от tmux (или создал сессию и отцепился) → хук закрывает SSH |
| `10` | показать обычный shell (Esc, отмена, «выйти в shell», нет tty) |
| `2` | неизвестный аргумент |

## Как это работает

В конец `~/.bashrc` добавляется блок:

```bash
if [[ -x "$HOME/.local/bin/tmux-login" && -n ${SSH_CONNECTION:-} && -z ${TMUX:-} && -z ${TMUX_PICKER_ACTIVE:-} ]]; then
    export TMUX_PICKER_ACTIVE=1
    "$HOME/.local/bin/tmux-login"
    if (( $? == 0 )); then
        exit 0   # отцепились от tmux — закрываем SSH-соединение
    fi
fi
```

Условия запуска:

- `SSH_CONNECTION` задан — это именно SSH-вход;
- `TMUX` не задан — не запускаться внутри tmux;
- `TMUX_PICKER_ACTIVE` не задан — защита от повторного запуска во вложенных shell;
- скрипт существует и исполняем — если удалить бинарник, вход продолжит работать.

Так как `.bashrc` в неинтерактивном режиме выходит раньше, `scp`/`sftp`/
`ssh host cmd` меню не видят.

## Разработка

```bash
make lint     # bash -n + shellcheck (если установлен)
make test     # автотесты на отдельном tmux-сервере (-L)
make deb      # собрать .deb в dist/
make rpm      # собрать .rpm в dist/
make overlay  # синхронизировать Gentoo overlay (files + Manifest)
make all      # lint + test

# без make:
./tests/run-tests.sh
./packaging/build-deb.sh
./packaging/build-rpm.sh
./sync-overlay.sh
```

Тесты не трогают реальные сессии: для скрипта подменяется `tmux` через
shim с отдельным сокетом, а интерактивные сценарии прогоняются в pty через
`script`. Сборка `.deb` и `.rpm` также проверяется тестами (если установлены
`dpkg-deb` / `rpmbuild`), а для Gentoo-overlay проверяется синхронизация
`files/` и `Manifest`.

Структура:

```
tmux-login/
├── bin/tmux-login              # основной скрипт
├── bin/tmux-login-enable       # управление хуком в ~/.bashrc
├── man/                        # man-страницы
├── packaging/build-deb.sh      # сборка .deb
├── packaging/build-rpm.sh      # сборка .rpm
├── packaging/tmux-login.spec.in # шаблон RPM spec
├── app-admin/tmux-login/       # Gentoo ebuild и files/
├── metadata/                   # Gentoo overlay metadata
├── profiles/                   # Gentoo overlay profiles
├── sync-overlay.sh             # синхронизация Gentoo overlay
├── GENTOO.md                   # инструкция по Gentoo overlay
├── install.sh                  # установка из репозитория
├── uninstall.sh                # удаление
├── tests/run-tests.sh          # автотесты
├── Makefile
├── .github/workflows/ci.yml
├── LICENSE
└── README.md
```

CI (GitHub Actions) выполняет линтер и тесты, а отдельные job собирают
`.deb` и `.rpm`, проверяют содержимое (`dpkg-deb` / `rpm`) и загружают
пакеты как артефакты.

## Ограничения

- рассчитан на bash как login shell; для zsh нужно добавить аналогичный блок
  в `~/.zshrc`;
- tmux переживает разрыв SSH, но не перезагрузку сервера — для этого нужен
  `systemd`/supervisor;
- `ForceCommand` в sshd не используется: автозапуск можно обойти флагами
  `ssh -t host bash --noprofile --norc` (это же служит аварийным входом);
- имена новых сессий ограничены `[A-Za-z0-9._-]`, первый символ — не дефис.

## Лицензия

MIT — см. [LICENSE](LICENSE).
