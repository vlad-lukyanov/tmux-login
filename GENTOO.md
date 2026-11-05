# Gentoo overlay для tmux-login

Весь репозиторий `https://github.com/vlad-lukyanov/tmux-login` является
Gentoo-overlay: в корне лежат `metadata/`, `profiles/` и категория
`app-admin/` с пакетом `app-admin/tmux-login`.

```
tmux-login/                  # корень репозитория = корень overlay
├── metadata/layout.conf
├── profiles/
│   ├── categories           # только app-admin
│   └── repo_name
├── app-admin/tmux-login/
│   ├── Manifest
│   ├── tmux-login-1.3.0.ebuild
│   └── files/               # скрипты, man-страницы, README, LICENSE
├── bin/                     # исходники проекта
├── man/
├── sync-overlay.sh          # синхронизация files/ + Manifest
└── ...
```

Ebuild не требует сборки: он устанавливает готовые shell-скрипты и
man-страницы. Зависимости: `>=app-shells/bash-4.4` и `app-misc/tmux`.

## Подключение через eselect repository

Нужен пакет `app-eselect/eselect-repository`:

```bash
sudo emerge --ask app-eselect/eselect-repository
```

Добавь overlay и синхронизируй его:

```bash
sudo eselect repository add tmux-login git https://github.com/vlad-lukyanov/tmux-login.git
sudo emaint sync -r tmux-login
```

Проверь, что пакет виден:

```bash
sudo emerge -pv app-admin/tmux-login
```

Если репозиторий с таким именем уже добавлен, сначала удали старую запись:

```bash
sudo eselect repository remove tmux-login
```

Для локальной проверки без GitHub можно добавить текущий каталог (имя
репозитория должно совпадать с `repo-name` в `metadata/layout.conf`):

```bash
sudo eselect repository remove tmux-login   # если уже добавлен
sudo eselect repository add tmux-login git file:///home/spider/projects/tmux-login
sudo emaint sync -r tmux-login
```

## Установка

Пакет помечен нестабильным (`~amd64 ~arm64 ~x86`), поэтому на стабильной
системе разреши keyword:

```bash
sudo mkdir -p /etc/portage/package.accept_keywords
echo 'app-admin/tmux-login ~amd64' | sudo tee /etc/portage/package.accept_keywords/tmux-login
```

Замени `~amd64` на свою архитектуру при необходимости. Затем:

```bash
sudo emerge -av app-admin/tmux-login
```

Включи автозапуск меню при SSH-входе от своего пользователя:

```bash
tmux-login-enable
# отключить: tmux-login-enable --remove
```

Следующее интерактивное SSH-подключение покажет меню. Проверить вручную:

```bash
tmux-login --version
tmux-login --list
```

## Обновление

```bash
sudo emaint sync -r tmux-login
sudo emerge -av -u app-admin/tmux-login
```

После изменения `bin/`, `man/`, `README.md` или `LICENSE` в репозитории
обнови копии в overlay и `Manifest`:

```bash
cd ~/projects/tmux-login
./sync-overlay.sh          # или make overlay
./sync-overlay.sh --check  # только проверка
```

При выпуске новой версии переименуй ebuild
(`tmux-login-X.Y.Z.ebuild`), выполни `sync-overlay.sh` и пересобери пакет:

```bash
sudo emerge -av --unmerge app-admin/tmux-login
sudo emerge -av app-admin/tmux-login
```

## Удаление

```bash
tmux-login-enable --remove
sudo emerge --unmerge app-admin/tmux-login
sudo eselect repository remove tmux-login
sudo rm -rf /var/db/repos/tmux-login   # при необходимости
```

## Примечания

- `HOMEPAGE` в ebuild: `https://github.com/vlad-lukyanov/tmux-login`.
- `profiles/categories` ограничивает сканирование overlay категорией
  `app-admin`, чтобы Portage не пытался читать `bin/`, `tests/` и т.п.
- `sync-overlay.sh` копирует файлы из корня проекта в
  `app-admin/tmux-login/files/` и пересчитывает `Manifest` (SHA256/SHA512),
  поэтому вручную `ebuild ... manifest` запускать не нужно.
- Overlay использует `masters = gentoo`.
