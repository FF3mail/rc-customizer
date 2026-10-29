# lib/backup.sh — резервное копирование и откат

create_backup() {
    local backup_dir="${BACKUP_ROOT}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    info "Создание резервной копии в $backup_dir ..."
    if [[ "$DRY_RUN" == true ]]; then
        info "[dry-run] Будет скопирован $SKIN_DIR и $CUSTOM_CONFIG"
        echo "$backup_dir"
        return 0
    fi
    cp -a "$SKIN_DIR" "$backup_dir/"
    if [[ -f "$CUSTOM_CONFIG" ]]; then
        cp -a "$CUSTOM_CONFIG" "$backup_dir/"
    fi
    # Сохраняем текущий CSS, если есть
    if [[ -f "$CSS_FILE" ]]; then
        cp -a "$CSS_FILE" "$backup_dir/"
    fi
    ln -sfn "$backup_dir" "${BACKUP_ROOT}_latest"
    echo "$backup_dir"
}

restore_from_backup_dir() {
    local backup_dir="$1"
    if [[ ! -d "$backup_dir" ]]; then
        warn "Каталог резервной копии не существует: $backup_dir"
        return 1
    fi
    info "Восстановление из резервной копии: $backup_dir"
    if [[ "$DRY_RUN" == true ]]; then
        info "[dry-run] Будет восстановлен скин и custom.inc.php из $backup_dir"
        return 0
    fi
    # Защита rm -rf
    local expected_skin="${ROUNDCUBE_DIR}/skins/${SKIN}"
    if [[ "$SKIN_DIR" != "$expected_skin" ]]; then
        warn "SKIN_DIR имеет неожиданное значение ('$SKIN_DIR'). Отказ от удаления."
        return 1
    fi
    if [[ "$ROUNDCUBE_DIR" != "/opt/www/roundcubemail" ]]; then
        warn "ROUNDCUBE_DIR имеет неожиданное значение ('$ROUNDCUBE_DIR'). Отказ от удаления."
        return 1
    fi
    if [[ -d "$backup_dir/$(basename "$SKIN_DIR")" ]]; then
        rm -rf "$SKIN_DIR"
        cp -a \
            "$backup_dir/$(basename "$SKIN_DIR")" \
            "$SKIN_DIR"
        chown -R www-data:www-data "$SKIN_DIR" 2>/dev/null || true
    else
        warn "Каталог скина не найден внутри резервной копии – пропуск восстановления скина"
    fi
    if [[ -f "$backup_dir/custom.inc.php" ]]; then
        mkdir -p "$CUSTOM_DIR"
        cp -a \
            "$backup_dir/custom.inc.php" \
            "$CUSTOM_CONFIG"
        chown www-data:www-data "$CUSTOM_CONFIG" 2>/dev/null || true
    else
        rm -f "$CUSTOM_CONFIG"
    fi
    return 0
}

rollback_to_legacy() {
    info "Откат к состоянию из предыдущей последней резервной копии..."
    local prev_latest=""
    local latest_link="${BACKUP_ROOT}_latest"
    # Захватываем текущий latest ДО создания safety-бэкапа
    if [[ -L "$latest_link" ]]; then
        prev_latest=$(readlink -f "$latest_link" 2>/dev/null || true)
    fi
    # Safety-бэкап текущего состояния
    create_backup >/dev/null
    if [[ -n "$prev_latest" && -d "$prev_latest" ]]; then
        if restore_from_backup_dir "$prev_latest"; then
            if [[ "$DRY_RUN" != true ]]; then
                ln -sfn "$prev_latest" "$latest_link"
            fi
            reload_php_fpm
            RESTORED_LEGACY=true
            info "Откат завершён (восстановлено из $prev_latest)."
            return 0
        fi
    fi
    # Fallback
    warn "Подходящая предыдущая резервная копия не найдена – выполняется простая очистка кастомизаций"
    if [[ "$DRY_RUN" == true ]]; then
        info "[dry-run] Будут удалены кастомный логотип, фон, CSS и ключи конфига"
        unlink_custom_css
    else
        remove_custom_config_key "skin_logo"
        remove_custom_config_key "product_name"
        rm -f "${SKIN_DIR}/images/custom_logo."*
        rm -f "${SKIN_DIR}/images/login_background."*
        rm -f "$CSS_FILE"
        unlink_custom_css
    fi
    reload_php_fpm
    RESTORED_LEGACY=true
    info "Откат завершён (резервная очистка)."
}
