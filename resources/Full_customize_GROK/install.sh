#!/bin/bash
# install.sh — установка Full_customize_GROK
# Запускать только из /tmp/Full_customize_GROK (после копирования дистрибутива)
#
# Устанавливает в: /usr/local/src/Full_customize_GROK
# Создаёт symlink:  /usr/local/bin/customize_roundcube
set -euo pipefail

DIST_NAME="Full_customize_GROK"
EXPECTED_SRC="/tmp/${DIST_NAME}"
INSTALL_DIR="/usr/local/src/${DIST_NAME}"
BIN_LINK="/usr/local/bin/customize_roundcube"
MAIN_SCRIPT="customize_roundcube.sh"

die()  { echo "[ОШИБКА] $*" >&2; exit 1; }
info() { echo "--> $*"; }
ok()   { echo "[OK] $*"; }

# ---------------------------------------------------------------------------
require_root() {
    [[ $EUID -eq 0 ]] || die "Запускайте от root: sudo $0"
}

# Проверяем, что мы внутри правильного каталога дистрибутива
check_source() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [[ "$here" != "$EXPECTED_SRC" ]]; then
        die "Установка разрешена только из ${EXPECTED_SRC}
Текущий каталог: ${here}

Скопируйте папку ${DIST_NAME} в /tmp и запустите:
  sudo /tmp/${DIST_NAME}/install.sh"
    fi

    [[ -f "${here}/${MAIN_SCRIPT}" ]] || die "Не найден ${MAIN_SCRIPT} в ${here}"
    [[ -d "${here}/lib" ]]            || die "Не найдена папка lib/ в ${here}"

    local needed
    for needed in common backup config css apply menu; do
        [[ -f "${here}/lib/${needed}.sh" ]] || die "Не найден lib/${needed}.sh"
    done
    ok "Дистрибутив в ${here} проверен"
}

# ---------------------------------------------------------------------------
do_install() {
    info "Установка в ${INSTALL_DIR} ..."

    if [[ -d "$INSTALL_DIR" ]]; then
        info "Обнаружена предыдущая установка — обновление"
        rm -rf "${INSTALL_DIR}.old" 2>/dev/null || true
        mv "$INSTALL_DIR" "${INSTALL_DIR}.old"
    fi

    mkdir -p "$(dirname "$INSTALL_DIR")"
    cp -a "$EXPECTED_SRC" "$INSTALL_DIR"

    # Права
    chmod 755 "${INSTALL_DIR}/${MAIN_SCRIPT}"
    chmod 644 "${INSTALL_DIR}/lib/"*.sh
    # install/uninstall оставляем исполняемыми только в исходнике /tmp — в системе не нужны
    rm -f "${INSTALL_DIR}/install.sh" "${INSTALL_DIR}/uninstall.sh" 2>/dev/null || true

    # Symlink для удобного запуска
    ln -sfn "${INSTALL_DIR}/${MAIN_SCRIPT}" "$BIN_LINK"
    chmod 755 "$BIN_LINK" 2>/dev/null || true

    ok "Установлено: ${INSTALL_DIR}"
    ok "Команда:     customize_roundcube  (или ${BIN_LINK})"
}

# ---------------------------------------------------------------------------
print_next_steps() {
    cat <<EOF

==========================================
  Установка завершена
==========================================

Запуск:
  sudo customize_roundcube -i
  sudo customize_roundcube --test
  sudo customize_roundcube --help

Руководство:
  less ${INSTALL_DIR}/GUIDE.md

Удаление:
  # снова скопируйте дистрибутив в /tmp и выполните:
  sudo /tmp/${DIST_NAME}/uninstall.sh

EOF
}

# ---------------------------------------------------------------------------
require_root
check_source
do_install
print_next_steps
