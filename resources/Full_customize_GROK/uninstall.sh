#!/bin/bash
# uninstall.sh — удаление Full_customize_GROK с компьютера
# Запускать из /tmp/Full_customize_GROK (после копирования дистрибутива)
#
# Удаляет:
#   /usr/local/src/Full_customize_GROK
#   /usr/local/bin/customize_roundcube
#
# Опционально (по запросу) откатывает кастомизации Roundcube
# (логотип, фон, CSS, product_name) через встроенный rollback.
set -euo pipefail

DIST_NAME="Full_customize_GROK"
EXPECTED_SRC="/tmp/${DIST_NAME}"
INSTALL_DIR="/usr/local/src/${DIST_NAME}"
BIN_LINK="/usr/local/bin/customize_roundcube"
BACKUP_ROOT="/root/roundcube_custom_backup"

AUTO_YES=false
DO_ROLLBACK=false
DO_REMOVE_BACKUPS=false

die()  { echo "[ОШИБКА] $*" >&2; exit 1; }
info() { echo "--> $*"; }
ok()   { echo "[OK] $*"; }
warn() { echo "[ПРЕДУПРЕЖДЕНИЕ] $*" >&2; }

usage() {
    cat <<EOF
Использование: $0 [ОПЦИИ]

Интерактивный режим (без флагов):
  Запрашивает подтверждения для отката, удаления программы и резервных копий.

Неинтерактивный режим (без TTY):
  --yes                        Автоподтверждение удаления программы
  --rollback                   Перед удалением откатить кастомизации Roundcube
  --remove-backups             Удалить резервные копии (без доп. запросов)
  -h, --help                   Показать эту справку

Комбинации:
  --yes                        Только удалить программу (бэкапы не трогать)
  --yes --rollback             Откат + удаление программы (бэкапы оставить)
  --yes --rollback --remove-backups
                               Полная очистка
  --yes --remove-backups       Удалить программу и бэкапы (без отката)

EOF
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes)
            AUTO_YES=true
            shift
            ;;
        --rollback)
            DO_ROLLBACK=true
            shift
            ;;
        --remove-backups)
            DO_REMOVE_BACKUPS=true
            shift
            ;;
        -h|--help)
            usage 0
            ;;
        *)
            die "Неизвестная опция: $1 (см. --help)"
            ;;
    esac
done

require_root() {
    [[ $EUID -eq 0 ]] || die "Запускайте от root: sudo $0"
}

check_source() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "$here" != "$EXPECTED_SRC" ]]; then
        die "Удаление запускайте из ${EXPECTED_SRC}
Скопируйте папку ${DIST_NAME} в /tmp и выполните:
  sudo /tmp/${DIST_NAME}/uninstall.sh"
    fi
}

prompt_yes_no() {
    local msg="$1" def="${2:-N}" choice
    if [[ "$def" == "Y" ]]; then
        read -rp "$msg [Y/n]: " choice
        choice="${choice:-Y}"
    else
        read -rp "$msg [y/N]: " choice
        choice="${choice:-N}"
    fi
    case "$choice" in
        [YyДд]*) return 0 ;;
        *) return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
remove_program() {
    info "Удаление программы..."

    if [[ -L "$BIN_LINK" ]] || [[ -f "$BIN_LINK" ]]; then
        rm -f "$BIN_LINK"
        ok "Удалён symlink: $BIN_LINK"
    else
        info "Symlink $BIN_LINK не найден"
    fi

    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        ok "Удалён каталог: $INSTALL_DIR"
    else
        info "Каталог $INSTALL_DIR не найден"
    fi

    # Старый backup каталога установки
    if [[ -d "${INSTALL_DIR}.old" ]]; then
        rm -rf "${INSTALL_DIR}.old"
        ok "Удалён ${INSTALL_DIR}.old"
    fi
}

# ---------------------------------------------------------------------------
rollback_customizations() {
    # Пытаемся вызвать rollback установленной (ещё не удалённой) копии
    local main="${INSTALL_DIR}/customize_roundcube.sh"
    if [[ -x "$main" ]]; then
        info "Запуск отката кастомизаций Roundcube..."
        bash -c "
            set -euo pipefail
            source '${INSTALL_DIR}/lib/common.sh'
            source '${INSTALL_DIR}/lib/backup.sh'
            source '${INSTALL_DIR}/lib/config.sh'
            source '${INSTALL_DIR}/lib/css.sh'
            source '${INSTALL_DIR}/lib/apply.sh'
            rollback_to_legacy
        " || warn "Не удалось выполнить автоматический откат. Сделайте вручную при необходимости."
    else
        warn "Скрипт кастомизации не найден — откат пропущен.
При необходимости удалите вручную:
  - ${INSTALL_DIR:+} изображения в skins/elastic/images/custom_logo.* и login_background.*
  - skins/elastic/styles/custom_login.css
  - ключи skin_logo / product_name в custom.inc.php"
    fi
}

remove_backups_interactive() {
    if ls -d ${BACKUP_ROOT}_* >/dev/null 2>&1; then
        info "Найдены резервные копии: ${BACKUP_ROOT}_*"
        if prompt_yes_no "Удалить все резервные копии Roundcube-кастомизаций?" "N"; then
            rm -rf ${BACKUP_ROOT}_* "${BACKUP_ROOT}_latest" 2>/dev/null || true
            ok "Резервные копии удалены"
        else
            info "Резервные копии оставлены в /root/"
        fi
    else
        info "Резервные копии не найдены"
    fi
}

remove_backups_force() {
    if ls -d ${BACKUP_ROOT}_* >/dev/null 2>&1 || [[ -L "${BACKUP_ROOT}_latest" ]]; then
        info "Удаление резервных копий: ${BACKUP_ROOT}_*"
        rm -rf ${BACKUP_ROOT}_* "${BACKUP_ROOT}_latest" 2>/dev/null || true
        ok "Резервные копии удалены"
    else
        info "Резервные копии не найдены"
    fi
}

# ---------------------------------------------------------------------------
require_root
check_source

if $AUTO_YES || $DO_ROLLBACK || $DO_REMOVE_BACKUPS; then
    [[ "$AUTO_YES" == true ]] || die "Неинтерактивный режим требует --yes"
    echo
    echo "=========================================="
    echo "  Удаление Full_customize_GROK (CLI)"
    echo "=========================================="
    echo
    if $DO_ROLLBACK; then
        rollback_customizations
    fi
    remove_program
    if $DO_REMOVE_BACKUPS; then
        remove_backups_force
    fi
    echo
    ok "Удаление завершено."
    echo
    exit 0
fi

echo
echo "=========================================="
echo "  Удаление Full_customize_GROK"
echo "=========================================="
echo

if prompt_yes_no "Откатить кастомизации Roundcube (логотип, фон, цвета, название)?" "Y"; then
    rollback_customizations
fi

remove_program
remove_backups_interactive

echo
ok "Удаление завершено."
echo
