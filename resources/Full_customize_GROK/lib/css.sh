# lib/css.sh — подключение и генерация custom_login.css

unlink_custom_css() {
    [[ -f "$LAYOUT_TEMPLATE" ]] || return 0
    if grep -qF "$CSS_LINK_MARKER" "$LAYOUT_TEMPLATE"; then
        if [[ "$DRY_RUN" == true ]]; then
            info "[dry-run] Будет удалена управляемая ссылка custom_login.css из layout.html"
            return 0
        fi
        local tmp
        tmp=$(mktemp)
        grep -vF "$CSS_LINK_MARKER" "$LAYOUT_TEMPLATE" > "$tmp"
        mv "$tmp" "$LAYOUT_TEMPLATE"
        chown www-data:www-data "$LAYOUT_TEMPLATE" 2>/dev/null || true
        chmod 644 "$LAYOUT_TEMPLATE" 2>/dev/null || true
        info "Управляемая ссылка custom_login.css удалена из layout.html"
    fi
}

link_custom_css() {
    [[ -f "$LAYOUT_TEMPLATE" ]] ||
        die "Шаблон layout.html не найден: $LAYOUT_TEMPLATE"
    unlink_custom_css
    local css_tag
    css_tag="    <!-- ${CSS_LINK_MARKER} -->"$'\n'
    css_tag+="    <link rel=\"stylesheet\" type=\"text/css\" href=\"skins/${SKIN}/styles/custom_login.css\">"
    if ! grep -qF "</head>" "$LAYOUT_TEMPLATE"; then
        die "Закрывающий тег </head> не найден в $LAYOUT_TEMPLATE"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        info "[dry-run] Будет вставлена ссылка custom_login.css в layout.html"
        return 0
    fi
    local tmp
    tmp=$(mktemp)
    awk -v tag="$css_tag" '
        !inserted && /<\/head>/ {
            print tag
            inserted=1
        }
        {
            print
        }
    ' "$LAYOUT_TEMPLATE" > "$tmp"
    if ! grep -qF "$CSS_LINK_MARKER" "$tmp"; then
        rm -f "$tmp"
        die "Не удалось вставить ссылку custom_login.css в layout.html"
    fi
    mv "$tmp" "$LAYOUT_TEMPLATE"
    chown www-data:www-data "$LAYOUT_TEMPLATE" 2>/dev/null || true
    chmod 644 "$LAYOUT_TEMPLATE" 2>/dev/null || true
    info "custom_login.css подключён в layout.html"
}

# Определяем расширение фонового изображения (если есть)
_detect_bg_ext() {
    local f
    for f in "${SKIN_DIR}/images/login_background."*; do
        if [[ -f "$f" ]]; then
            echo "${f##*.}"
            return 0
        fi
    done
    echo ""
}

# Генерация полного CSS (фон + цвета)
# Вызывается после любого изменения фона или цветов
generate_custom_css() {
    local bg_ext
    bg_ext=$(_detect_bg_ext)

    local text_c="${TEXT_COLOR:-$DEFAULT_TEXT_COLOR}"
    local form_bg="${FORM_BG:-$DEFAULT_FORM_BG}"
    local input_bg="${INPUT_BG:-$DEFAULT_INPUT_BG}"
    local input_c="${INPUT_COLOR:-$DEFAULT_INPUT_COLOR}"
    local input_b="${INPUT_BORDER:-$DEFAULT_INPUT_BORDER}"
    local input_f="${INPUT_FOCUS:-$DEFAULT_INPUT_FOCUS}"
    local btn_bg="${BUTTON_BG:-$DEFAULT_BUTTON_BG}"
    local btn_c="${BUTTON_COLOR:-$DEFAULT_BUTTON_COLOR}"

    if [[ "$DRY_RUN" == true ]]; then
        info "[dry-run] Будет сгенерирован custom_login.css (фон + цвета)"
        link_custom_css
        return 0
    fi

    local tmpcss
    tmpcss=$(mktemp)

    cat > "$tmpcss" <<EOF
/* ============================================================
 * Custom Roundcube login styles
 * Managed by customize_roundcube.sh — do not edit manually
 * ============================================================ */

/* --- Background image --- */
EOF

    if [[ -n "$bg_ext" ]]; then
        cat >> "$tmpcss" <<EOF
body.task-login {
    background-image: url('../images/login_background.${bg_ext}') !important;
    background-size: cover !important;
    background-position: center center !important;
    background-repeat: no-repeat !important;
}
body.task-login #layout,
body.task-login #layout-content,
body.task-login .layout-content {
    background: transparent !important;
}
EOF
    fi

    cat >> "$tmpcss" <<EOF

/* --- Login form window --- */
body.task-login #login-form {
    background: ${form_bg} !important;
    border-radius: 8px !important;
    padding: 1.5rem !important;
    box-shadow: 0 4px 24px rgba(0,0,0,0.15) !important;
}

/* --- Input fields (login / password) --- */
body.task-login #login-form input.form-control,
body.task-login #login-form input[type="text"],
body.task-login #login-form input[type="password"],
body.task-login #login-form input[type="email"] {
    background-color: ${input_bg} !important;
    color: ${input_c} !important;
    border-color: ${input_b} !important;
    border-radius: 4px !important;
}

body.task-login #login-form input.form-control:focus,
body.task-login #login-form input[type="text"]:focus,
body.task-login #login-form input[type="password"]:focus,
body.task-login #login-form input[type="email"]:focus {
    border-color: ${input_f} !important;
    box-shadow: 0 0 0 0.2rem ${input_f}33 !important;
}

/* --- Submit button --- */
body.task-login #login-form .btn-primary,
body.task-login #login-form #rcmloginsubmit,
body.task-login #login-form input[type="submit"] {
    background-color: ${btn_bg} !important;
    border-color: ${btn_bg} !important;
    color: ${btn_c} !important;
}

body.task-login #login-form .btn-primary:hover,
body.task-login #login-form #rcmloginsubmit:hover {
    filter: brightness(0.92);
}

/* --- Product name (title / footer text) --- */
body.task-login #login-footer,
body.task-login #login-footer a,
body.task-login .product-name {
    color: ${text_c} !important;
}

/* --- Logo spacing adjustment (optional) --- */
body.task-login #logo {
    max-height: 90px;
}
EOF

    # Сохраняем владельца/права, если файл уже существовал
    if [[ -f "$CSS_FILE" ]]; then
        local owner mode
        owner=$(stat -c '%U:%G' "$CSS_FILE" 2>/dev/null || echo "www-data:www-data")
        mode=$(stat -c '%a' "$CSS_FILE" 2>/dev/null || echo "644")
        mv "$tmpcss" "$CSS_FILE"
        chown "$owner" "$CSS_FILE" 2>/dev/null || chown www-data:www-data "$CSS_FILE" 2>/dev/null || true
        chmod "$mode" "$CSS_FILE" 2>/dev/null || chmod 644 "$CSS_FILE"
    else
        mv "$tmpcss" "$CSS_FILE"
        chown www-data:www-data "$CSS_FILE" 2>/dev/null || true
        chmod 644 "$CSS_FILE"
    fi

    link_custom_css
    info "custom_login.css обновлён (фон + цвета)"
}
