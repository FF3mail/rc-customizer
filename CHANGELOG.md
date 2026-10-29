# Changelog

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
