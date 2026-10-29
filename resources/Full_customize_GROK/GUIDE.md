# Full_customize_GROK — руководство

Кастомизация страницы входа Roundcube (скин Elastic) в iRedMail на Ubuntu 24.04+.

Русский интерфейс. Модульная структура. Установка только из `/tmp`.

---

## 1. Состав дистрибутива

```
Full_customize_GROK/
├── install.sh                 # установка
├── uninstall.sh               # удаление
├── customize_roundcube.sh     # основная программа
├── GUIDE.md                   # это руководство
└── lib/
    ├── common.sh              # константы, проверки, хелперы
    ├── backup.sh              # резервные копии и откат
    ├── config.sh              # PHP-конфиги Roundcube
    ├── css.sh                 # генерация custom_login.css
    ├── apply.sh               # логотип, фон, текст, цвета
    └── menu.sh                # интерактивное меню
```

---

## 2. Установка

### 2.1. Подготовка

1. Скопируйте **целиком** папку `Full_customize_GROK` (с подпапкой `lib`) на сервер в `/tmp`:

```bash
# пример: с локальной машины
scp -r Full_customize_GROK root@ВАШ_СЕРВЕР:/tmp/
```

На сервере должно получиться:

```
/tmp/Full_customize_GROK/
/tmp/Full_customize_GROK/lib/
/tmp/Full_customize_GROK/install.sh
...
```

### 2.2. Запуск установщика

```bash
sudo /tmp/Full_customize_GROK/install.sh
```

Установщик:

- проверяет, что запущен **только** из `/tmp/Full_customize_GROK`;
- копирует программу в `/usr/local/src/Full_customize_GROK`;
- создаёт команду `customize_roundcube` → `/usr/local/bin/customize_roundcube`.

### 2.3. Проверка

```bash
sudo customize_roundcube --test
```

---

## 3. Использование

### 3.1. Интерактивный режим (рекомендуется)

```bash
sudo customize_roundcube -i
```

Меню:

1. **Выполнить кастомизацию** — фон, логотип, название, цвета  
2. **Откат** — восстановить предыдущую резервную копию / очистить кастомизации  
3. **Выход**

### 3.2. Режим командной строки

```bash
# Логотип + фон + название
sudo customize_roundcube \
  --logo /path/to/logo.png \
  --background /path/to/bg.jpg \
  --text "Моя Почта"

# Только цвета (тёмная форма)
sudo customize_roundcube \
  --text-color "#ffffff" \
  --form-bg "rgba(20,20,30,0.85)" \
  --input-bg "#1e1e2e" \
  --input-color "#e0e0e0" \
  --input-border "#444455" \
  --input-focus "#37beff" \
  --button-bg "#37beff" \
  --button-color "#ffffff"

# Проверка без изменений
sudo customize_roundcube --dry-run --logo /tmp/logo.png

# Справка
sudo customize_roundcube --help
```

### 3.3. Параметры

| Параметр | Описание | Формат / допустимое |
|----------|----------|---------------------|
| `-l, --logo PATH` | Логотип | PNG, JPG, JPEG, SVG, WEBP |
| `-b, --background PATH` | Фон страницы входа | PNG, JPG, JPEG, WEBP |
| `-t, --text TEXT` | Название продукта (заголовок и подвал) | любой текст |
| `--text-color COLOR` | Цвет надписи (footer / product name) | `#RGB`, `#RRGGBB`, `rgba(...)` |
| `--form-bg COLOR` | Фон окна формы | то же |
| `--input-bg COLOR` | Фон полей логин/пароль | то же |
| `--input-color COLOR` | Цвет текста в полях | то же |
| `--input-border COLOR` | Цвет рамки полей | то же |
| `--input-focus COLOR` | Цвет рамки при фокусе | то же |
| `--button-bg COLOR` | Фон кнопки «Войти» | то же |
| `--button-color COLOR` | Цвет текста кнопки | то же |
| `-i, --interactive` | Интерактивное меню | — |
| `--test` | Только проверка окружения | — |
| `--dry-run` | Показать действия без изменений | — |
| `-h, --help` | Справка | — |

**Цвета по умолчанию:**

| Параметр | Значение |
|----------|----------|
| text-color | `#ffffff` |
| form-bg | `rgba(255,255,255,0.92)` |
| input-bg | `#ffffff` |
| input-color | `#212529` |
| input-border | `#ced4da` |
| input-focus | `#37beff` |
| button-bg | `#37beff` |
| button-color | `#ffffff` |

---

## 4. Что меняется в системе

| Компонент | Путь |
|-----------|------|
| Логотип | `/opt/www/roundcubemail/skins/elastic/images/custom_logo.*` |
| Фон | `/opt/www/roundcubemail/skins/elastic/images/login_background.*` |
| CSS | `/opt/www/roundcubemail/skins/elastic/styles/custom_login.css` |
| Подключение CSS | правка `.../templates/includes/layout.html` (маркер) |
| Настройки | `/opt/iredmail/custom/roundcube/custom.inc.php` |
| Include в основной конфиг | `/opt/www/roundcubemail/config/config.inc.php` |
| Резервные копии | `/root/roundcube_custom_backup_ГГГГММДД_ЧЧММСС` |

Перед каждым изменением создаётся резервная копия скина и конфига.

---

## 5. Откат изменений

### Через программу

```bash
sudo customize_roundcube -i
# пункт 2 — Откат
```

или (если установлен):

```bash
# в интерактивном меню
```

### Через uninstall (с откатом кастомизаций)

См. раздел 6.

---

## 6. Удаление

1. Снова скопируйте папку `Full_customize_GROK` в `/tmp` (если её там уже нет).

2. Запустите:

```bash
sudo /tmp/Full_customize_GROK/uninstall.sh
```

Скрипт спросит:

- откатить ли кастомизации Roundcube (логотип, фон, цвета, название);
- удалить ли резервные копии в `/root/roundcube_custom_backup_*`.

Удаляются:

- `/usr/local/src/Full_customize_GROK`
- `/usr/local/bin/customize_roundcube`

---

## 7. Требования

- Ubuntu 24.04+ (или совместимый), iRedMail с Roundcube
- Скин **elastic**
- Пути по умолчанию:
  - Roundcube: `/opt/www/roundcubemail`
  - Custom: `/opt/iredmail/custom/roundcube`
- Права **root**
- PHP-FPM (для очистки OPcache после изменений)

---

## 8. Безопасность

- SVG-логотипы проверяются на `<script>`, обработчики событий, внешние ссылки
- Запись файлов — атомарная (`mktemp` + `mv`)
- `rm -rf` защищён проверкой путей
- PHP-конфиг проверяется через `php -l` перед установкой
- Установка/удаление разрешены **только** из `/tmp/Full_customize_GROK`

---

## 9. Типичные проблемы

| Симптом | Что проверить |
|---------|----------------|
| «Установка разрешена только из /tmp/...» | Каталог должен называться точно `Full_customize_GROK` и лежать в `/tmp` |
| Изменения не видны | `sudo customize_roundcube` перезагружает PHP-FPM; обновите страницу с Ctrl+F5 |
| Нет PHP-FPM | Предупреждение при `--test`; изменения всё равно применятся, кэш может устареть |
| Ошибка MIME / symlink | Файлы изображений не должны быть символическими ссылками |

---

## 10. Краткая шпаргалка

```bash
# Установка
scp -r Full_customize_GROK root@server:/tmp/
ssh root@server
sudo /tmp/Full_customize_GROK/install.sh
sudo customize_roundcube --test
sudo customize_roundcube -i

# Удаление
# (снова положить Full_customize_GROK в /tmp)
sudo /tmp/Full_customize_GROK/uninstall.sh
```
