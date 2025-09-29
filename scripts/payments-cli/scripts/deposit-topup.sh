#!/bin/bash

# Скрипт управления вкладами для ЯндексБанка
# Поддерживает бессрочные и срочные вклады с уведомлениями

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/waybar"
DEPOSITS_FILE="$CONFIG_DIR/deposits.json"
CONFIG_FILE="$CONFIG_DIR/deposits.conf"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Инициализация конфигурации
init_config() {
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR"
        log "Создана директория конфигурации: $CONFIG_DIR"
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat >"$CONFIG_FILE" <<EOF
# Конфигурация скрипта управления вкладами
DEPOSITS_FILE="$DEPOSITS_FILE"

# Настройки уведомлений
NOTIFY_DAYS_BEFORE_PROMO_END=7
NOTIFY_DAYS_BEFORE_DEPOSIT_END=30
NOTIFY_DAYS_BEFORE_TOPUP_END=3

# Telegram настройки (опционально)
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Настройки ЯндексБанка
YANDEX_BANK_SAVE_RATE=17.0
YANDEX_BANK_NORMAL_RATE=12.0
YANDEX_BANK_PROMO_END_DATE="2025-10-24"
EOF
        warn "Создан файл конфигурации: $CONFIG_FILE"
    fi

    source "$CONFIG_FILE"
}

# Инициализация файла вкладов
init_deposits_file() {
    if [[ ! -f "$DEPOSITS_FILE" ]]; then
        cat >"$DEPOSITS_FILE" <<EOF
{
  "deposits": [
    {
      "id": "yandex-save-1",
      "name": "Яндекс Сейв (бессрочный)",
      "bank": "Яндекс Банк",
      "type": "savings",
      "amount": 0,
      "interest_rate": $YANDEX_BANK_SAVE_RATE,
      "promo_rate": $YANDEX_BANK_NORMAL_RATE,
      "promo_end_date": "$YANDEX_BANK_PROMO_END_DATE",
      "start_date": "$(date +%Y-%m-%d)",
      "capitalization": "daily",
      "auto_renewal": true,
      "top_up_end_date": "",
      "created_at": "$(date -Iseconds)"
    },
    {
      "id": "yandex-term-1", 
      "name": "Яндекс Срочный (3 мес)",
      "bank": "Яндекс Банк",
      "type": "term",
      "amount": 0,
      "interest_rate": 17.0,
      "start_date": "$(date +%Y-%m-%d)",
      "end_date": "$(date -d "+3 months" +%Y-%m-%d)",
      "term_months": 3,
      "capitalization": "end",
      "auto_renewal": true,
      "top_up_end_date": "$(date -d "+7 days" +%Y-%m-%d)",
      "created_at": "$(date -Iseconds)"
    }
  ]
}
EOF
        log "Создан файл вкладов с шаблонными данными"
    fi
}

# Проверка зависимостей
check_dependencies() {
    local deps=("jq" "date")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            error "Необходима утилита: $dep"
            exit 1
        fi
    done
}

# Расчет дохода по вкладу
calculate_income() {
    local deposit_id=$1
    local days=$2

    local deposit_data=$(jq -r ".deposits[] | select(.id == \"$deposit_id\")" "$DEPOSITS_FILE")
    if [[ -z "$deposit_data" ]]; then
        error "Вклад не найден: $deposit_id"
        return 1
    fi

    local amount=$(echo "$deposit_data" | jq -r '.amount')
    local rate=$(echo "$deposit_data" | jq -r '.interest_rate')
    local capitalization=$(echo "$deposit_data" | jq -r '.capitalization')

    if [[ $amount -eq 0 ]]; then
        echo "0"
        return 0
    fi

    local income=0
    case $capitalization in
    "daily")
        income=$(echo "scale=2; $amount * $rate / 100 / 365 * $days" | bc -l)
        ;;
    "monthly")
        local months=$(echo "scale=2; $days / 30" | bc -l)
        income=$(echo "scale=2; $amount * $rate / 100 / 12 * $months" | bc -l)
        ;;
    "end")
        income=$(echo "scale=2; $amount * $rate / 100 * $days / 365" | bc -l)
        ;;
    *)
        income=$(echo "scale=2; $amount * $rate / 100 * $days / 365" | bc -l)
        ;;
    esac

    echo "$income"
}

# Добавление средств на вклад
deposit_topup() {
    local deposit_id=$1
    local amount=$2
    local description="${3:-Пополнение вклада}"

    if [[ ! -f "$DEPOSITS_FILE" ]]; then
        error "Файл вкладов не найден"
        return 1
    fi

    local deposit_name=$(jq -r ".deposits[] | select(.id == \"$deposit_id\") | .name" "$DEPOSITS_FILE")
    if [[ -z "$deposit_name" ]]; then
        error "Вклад с ID '$deposit_id' не найден"
        return 1
    fi

    if ! [[ "$amount" =~ ^[0-9]+$ ]]; then
        error "Сумма должна быть целым числом"
        return 1
    fi

    log "Пополнение вклада '$deposit_name' на сумму $amount руб."

    # Обновляем сумму в JSON
    local current_amount=$(jq -r ".deposits[] | select(.id == \"$deposit_id\") | .amount" "$DEPOSITS_FILE")
    local new_amount=$((current_amount + amount * 100)) # Храним в копейках

    jq "(.deposits[] | select(.id == \"$deposit_id\") | .amount) = $new_amount" "$DEPOSITS_FILE" >"${DEPOSITS_FILE}.tmp"

    if mv "${DEPOSITS_FILE}.tmp" "$DEPOSITS_FILE"; then
        log "Вклад успешно пополнен. Новая сумма: $((new_amount / 100)) руб."

        # Отправляем уведомление
        send_notification "💰 Пополнение вклада" "Вклад '$deposit_name' пополнен на $amount руб. Текущая сумма: $((new_amount / 100)) руб."
    else
        error "Ошибка при обновлении файла вкладов"
        return 1
    fi
}

# Проверка условий по вкладам
check_deposit_conditions() {
    local today=$(date +%Y-%m-%d)
    local notifications=()

    while IFS= read -r deposit; do
        local id=$(echo "$deposit" | jq -r '.id')
        local name=$(echo "$deposit" | jq -r '.name')
        local type=$(echo "$deposit" | jq -r '.type')
        local promo_end_date=$(echo "$deposit" | jq -r '.promo_end_date // ""')
        local end_date=$(echo "$deposit" | jq -r '.end_date // ""')
        local top_up_end_date=$(echo "$deposit" | jq -r '.top_up_end_date // ""')

        # Проверка окончания промо-периода
        if [[ -n "$promo_end_date" ]]; then
            local days_until_promo=$((($(date -d "$promo_end_date" +%s) - $(date -d "$today" +%s)) / 86400))
            if [[ $days_until_promo -le $NOTIFY_DAYS_BEFORE_PROMO_END ]] && [[ $days_until_promo -ge 0 ]]; then
                notifications+=("🟡 По вкладу '$name' до окончания акционной ставки осталось $days_until_promo дн.")
            fi
        fi

        # Проверка окончания срочного вклада
        if [[ "$type" == "term" && -n "$end_date" ]]; then
            local days_until_end=$((($(date -d "$end_date" +%s) - $(date -d "$today" +%s)) / 86400))
            if [[ $days_until_end -le $NOTIFY_DAYS_BEFORE_DEPOSIT_END ]] && [[ $days_until_end -ge 0 ]]; then
                notifications+=("🔴 Срочный вклад '$name' заканчивается через $days_until_end дн.")
            fi
        fi

        # Проверка окончания периода пополнения
        if [[ -n "$top_up_end_date" ]]; then
            local days_until_topup=$((($(date -d "$top_up_end_date" +%s) - $(date -d "$today" +%s)) / 86400))
            if [[ $days_until_topup -le $NOTIFY_DAYS_BEFORE_TOPUP_END ]] && [[ $days_until_topup -ge 0 ]]; then
                notifications+=("🔵 По вкладу '$name' период пополнения заканчивается через $days_until_topup дн.")
            fi
        fi

    done < <(jq -c '.deposits[]' "$DEPOSITS_FILE")

    # Вывод уведомлений
    if [[ ${#notifications[@]} -gt 0 ]]; then
        echo "Уведомления по вкладам:"
        echo "======================"
        for notification in "${notifications[@]}"; do
            echo "• $notification"
        done
        echo ""
    fi
}

# Отправка уведомления
send_notification() {
    local title=$1
    local message=$2

    # Локальное уведомление
    if command -v notify-send &>/dev/null; then
        notify-send "$title" "$message"
    fi

    # Вывод в консоль
    info "$title: $message"
}

# Просмотр списка вкладов
list_deposits() {
    if [[ ! -f "$DEPOSITS_FILE" ]]; then
        error "Файл вкладов не найден"
        return 1
    fi

    local total_count=$(jq '.deposits | length' "$DEPOSITS_FILE")
    if [[ $total_count -eq 0 ]]; then
        info "Нет активных вкладов"
        return 0
    fi

    echo "Активные вклады:"
    echo "================"

    jq -r '.deposits[] | "\(.name) | \(.bank) | \(.amount / 100 | tonumber) руб. | \(.interest_rate)% | \(.type) | Создан: \(.start_date)"' "$DEPOSITS_FILE" | while read -r line; do
        echo "  • $line"
    done

    local total_amount=$(jq '[.deposits[].amount] | add / 100' "$DEPOSITS_FILE")
    echo ""
    echo "Общая сумма вкладов: $total_amount руб."
}

# Обновление дат по вкладам
update_deposit_dates() {
    local deposit_id=$1

    if [[ ! -f "$DEPOSITS_FILE" ]]; then
        error "Файл вкладов не найден"
        return 1
    fi

    local deposit_data=$(jq -r ".deposits[] | select(.id == \"$deposit_id\")" "$DEPOSITS_FILE")
    if [[ -z "$deposit_data" ]]; then
        error "Вклад не найден: $deposit_id"
        return 1
    fi

    local type=$(echo "$deposit_data" | jq -r '.type')
    local term_months=$(echo "$deposit_data" | jq -r '.term_months // 0')

    if [[ "$type" == "term" && $term_months -gt 0 ]]; then
        local new_end_date=$(date -d "+$term_months months" +%Y-%m-%d)
        local new_top_up_end_date=$(date -d "+7 days" +%Y-%m-%d)

        jq "(.deposits[] | select(.id == \"$deposit_id\") | .end_date) = \"$new_end_date\" | (.deposits[] | select(.id == \"$deposit_id\") | .top_up_end_date) = \"$new_top_up_end_date\"" "$DEPOSITS_FILE" >"${DEPOSITS_FILE}.tmp"

        if mv "${DEPOSITS_FILE}.tmp" "$DEPOSITS_FILE"; then
            log "Даты вклада обновлены. Новый срок до: $new_end_date"
        else
            error "Ошибка при обновлении дат вклада"
        fi
    fi
}

# Основная функция
main() {
    check_dependencies
    init_config
    init_deposits_file

    case "${1:-}" in
    "list")
        list_deposits
        ;;
    "topup")
        if [[ $# -lt 3 ]]; then
            error "Использование: $0 topup <deposit_id> <amount> [description]"
            exit 1
        fi
        deposit_topup "$2" "$3" "${4:-}"
        ;;
    "check")
        check_deposit_conditions
        ;;
    "update")
        if [[ $# -lt 2 ]]; then
            error "Использование: $0 update <deposit_id>"
            exit 1
        fi
        update_deposit_dates "$2"
        ;;
    "calculate")
        if [[ $# -lt 3 ]]; then
            error "Использование: $0 calculate <deposit_id> <days>"
            exit 1
        fi
        calculate_income "$2" "$3"
        ;;
    "help" | "-h" | "--help")
        echo "Использование: $0 {list|topup|check|update|calculate}"
        echo ""
        echo "Команды:"
        echo "  list                           - Показать список вкладов"
        echo "  topup <id> <amount> [desc]     - Пополнить вклад"
        echo "  check                          - Проверить условия по вкладам"
        echo "  update <id>                    - Обновить даты вклада (пролонгация)"
        echo "  calculate <id> <days>          - Рассчитать доход за указанное количество дней"
        echo ""
        echo "Примеры:"
        echo "  $0 list"
        echo "  $0 topup yandex-save-1 5000"
        echo "  $0 check"
        echo "  $0 update yandex-term-1"
        echo "  $0 calculate yandex-save-1 30"
        ;;
    *)
        if [[ -z "$1" ]]; then
            list_deposits
            echo ""
            check_deposit_conditions
        else
            error "Неизвестная команда: $1"
            echo "Используйте '$0 help' для справки"
            exit 1
        fi
        ;;
    esac
}

main "$@"
