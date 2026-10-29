#!/bin/bash
# customize_roundcube.sh
# Кастомизация страницы входа Roundcube в iRedMail (Ubuntu 24.04+)
# Русская локализация интерфейса. Модульная структура.
#
# Модули (в каталоге lib/):
#   common.sh  — константы, хелперы, проверки
#   backup.sh  — резервное копирование и откат
#   config.sh  — работа с PHP-конфигами
#   css.sh     — генерация и подключение custom_login.css
#   apply.sh   — применение логотипа / фона / текста / цветов
#   menu.sh    — интерактивное меню
#
# Security / correctness:
# 1. Rollback restores the *previous* latest backup
# 2. MIME check is strict when 'file' is available
# 3. Config key removal does not use unescaped regex input
# 4. CSS write is atomic (mktemp + mv)
# 5. restore_from_backup_dir protects rm -rf with path validation
# 6. SVG is allowed but scanned for dangerous constructs
# 7. Custom CSS is explicitly linked from layout.html
# 8. Existing managed CSS link is removed/replaced safely
# 9. Main Roundcube config ownership/mode is preserved
# 10. Generated custom PHP config is syntax-checked before installation
set -euo pipefail
export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"

# ---------------------------------------------------------------------------
# Определение каталога скрипта и подключение модулей
# (корректно при запуске через symlink, напр. /usr/local/bin/customize_roundcube)
# ---------------------------------------------------------------------------
SOURCE="${BASH_SOURCE[0]}"
while [[ -h "$SOURCE" ]]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

for mod in common backup config css apply menu; do
    if [[ ! -f "${LIB_DIR}/${mod}.sh" ]]; then
        echo "[ОШИБКА] Не найден модуль: ${LIB_DIR}/${mod}.sh" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "${LIB_DIR}/${mod}.sh"
done

# ---------------------------------------------------------------------------
# Справка
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
Использование: $0 [ОПЦИИ]

Основные опции:
  -l, --logo PATH              Путь к файлу логотипа (PNG, JPG, SVG, WEBP)
  -b, --background PATH        Путь к фоновому изображению (JPG, PNG, WEBP)
  -t, --text TEXT              Название продукта (заголовок и подвал)

Цвета (формат #RGB, #RRGGBB или rgba(...)):
  --text-color COLOR           Цвет надписи (product name / footer)
  --form-bg COLOR              Фон окна формы входа
  --input-bg COLOR             Фон полей ввода (логин/пароль)
  --input-color COLOR          Цвет текста в полях
  --input-border COLOR         Цвет рамки полей
  --input-focus COLOR          Цвет рамки при фокусе
  --button-bg COLOR            Фон кнопки «Войти»
  --button-color COLOR         Цвет текста кнопки

Прочее:
  -i, --interactive            Запустить интерактивное меню
  --test                       Только проверить окружение
  --dry-run                    Показать, что будет сделано, без изменений
  --rollback                   Откат к предыдущей резервной копии (без меню)
  --yes                        Автоматически «да» на внутренние запросы (зарезервировано)
  -h, --help                   Показать эту справку

Примечания:
  - SVG-логотипы принимаются, но проверяются на опасные конструкции.
  - Используется отдельный файл custom_login.css.
  - custom_login.css явно подключается из Elastic layout.html.
  - Цвета применяются через CSS и сохраняются в custom_login.css.

Примеры:
  $0 --logo /tmp/logo.png --background /tmp/bg.jpg --text "Моя Почта"
  $0 --text-color "#ffffff" --form-bg "rgba(0,0,0,0.7)" --input-bg "#1a1a1a"
  $0 -i
EOF
    exit "${1:-0}"
}

# ---------------------------------------------------------------------------
# Точка входа
# ---------------------------------------------------------------------------
require_root

LOGO_PATH=""
BG_PATH=""
CUSTOM_TEXT=""
ROLLBACK_MODE=false
ASSUME_YES=false

if [[ $# -eq 0 ]]; then
    run_tests
    start_interactive_menu
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -l|--logo)
            [[ $# -lt 2 ]] && { echo "Ошибка: отсутствует аргумент для $1" >&2; usage 1; }
            LOGO_PATH="$2"
            shift 2
            ;;
        -b|--background)
            [[ $# -lt 2 ]] && { echo "Ошибка: отсутствует аргумент для $1" >&2; usage 1; }
            BG_PATH="$2"
            shift 2
            ;;
        -t|--text)
            [[ $# -lt 2 ]] && { echo "Ошибка: отсутствует аргумент для $1" >&2; usage 1; }
            CUSTOM_TEXT="$2"
            shift 2
            ;;
        --text-color)
            [[ $# -lt 2 ]] && { echo "Ошибка: отсутствует аргумент для $1" >&2; usage 1; }
            TEXT_COLOR="$2"
            shift 2
            ;;
        --form-bg)
            [[ $# -lt 2 ]] && { echo "Ошибка: отсутствует аргумент для $1" >&2; usage 1; }
            FORM_BG="$2"
            shift 2
            ;;
        --input-bg)
            [[ $# -lt 2 ]] && { echo "Ошибка: отсутствует аргумент для $1" >&2; usage 1; }
            INPUT_BG="$2"
            shift 2
            ;;
        --input-color)
            [[ $# -lt 2 ]] && { echo "Ошибка: отсутствует аргумент для $1" >&2; usage 1; }
            INPUT_COLOR="$2"
            shift 2
            ;;
        --input-border)
            [[ $# -lt 2 ]] && { echo "Ошибка: отсутствует аргумент для $1" >&2; usage 1; }
            INPUT_BORDER="$2"
            shift 2
            ;;
        --input-focus)
            [[ $# -lt 2 ]] && { echo "Ошибка: отсутствует аргумент для $1" >&2; usage 1; }
            INPUT_FOCUS="$2"
            shift 2
            ;;
        --button-bg)
            [[ $# -lt 2 ]] && { echo "Ошибка: отсутствует аргумент для $1" >&2; usage 1; }
            BUTTON_BG="$2"
            shift 2
            ;;
        --button-color)
            [[ $# -lt 2 ]] && { echo "Ошибка: отсутствует аргумент для $1" >&2; usage 1; }
            BUTTON_COLOR="$2"
            shift 2
            ;;
        -i|--interactive)
            run_tests
            start_interactive_menu
            exit 0
            ;;
        --test)
            run_tests </dev/null
            echo "Проверки успешно завершены."
            exit 0
            ;;
        --rollback)
            ROLLBACK_MODE=true
            shift
            ;;
        --yes)
            ASSUME_YES=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage 0
            ;;
        *)
            echo "Неизвестная опция: $1" >&2
            usage 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# CLI-режим
# ---------------------------------------------------------------------------
if $ROLLBACK_MODE; then
    run_tests </dev/null
    rollback_to_legacy
    print_summary
    exit 0
fi

run_tests </dev/null
create_backup >/dev/null

[[ -n "$LOGO_PATH" ]] && apply_logo "$LOGO_PATH"
[[ -n "$BG_PATH" ]]   && apply_background "$BG_PATH"
[[ -n "$CUSTOM_TEXT" ]] && apply_text "$CUSTOM_TEXT"

# Если задан хотя бы один цвет — применяем цвета
if [[ -n "$TEXT_COLOR" || -n "$FORM_BG" || -n "$INPUT_BG" || \
      -n "$INPUT_COLOR" || -n "$INPUT_BORDER" || -n "$INPUT_FOCUS" || \
      -n "$BUTTON_BG" || -n "$BUTTON_COLOR" ]]; then
    apply_colors
fi

if $MODIFIED_LOGO || $MODIFIED_BG || $MODIFIED_TEXT || $MODIFIED_COLORS; then
    reload_php_fpm
fi

print_summary
