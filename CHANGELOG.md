# Changelog

## v1.0.1 (2026-10-29)

- Иконка **rc-customizer.ico** в `RCCustomizer.exe` (файл в проводнике) и в заголовке окна.
- Сборка через `build.spec` (единый spec с `icon=`).

## v1.0.0 (2026-10-29)

- Первый публичный релиз **RCCustomizer.exe** (Windows 10+, onefile).
- GUI: SSH/SFTP, установка, кастомизация, откат, удаление (русский интерфейс).
- В bundle: **Full_customize_GROK** с CLI `--rollback` / `uninstall.sh --yes` и исправлением пути `lib/` через symlink.
- Удалённые команды вызывают `bash /usr/local/src/Full_customize_GROK/customize_roundcube.sh` (стабильно до и после обновления на сервере).

## CLI extensions (Full_customize_GROK)

### customize_roundcube.sh

- **`--rollback`** — неинтерактивный откат через `rollback_to_legacy`, затем `print_summary` и выход 0.
- **`--yes`** — зарезервировано для автоподтверждения внутренних запросов (pass-through).
- Обновлена справка **`--help`**.
- CLI-пути (`--test`, `--dry-run`, `--rollback`, обычная кастомизация) не обращаются к `read`; добавлен `</dev/null` для `run_tests` где уместно.

### uninstall.sh

- **`--yes`** — удаление программы без интерактивных запросов.
- **`--rollback`** — откат кастомизаций перед удалением (с `--yes`).
- **`--remove-backups`** — удаление резервных копий без запроса (с `--yes`).
- Комбинации: `--yes` | `--yes --rollback` | `--yes --rollback --remove-backups` | `--yes --remove-backups`.
- При наличии любого из новых флагов скрипт не вызывает `read` / `prompt_yes_no`.
- Обновлена справка **`--help`**.

## RC Customizer GUI (rc-customizer-gui)

- Первый релиз: Tkinter-оболочка, Paramiko SSH/SFTP, PyInstaller onefile `RCCustomizer.exe`.
