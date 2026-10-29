# lib/apply.sh — применение логотипа, фона, текста и цветов

apply_logo() {
    local path="$1"
    local resolved
    resolved=$(safe_realpath "$path") ||
        die "Файл логотипа не найден или является символической ссылкой: $path"
    validate_extension "$resolved" "$ALLOWED_LOGO_EXT" ||
        die "Неподдерживаемое расширение логотипа. Разрешено: $ALLOWED_LOGO_EXT"
    check_mime "$resolved"
    local ext="${resolved##*.}"
    ext="${ext,,}"
    if [[ "$ext" == "svg" ]]; then
        info "Обнаружен SVG-логотип – выполняется проверка безопасности..."
        check_svg_safety "$resolved"
        warn "SVG принят после базовой проверки безопасности. Для максимальной безопасности предпочтительнее PNG/WebP."
    fi
    local dest_logo="${SKIN_DIR}/images/custom_logo.${ext}"
    local logo_url="skins/${SKIN}/images/custom_logo.${ext}"
    if [[ "$DRY_RUN" == true ]]; then
        info "[dry-run] Будет установлен логотип $resolved -> $dest_logo"
        MODIFIED_LOGO=true
        return 0
    fi
    rm -f "${SKIN_DIR}/images/custom_logo."*
    cp "$resolved" "$dest_logo"
    chown www-data:www-data "$dest_logo" || true
    chmod 644 "$dest_logo"
    update_custom_config "skin_logo" "'${logo_url}'"
    MODIFIED_LOGO=true
    info "Логотип успешно обновлён"
}

apply_background() {
    local path="$1"
    local resolved
    resolved=$(safe_realpath "$path") ||
        die "Файл фона не найден или является символической ссылкой: $path"
    validate_extension "$resolved" "$ALLOWED_BG_EXT" ||
        die "Неподдерживаемое расширение фона. Разрешено: $ALLOWED_BG_EXT"
    check_mime "$resolved"
    local ext="${resolved##*.}"
    ext="${ext,,}"
    local dest_bg="${SKIN_DIR}/images/login_background.${ext}"
    if [[ "$DRY_RUN" == true ]]; then
        info "[dry-run] Будет установлен фон $resolved -> $dest_bg"
        MODIFIED_BG=true
        generate_custom_css
        return 0
    fi
    rm -f "${SKIN_DIR}/images/login_background."*
    cp "$resolved" "$dest_bg"
    chown www-data:www-data "$dest_bg" || true
    chmod 644 "$dest_bg"
    MODIFIED_BG=true
    generate_custom_css
    info "Фоновое изображение обновлено"
}

apply_text() {
    local text="$1"
    local escaped
    escaped=$(
        printf '%s' "$text" |
            sed "s/\\\\/\\\\\\\\/g; s/'/\\\\'/g"
    )
    update_custom_config "product_name" "'${escaped}'"
    MODIFIED_TEXT=true
    info "Название продукта обновлено (заголовок и подвал)"
}

# Применение цветов (все или частично)
# Аргументы можно передавать через глобальные переменные TEXT_COLOR и т.д.
apply_colors() {
    # Валидация всех заданных цветов
    validate_color "$TEXT_COLOR" "цвет надписи (TEXT_COLOR)"
    validate_color "$FORM_BG" "фон формы (FORM_BG)"
    validate_color "$INPUT_BG" "фон полей (INPUT_BG)"
    validate_color "$INPUT_COLOR" "цвет текста полей (INPUT_COLOR)"
    validate_color "$INPUT_BORDER" "цвет рамки полей (INPUT_BORDER)"
    validate_color "$INPUT_FOCUS" "цвет фокуса (INPUT_FOCUS)"
    validate_color "$BUTTON_BG" "фон кнопки (BUTTON_BG)"
    validate_color "$BUTTON_COLOR" "цвет текста кнопки (BUTTON_COLOR)"

    # Если ничего не задано — используем значения по умолчанию (но всё равно перегенерируем)
    TEXT_COLOR="${TEXT_COLOR:-$DEFAULT_TEXT_COLOR}"
    FORM_BG="${FORM_BG:-$DEFAULT_FORM_BG}"
    INPUT_BG="${INPUT_BG:-$DEFAULT_INPUT_BG}"
    INPUT_COLOR="${INPUT_COLOR:-$DEFAULT_INPUT_COLOR}"
    INPUT_BORDER="${INPUT_BORDER:-$DEFAULT_INPUT_BORDER}"
    INPUT_FOCUS="${INPUT_FOCUS:-$DEFAULT_INPUT_FOCUS}"
    BUTTON_BG="${BUTTON_BG:-$DEFAULT_BUTTON_BG}"
    BUTTON_COLOR="${BUTTON_COLOR:-$DEFAULT_BUTTON_COLOR}"

    generate_custom_css
    MODIFIED_COLORS=true
    info "Цвета формы и надписи обновлены"
}

reload_php_fpm() {
    local fpm
    if fpm=$(detect_php_fpm); then
        if [[ "$DRY_RUN" == true ]]; then
            info "[dry-run] Будет перезагружен $fpm"
        else
            info "Перезагрузка $fpm для очистки OPcache..."
            systemctl reload "$fpm" ||
                warn "Не удалось перезагрузить $fpm"
        fi
    else
        warn "Служба PHP-FPM не найдена – перезагрузка пропущена"
    fi
    # Очистка кэша шаблонов Roundcube
    if [[ -d "${ROUNDCUBE_DIR}/temp" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            info "[dry-run] Будет очищен ${ROUNDCUBE_DIR}/temp/*"
        else
            if [[ "$ROUNDCUBE_DIR" == /opt/www/roundcubemail ]]; then
                find "${ROUNDCUBE_DIR}/temp" \
                    -mindepth 1 \
                    -delete 2>/dev/null || true
                chown -R www-data:www-data \
                    "${ROUNDCUBE_DIR}/temp" 2>/dev/null || true
            else
                warn "Неожиданный ROUNDCUBE_DIR – отказ от очистки temp"
            fi
        fi
    fi
}

print_summary() {
    echo
    echo "=========================================="
    echo "           ИТОГИ ВЫПОЛНЕНИЯ               "
    echo "=========================================="
    if $RESTORED_LEGACY; then
        echo " - Выполнен откат / восстановление из резервной копии."
    else
        [[ "$MODIFIED_LOGO" == true ]] &&
            echo " - Логотип:       Обновлён" ||
            echo " - Логотип:       Без изменений"
        [[ "$MODIFIED_BG" == true ]] &&
            echo " - Фон:           Обновлён" ||
            echo " - Фон:           Без изменений"
        [[ "$MODIFIED_TEXT" == true ]] &&
            echo " - Название:      Обновлено" ||
            echo " - Название:      Без изменений"
        [[ "$MODIFIED_COLORS" == true ]] &&
            echo " - Цвета:         Обновлены" ||
            echo " - Цвета:         Без изменений"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        echo " - Режим:         DRY-RUN (изменения не вносились)"
    fi
    echo "=========================================="
    echo
}
