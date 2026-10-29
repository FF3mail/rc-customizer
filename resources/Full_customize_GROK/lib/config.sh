# lib/config.sh — работа с custom.inc.php и основным конфигом Roundcube

ensure_custom_config_included() {
    [[ -f "$MAIN_CONFIG" ]] || return 0
    local include_line="include_once '${CUSTOM_CONFIG}';"
    if ! grep -qF "$include_line" "$MAIN_CONFIG"; then
        if [[ "$DRY_RUN" == true ]]; then
            info "[dry-run] Будет добавлено подключение custom.inc.php в основной конфиг"
            return 0
        fi
        {
            echo ""
            echo "// Custom configuration (managed by customize_roundcube.sh)"
            echo "$include_line"
        } >> "$MAIN_CONFIG"
        info "Добавлено подключение custom.inc.php в основной конфиг"
    fi
}

_remove_config_key_lines() {
    local key="$1"
    local src="$2"
    local dst="$3"
    awk -v k="$key" '
        BEGIN {
            pat = "^[[:space:]]*\\$config\\[\\047" k "\\047\\]"
        }
        $0 ~ pat {
            next
        }
        {
            print
        }
    ' "$src" > "$dst"
}

update_custom_config() {
    local key="$1"
    local value="$2"
    mkdir -p "$CUSTOM_DIR"
    if [[ "$DRY_RUN" == true ]]; then
        info "[dry-run] Будет установлено \$config['${key}'] = ${value}"
        return 0
    fi
    local tmp
    tmp=$(mktemp)
    if [[ -f "$CUSTOM_CONFIG" ]]; then
        _remove_config_key_lines "$key" "$CUSTOM_CONFIG" "$tmp"
        sed -i '/^[[:space:]]*?>[[:space:]]*$/d' "$tmp" || true
    else
        echo "<?php" > "$tmp"
    fi
    # Гарантируем завершающий перевод строки
    if [[ -s "$tmp" ]] &&
       [[ "$(tail -c1 "$tmp" | wc -l)" -eq 0 ]]; then
        echo >> "$tmp"
    fi
    echo "\$config['${key}'] = ${value};" >> "$tmp"
    if ! php -l "$tmp" >/dev/null 2>&1; then
        rm -f "$tmp"
        die "Сгенерированный PHP-конфиг невалиден (php -l завершился с ошибкой)"
    fi
    mv "$tmp" "$CUSTOM_CONFIG"
    chown www-data:www-data "$CUSTOM_CONFIG" 2>/dev/null || true
    chmod 644 "$CUSTOM_CONFIG"
    ensure_custom_config_included
}

remove_custom_config_key() {
    local key="$1"
    [[ -f "$CUSTOM_CONFIG" ]] || return 0
    if [[ "$DRY_RUN" == true ]]; then
        info "[dry-run] Будет удалён \$config['${key}']"
        return 0
    fi
    local tmp
    tmp=$(mktemp)
    _remove_config_key_lines "$key" "$CUSTOM_CONFIG" "$tmp"
    mv "$tmp" "$CUSTOM_CONFIG"
    chown www-data:www-data "$CUSTOM_CONFIG" 2>/dev/null || true
}
