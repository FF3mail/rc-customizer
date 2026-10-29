# lib/menu.sh — интерактивное меню

prompt_yes_no() {
    local prompt_msg="$1"
    local default_val="${2:-N}"
    local choice
    if [[ "$default_val" == "Y" ]]; then
        read -rp "$prompt_msg [Y/n]: " choice
        choice="${choice:-Y}"
    else
        read -rp "$prompt_msg [y/N]: " choice
        choice="${choice:-N}"
    fi
    case "$choice" in
        [YyДд]*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

prompt_color() {
    local prompt_msg="$1"
    local default_val="$2"
    local var_name="$3"
    local val
    read -rp "$prompt_msg [$default_val]: " val
    val="${val:-$default_val}"
    # Простая валидация
    if [[ -n "$val" ]]; then
        validate_color "$val" "$prompt_msg"
        printf -v "$var_name" '%s' "$val"
    fi
}

show_customization_menu() {
    echo
    echo "--- Кастомизация ---"

    if prompt_yes_no "Обновить фон страницы входа?" "Y"; then
        read -rp "Путь к фоновому изображению: " bg_file
        if [[ -n "$bg_file" && -f "$bg_file" ]]; then
            apply_background "$bg_file"
        else
            echo "[ОШИБКА] Файл не существует. Пропуск."
        fi
    fi

    if prompt_yes_no "Обновить логотип?" "Y"; then
        read -rp "Путь к файлу логотипа: " logo_file
        if [[ -n "$logo_file" && -f "$logo_file" ]]; then
            apply_logo "$logo_file"
        else
            echo "[ОШИБКА] Файл не существует. Пропуск."
        fi
    fi

    if prompt_yes_no "Обновить название продукта (заголовок/подвал)?" "Y"; then
        read -rp "Введите название продукта: " custom_txt
        if [[ -n "$custom_txt" ]]; then
            apply_text "$custom_txt"
        fi
    fi

    if prompt_yes_no "Настроить цвета (надпись, форма, поля ввода)?" "Y"; then
        echo
        echo "  Можно вводить #RGB, #RRGGBB или rgba(r,g,b,a)"
        echo "  Нажмите Enter, чтобы оставить значение по умолчанию."
        echo
        prompt_color "Цвет надписи (product name / footer)" "$DEFAULT_TEXT_COLOR" TEXT_COLOR
        prompt_color "Фон окна формы входа"               "$DEFAULT_FORM_BG"    FORM_BG
        prompt_color "Фон полей ввода (логин/пароль)"      "$DEFAULT_INPUT_BG"   INPUT_BG
        prompt_color "Цвет текста в полях"                 "$DEFAULT_INPUT_COLOR" INPUT_COLOR
        prompt_color "Цвет рамки полей"                    "$DEFAULT_INPUT_BORDER" INPUT_BORDER
        prompt_color "Цвет рамки при фокусе"               "$DEFAULT_INPUT_FOCUS" INPUT_FOCUS
        prompt_color "Фон кнопки «Войти»"                  "$DEFAULT_BUTTON_BG"  BUTTON_BG
        prompt_color "Цвет текста кнопки"                  "$DEFAULT_BUTTON_COLOR" BUTTON_COLOR

        apply_colors
    fi

    if $MODIFIED_LOGO || $MODIFIED_BG || $MODIFIED_TEXT || $MODIFIED_COLORS; then
        reload_php_fpm
    fi
}

start_interactive_menu() {
    while true; do
        MODIFIED_LOGO=false
        MODIFIED_BG=false
        MODIFIED_TEXT=false
        MODIFIED_COLORS=false
        RESTORED_LEGACY=false
        # Сброс цветов на значения по умолчанию для нового цикла
        TEXT_COLOR=""
        FORM_BG=""
        INPUT_BG=""
        INPUT_COLOR=""
        INPUT_BORDER=""
        INPUT_FOCUS=""
        BUTTON_BG=""
        BUTTON_COLOR=""

        echo
        echo "=========================================="
        echo "   КАСТОМИЗАЦИЯ ROUNDCUBE – ГЛАВНОЕ МЕНЮ "
        echo "=========================================="
        echo "1. Выполнить кастомизацию"
        echo "2. Откат к предыдущей резервной копии / по умолчанию"
        echo "3. Выход"
        echo "------------------------------------------"
        read -rp "Выберите пункт [1-3]: " main_choice
        case "$main_choice" in
            1)
                create_backup >/dev/null
                show_customization_menu
                print_summary
                ;;
            2)
                rollback_to_legacy
                print_summary
                ;;
            3)
                echo "Выход."
                exit 0
                ;;
            *)
                echo "[ОШИБКА] Неверный выбор. Попробуйте снова."
                continue
                ;;
        esac
        if ! prompt_yes_no "Вернуться в главное меню?" "Y"; then
            echo "До свидания!"
            exit 0
        fi
    done
}
