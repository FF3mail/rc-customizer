# lib/common.sh — общие константы, хелперы, проверки
# Используется всеми модулями customize_roundcube

# ---------------------------------------------------------------------------
# Конфигурация путей
# ---------------------------------------------------------------------------
ROUNDCUBE_DIR="/opt/www/roundcubemail"
MAIN_CONFIG="${ROUNDCUBE_DIR}/config/config.inc.php"
SKIN="elastic"
SKIN_DIR="${ROUNDCUBE_DIR}/skins/${SKIN}"
LAYOUT_TEMPLATE="${SKIN_DIR}/templates/includes/layout.html"
CUSTOM_DIR="/opt/iredmail/custom/roundcube"
CUSTOM_CONFIG="${CUSTOM_DIR}/custom.inc.php"
CSS_FILE="${SKIN_DIR}/styles/custom_login.css"
CSS_LINK_MARKER="customize_roundcube.sh: custom_login.css"
BACKUP_ROOT="/root/roundcube_custom_backup"
ALLOWED_LOGO_EXT="png jpg jpeg svg webp"
ALLOWED_BG_EXT="png jpg jpeg webp"

# Цвета по умолчанию (можно переопределить)
DEFAULT_TEXT_COLOR="#ffffff"
DEFAULT_FORM_BG="rgba(255,255,255,0.92)"
DEFAULT_INPUT_BG="#ffffff"
DEFAULT_INPUT_COLOR="#212529"
DEFAULT_INPUT_BORDER="#ced4da"
DEFAULT_INPUT_FOCUS="#37beff"
DEFAULT_BUTTON_BG="#37beff"
DEFAULT_BUTTON_COLOR="#ffffff"

# Runtime-флаги
MODIFIED_LOGO=false
MODIFIED_BG=false
MODIFIED_TEXT=false
MODIFIED_COLORS=false
RESTORED_LEGACY=false
DRY_RUN=false

# Текущие значения цветов (заполняются при запуске)
TEXT_COLOR=""
FORM_BG=""
INPUT_BG=""
INPUT_COLOR=""
INPUT_BORDER=""
INPUT_FOCUS=""
BUTTON_BG=""
BUTTON_COLOR=""

# ---------------------------------------------------------------------------
# Хелперы вывода
# ---------------------------------------------------------------------------
die() {
    echo "[ОШИБКА] $*" >&2
    exit 1
}
info() {
    echo "--> $*"
}
ok() {
    echo "[OK] $*"
}
warn() {
    echo "[ПРЕДУПРЕЖДЕНИЕ] $*" >&2
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        die "Этот скрипт необходимо запускать от имени root."
    fi
}

# Resolve real path and reject symlinks / non-regular files.
safe_realpath() {
    local path="$1"
    local resolved
    if command -v realpath >/dev/null 2>&1; then
        resolved=$(realpath -e "$path" 2>/dev/null) || return 1
    else
        resolved=$(readlink -f "$path" 2>/dev/null) || return 1
    fi
    [[ -f "$resolved" && ! -L "$resolved" ]] || return 1
    echo "$resolved"
}

validate_extension() {
    local file="$1"
    local allowed="$2"
    local ext="${file##*.}"
    ext="${ext,,}"
    for a in $allowed; do
        [[ "$ext" == "$a" ]] && return 0
    done
    return 1
}

# Строгая проверка MIME, если доступна утилита file
check_mime() {
    local file="$1"
    if ! command -v file >/dev/null 2>&1; then
        return 0
    fi
    local mime
    mime=$(file -b --mime-type "$file" 2>/dev/null || true)
    if [[ -z "$mime" ]]; then
        return 0
    fi
    case "$mime" in
        image/*)
            return 0
            ;;
        *)
            die "Файл '$file' отклонён: MIME-тип '$mime' не является изображением (требуется image/*)."
            ;;
    esac
}

# Базовая проверка SVG на опасные конструкции
check_svg_safety() {
    local file="$1"
    if grep -qiE \
        -e '<script' \
        -e '\bon\w+\s*=' \
        -e 'javascript:' \
        -e 'data:text/html' \
        -e '<foreignObject' \
        -e '<iframe' \
        -e '<embed' \
        -e '<object' \
        -e 'xlink:href\s*=\s*["'\'']?https?:' \
        "$file" 2>/dev/null; then
        die "SVG-файл '$file' содержит потенциально опасные конструкции (script/обработчики событий/внешние ссылки). Отклонён."
    fi
}

# Проверка цвета в формате #RGB / #RRGGBB / rgba(...)
validate_color() {
    local color="$1"
    local name="$2"
    if [[ -z "$color" ]]; then
        return 0
    fi
    if [[ "$color" =~ ^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$ ]]; then
        return 0
    fi
    if [[ "$color" =~ ^rgba?\([0-9,\.[:space:]]+\)$ ]]; then
        return 0
    fi
    die "Некорректный цвет для $name: '$color'. Ожидается #RGB, #RRGGBB или rgba(...)."
}

detect_php_fpm() {
    local unit=""
    if command -v php >/dev/null 2>&1; then
        local ver
        ver=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)
        if [[ -n "$ver" ]] &&
           systemctl is-active --quiet "php${ver}-fpm" 2>/dev/null; then
            echo "php${ver}-fpm"
            return 0
        fi
    fi
    unit=$(
        systemctl list-units \
            --type=service \
            --state=active \
            --no-legend \
            'php*-fpm.service' 2>/dev/null |
            awk '{print $1}' |
            head -n1 || true
    )
    if [[ -n "$unit" ]]; then
        echo "${unit%.service}"
        return 0
    fi
    for v in 8.4 8.3 8.2 8.1 8.0; do
        if systemctl is-active --quiet "php${v}-fpm" 2>/dev/null; then
            echo "php${v}-fpm"
            return 0
        fi
    done
    return 1
}

run_tests() {
    echo "=== Проверка окружения ==="
    require_root
    ok "Запущено от имени root"
    [[ -d "$ROUNDCUBE_DIR" ]] ||
        die "Каталог Roundcube не найден: $ROUNDCUBE_DIR"
    ok "Каталог Roundcube найден"
    [[ -d "$SKIN_DIR" ]] ||
        die "Каталог скина не найден: $SKIN_DIR"
    ok "Скин '$SKIN' найден"
    [[ -f "$LAYOUT_TEMPLATE" ]] ||
        die "Шаблон layout.html не найден: $LAYOUT_TEMPLATE"
    ok "Шаблон layout.html найден"
    [[ -f "$MAIN_CONFIG" ]] ||
        warn "Основной конфиг не найден: $MAIN_CONFIG (будет пропущен, если отсутствует)"
    if detect_php_fpm >/dev/null; then
        ok "Служба PHP-FPM обнаружена: $(detect_php_fpm)"
    else
        warn "Активная служба php*-fpm не найдена (перезагрузка будет пропущена)"
    fi
    echo "=== Все критические проверки пройдены ==="
    echo
    return 0
}
