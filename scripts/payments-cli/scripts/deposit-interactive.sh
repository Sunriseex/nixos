#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/waybar"
DEPOSITS_FILE="$CONFIG_DIR/deposits.json"
LEDGER_PATH="$HOME/ObsidianVault/finances/transactions.ledger"

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

check_ledger_file() {
    if [[ ! -f "$LEDGER_PATH" ]]; then
        warn "Файл ledger не найден: $LEDGER_PATH"
        return 1
    fi
    return 0
}

record_to_ledger() {
    local date="$1"
    local description="$2"
    local amount="$3"
    local from_account="$4"
    local to_account="$5"

    if ! check_ledger_file; then
        return 1
    fi

    local amount_formatted="₽${amount}"

    local ledger_entry="$date $description\n"
    ledger_entry+="    $to_account    $amount_formatted\n"
    ledger_entry+="    $from_account    -$amount_formatted\n"

    echo -e "\n$ledger_entry" >>"$LEDGER_PATH"

    log "Операция записана в ledger: $LEDGER_PATH"
    return 0
}

record_deposit_creation() {
    local name="$1"
    local amount="$2"
    local from_account="$3"
    local to_account="$4"
    local date=$(date +%Y-%m-%d)
    local description="Открытие вклада: $name"

    record_to_ledger "$date" "$description" "$amount" "$from_account" "$to_account"
}

record_deposit_topup() {
    local name="$1"
    local amount="$2"
    local from_account="$3"
    local to_account="$4"
    local date=$(date +%Y-%m-%d)
    local description="Пополнение вклада: $name"

    record_to_ledger "$date" "$description" "$amount" "$from_account" "$to_account"
}

record_interest() {
    local name="$1"
    local amount="$2"
    local days="$3"
    local to_account="$4"
    local date=$(date +%Y-%m-%d)
    local description="Начисление процентов за $days дней: $name"

    record_to_ledger "$date" "$description" "$amount" "Income:Interest" "$to_account"
}
get_default_account() {
    local bank="$1"
    local account_type="$2"

    local bank_safe=$(echo "$bank" | tr ' ' '_' | tr -cd '[:alnum:]_')

    if [[ "$account_type" == "from" ]]; then
        echo "Assets:Banking:${bank_safe}"
    else
        echo "Assets:Banking:${bank_safe}:Savings"
    fi
}

select_accounts() {
    local bank="$1"
    local default_from=$(get_default_account "$bank" "from")
    local default_to=$(get_default_account "$bank" "to")

    echo ""
    echo "Выбор счетов для операции:"
    echo "Счет списания (откуда):"
    read -p "  [по умолчанию: $default_from]: " from_account
    echo "Счет зачисления (куда):"
    read -p "  [по умолчанию: $default_to]: " to_account

    from_account=${from_account:-$default_from}
    to_account=${to_account:-$default_to}
}

calculate_earned_interest() {
    local deposit_name="$1"
    local bank="$2"

    echo "0.00"
}

calculate_income_interactive() {
    echo "=========================================="
    echo "Расчет дохода по вкладу"
    echo "=========================================="

    local deposits_list
    deposits_list=$(deposit-manager list 2>/dev/null)

    if [[ -z "$deposits_list" ]]; then
        error "Нет доступных вкладов для расчета"
        return 1
    fi

    echo "Ваши вклады:"
    echo "$deposits_list"
    echo ""

    local deposits=()
    local i=1

    while IFS= read -r line; do
        if [[ $line =~ [0-9]+\.\ ([^\(]+)\ \(([^\)]+)\) ]]; then
            deposit_name="${BASH_REMATCH[1]}"
            bank_name="${BASH_REMATCH[2]}"
            deposits[i]="$deposit_name|$bank_name"
            echo "  $i) $deposit_name ($bank_name)"
            ((i++))
        fi
    done <<<"$deposits_list"

    if [[ ${#deposits[@]} -eq 0 ]]; then
        error "Не удалось распознать список вкладов"
        return 1
    fi

    while true; do
        read -p "Выберите вклад [1-$((i - 1))]: " choice
        if [[ $choice =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le $((i - 1)) ]]; then
            selected="${deposits[$choice]}"
            deposit_name=$(echo "$selected" | cut -d'|' -f1)
            bank_name=$(echo "$selected" | cut -d'|' -f2)
            break
        else
            error "Введите число от 1 до $((i - 1))"
        fi
    done

    log "Поиск вклада '$deposit_name' в банке '$bank_name'..."
    deposit_id=$(jq -r --arg name "$deposit_name" --arg bank "$bank_name" '.deposits[] | select(.name == $name and .bank == $bank) | .id' "$DEPOSITS_FILE" 2>/dev/null)

    if [[ -z "$deposit_id" || "$deposit_id" == "null" ]]; then
        error "Не удалось найти ID вклада '$deposit_name' в банке '$bank_name'"
        return 1
    fi

    while true; do
        read -p "Введите количество дней для расчета: " days
        if [[ $days =~ ^[0-9]+$ ]] && [[ $days -gt 0 ]]; then
            break
        else
            error "Введите положительное целое число"
        fi
    done

    log "Расчет дохода по вкладу '$deposit_name'..."
    deposit-manager calculate "$deposit_id" "$days"

    return $?
}

find_deposit_id() {
    local name="$1"
    local bank="$2"

    if [[ -z "$name" || -z "$bank" ]]; then
        error "Использование: $0 find <name> <bank>"
        return 1
    fi

    echo "Поиск ID вклада: $name в банке $bank"
    local deposit_id=$(get_deposit_id "$name" "$bank")

    if [[ -n "$deposit_id" ]]; then
        echo "Найден ID: $deposit_id"
        return 0
    else
        error "Вклад не найден"
        return 1
    fi
}

check_deposit_exists() {
    local name="$1"
    local bank="$2"

    if [[ -f "$DEPOSITS_FILE" ]]; then
        if jq -e --arg name "$name" --arg bank "$bank" '.deposits[] | select(.name == $name and .bank == $bank)' "$DEPOSITS_FILE" >/dev/null 2>&1; then
            return 0
        fi
    fi

    if deposit-manager list 2>/dev/null | grep -q "Name: $name.*Bank: $bank"; then
        return 0
    fi

    return 1
}

get_deposit_id() {
    local name="$1"
    local bank="$2"

    if [[ -f "$DEPOSITS_FILE" ]]; then
        local existing_id=$(jq -r --arg name "$name" --arg bank "$bank" '.deposits[] | select(.name == $name and .bank == $bank) | .id' "$DEPOSITS_FILE" 2>/dev/null)

        if [[ -n "$existing_id" && "$existing_id" != "null" ]]; then
            echo "$existing_id"
            return 0
        fi
    fi

    warn "Вклад не найден, создается новый ID"
    echo "$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')-$(date +%s)"
}

create_new_deposit() {
    local name="$1"
    local bank="$2"
    local deposit_type="$3"
    local amount="$4"
    local rate="$5"
    local term="$6"
    local promo_rate_value="$7"
    local promo_end_date="$8"

    log "Создание нового вклада: $name"

    select_accounts "$bank"

    local command="deposit-manager create --name \"$name\" --bank \"$bank\" --type \"$deposit_type\" --amount \"$amount\" --rate \"$rate\""

    if [[ "$deposit_type" == "term" && -n "$term" ]]; then
        command="$command --term \"$term\""
    fi

    if [[ -n "$promo_rate_value" ]]; then
        command="$command --promo-rate \"$promo_rate_value\""
    fi

    if [[ -n "$promo_end_date" ]]; then
        command="$command --promo-end \"$promo_end_date\""
    fi

    echo "Выполняется команда: $command"
    eval "$command"

    local result=$?

    if [[ $result -eq 0 ]]; then
        record_deposit_creation "$name" "$amount" "$from_account" "$to_account"
    fi

    return $result
}

topup_existing_deposit() {
    local name="$1"
    local bank="$2"
    local amount="$3"

    log "Пополнение существующего вклада: $name"

    local deposit_id
    deposit_id=$(get_deposit_id "$name" "$bank")
    if [[ $? -ne 0 || -z "$deposit_id" ]]; then
        error "Не удалось найти ID вклада '$name' в банке '$bank'"
        show_existing_deposits
        return 1
    fi

    select_accounts "$bank"

    log "Используется ID вклада: $deposit_id"

    deposit-manager topup "$deposit_id" "$amount" "Пополнение через интерактивный скрипт"

    local result=$?

    if [[ $result -eq 0 ]]; then
        record_deposit_topup "$name" "$amount" "$from_account" "$to_account"
    else
        error "Ошибка при пополнении вклада"
        echo "Попробуйте выполнить команду вручную:"
        echo "deposit-manager topup \"$deposit_id\" \"$amount\""
    fi

    return $result
}

add_or_update_deposit() {
    echo "=========================================="
    echo "Добавление/обновление вклада"
    echo "=========================================="

    local promo_rate_value=""
    local promo_end_date=""
    local capitalization=""
    local auto_renewal_flag=""

    show_existing_deposits
    echo ""

    while true; do
        read -p "Введите название вклада: " name
        if [[ -n "$name" ]]; then
            break
        else
            error "Название не может быть пустым"
        fi
    done

    while true; do
        read -p "Введите название банка: " bank
        if [[ -n "$bank" ]]; then
            break
        else
            error "Название банка не может быть пустым"
        fi
    done

    local deposit_exists=false
    if check_deposit_exists "$name" "$bank"; then
        deposit_exists=true
        info "Вклад '$name' в банке '$bank' уже существует"

        local existing_id=$(get_deposit_id "$name" "$bank")
        info "ID вклада: $existing_id"

        echo ""
        echo "Выберите действие:"
        echo "1) Пополнить существующий вклад"
        echo "2) Создать новый вклад (с другим ID)"

        while true; do
            read -p "Ваш выбор [1 или 2]: " choice
            case $choice in
            1)
                while true; do
                    read -p "Введите сумму для пополнения: " amount
                    if [[ $amount =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] && [[ $(echo "$amount > 0" | bc -l) -eq 1 ]]; then
                        break
                    else
                        error "Некорректная сумма. Пример: 50000 или 1500.50"
                    fi
                done

                topup_existing_deposit "$name" "$bank" "$amount"
                return $?
                ;;
            2)
                deposit_exists=false
                break
                ;;
            *)
                error "Введите 1 или 2"
                ;;
            esac
        done
    fi

    if [[ "$deposit_exists" == false ]]; then
        echo ""
        echo "Типы вкладов:"
        echo "1) savings - Бессрочный (с возможностью пополнения)"
        echo "2) term - Срочный (фиксированный срок)"

        while true; do
            read -p "Выберите тип вклада [1 или 2]: " type_choice
            case $type_choice in
            1)
                deposit_type="savings"
                break
                ;;
            2)
                deposit_type="term"
                break
                ;;
            *)
                error "Введите 1 или 2"
                ;;
            esac
        done

        while true; do
            read -p "Введите сумму вклада в рублях: " amount
            if [[ $amount =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] && [[ $(echo "$amount > 0" | bc -l) -eq 1 ]]; then
                break
            else
                error "Некорректная сумма. Пример: 50000 или 1500.50"
            fi
        done

        while true; do
            read -p "Введите процентную ставку (например: 17.5): " rate
            if [[ $rate =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] && [[ $(echo "$rate > 0" | bc -l) -eq 1 ]]; then
                break
            else
                error "Некорректная ставка. Пример: 17.5 или 8.25"
            fi
        done

        local term=""
        if [[ "$deposit_type" == "term" ]]; then
            while true; do
                read -p "Введите срок вклада в месяцах: " term
                if [[ $term =~ ^[0-9]+$ ]] && [[ $term -gt 0 ]]; then
                    break
                else
                    error "Введите положительное целое число"
                fi
            done
        fi

        echo ""
        echo "Дополнительные опции:"
        echo "1) Стандартные настройки"
        echo "2) Настроить дополнительные параметры"

        read -p "Ваш выбор [1 или 2]: " advanced_choice
        if [[ "$advanced_choice" == "2" ]]; then
            echo ""
            echo "Тип капитализации:"
            echo "1) daily - Ежедневная"
            echo "2) monthly - Ежемесячная"
            echo "3) end - В конце срока"

            read -p "Выберите тип капитализации [1-3]: " cap_choice
            case $cap_choice in
            1) capitalization="daily" ;;
            2) capitalization="monthly" ;;
            3) capitalization="end" ;;
            *) capitalization="daily" ;;
            esac

            read -p "Включить автопролонгацию? [y/N]: " auto_renewal
            if [[ $auto_renewal =~ ^[Yy]$ ]]; then
                auto_renewal_flag="--auto-renewal"
            else
                auto_renewal_flag=""
            fi

            read -p "Есть ли промо-ставка? [y/N]: " has_promo_rate
            if [[ $has_promo_rate =~ ^[Yy]$ ]]; then
                while true; do
                    read -p "Введите промо-ставку: " promo_rate_value
                    if [[ $promo_rate_value =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] && [[ $(echo "$promo_rate_value > 0" | bc -l) -eq 1 ]]; then
                        break
                    else
                        error "Некорректная промо-ставка. Пример: 17.5 или 8.25"
                    fi
                done

                while true; do
                    read -p "Введите дату окончания промо-ставки (ГГГГ-ММ-ДД): " promo_end_date
                    if date -d "$promo_end_date" >/dev/null 2>&1; then
                        break
                    else
                        error "Некорректная дата. Используйте формат ГГГГ-ММ-ДД"
                    fi
                done
            fi
        fi

        echo ""
        echo "=========================================="
        echo "Проверьте введенные данные:"
        echo "=========================================="
        echo "Название: $name"
        echo "Банк: $bank"
        echo "Тип: $deposit_type"
        echo "Сумма: $amount руб."
        echo "Ставка: $rate%"
        if [[ "$deposit_type" == "term" ]]; then
            echo "Срок: $term месяцев"
        fi
        if [[ -n "$promo_rate_value" ]]; then
            echo "Промо-ставка: $promo_rate_value% (до $promo_end_date)"
        fi
        if [[ -n "$capitalization" ]]; then
            echo "Капитализация: $capitalization"
        fi
        if [[ -n "$auto_renewal_flag" ]]; then
            echo "Автопролонгация: включена"
        fi
        echo "=========================================="

        while true; do
            read -p "Создать вклад? [y/N]: " confirm
            case $confirm in
            [Yy]*)
                create_new_deposit "$name" "$bank" "$deposit_type" "$amount" "$rate" "$term" "$promo_rate_value" "$promo_end_date"
                break
                ;;
            [Nn]*)
                echo "Отмена создания вклада"
                exit 0
                ;;
            *)
                echo "Отмена создания вклада"
                exit 0
                ;;
            esac
        done
    fi
}

update_deposit_rate_interactive() {
    echo "=========================================="
    echo "Обновление ставки по вкладу"
    echo "=========================================="

    echo "Список ваших вкладов:"
    local deposits_list
    deposits_list=$(deposit-manager list 2>/dev/null)

    if [[ -z "$deposits_list" ]]; then
        error "Нет доступных вкладов для обновления"
        return 1
    fi

    echo "$deposits_list"
    echo ""

    while true; do
        read -p "Введите название вклада: " name
        if [[ -n "$name" ]]; then
            break
        else
            error "Название не может быть пустым"
        fi
    done

    while true; do
        read -p "Введите банк: " bank
        if [[ -n "$bank" ]]; then
            break
        else
            error "Банк не может быть пустым"
        fi
    done

    log "Поиск вклада '$name' в банке '$bank'..."
    deposit_info=$(deposit-manager find "$name" "$bank" 2>/dev/null)

    if ! echo "$deposits_list" | grep -q "$name.*$bank"; then
        error "Вклад '$name' в банке '$bank' не найден"
        return 1
    fi

    local deposit_json
    deposit_json=$(jq -r --arg name "$name" --arg bank "$bank" '.deposits[] | select(.name == $name and .bank == $bank)' "$DEPOSITS_FILE" 2>/dev/null)

    if [[ -z "$deposit_json" || "$deposit_json" == "null" ]]; then
        error "Не удалось получить данные вклада"
        return 1
    fi

    local current_rate
    current_rate=$(echo "$deposit_json" | jq -r '.interest_rate')
    local current_promo_rate
    current_promo_rate=$(echo "$deposit_json" | jq -r '.promo_rate // "нет"')
    local current_promo_end_date
    current_promo_end_date=$(echo "$deposit_json" | jq -r '.promo_end_date // "нет"')

    echo ""
    echo "Текущие данные вклада:"
    echo "  Основная ставка: $current_rate%"
    echo "  Промо-ставка: $current_promo_rate"
    if [[ "$current_promo_end_date" != "нет" ]]; then
        echo "  Дата окончания промо: $current_promo_end_date"
    fi
    echo ""

    while true; do
        read -p "Введите новую основную ставку (текущая: $current_rate%): " new_rate
        if [[ -z "$new_rate" ]]; then
            new_rate="$current_rate"
            break
        elif [[ $new_rate =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] && (($(echo "$new_rate > 0" | bc -l))); then
            break
        else
            error "Некорректная ставка. Пример: 5.5 или 10"
        fi
    done

    echo ""
    echo "Обновление промо-ставки:"
    echo "1) Оставить текущую промо-ставку"
    echo "2) Изменить промо-ставку"
    echo "3) Удалить промо-ставку"

    local promo_choice
    while true; do
        read -p "Ваш выбор [1-3]: " promo_choice
        case $promo_choice in
        1)
            new_promo_rate="$current_promo_rate"
            new_promo_end_date="$current_promo_end_date"
            break
            ;;
        2)
            while true; do
                read -p "Введите новую промо-ставку: " new_promo_rate
                if [[ $new_promo_rate =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] && (($(echo "$new_promo_rate > 0" | bc -l))); then
                    break
                else
                    error "Некорректная промо-ставка. Пример: 5.5 или 10"
                fi
            done

            while true; do
                read -p "Введите дату окончания промо-ставки (ГГГГ-ММ-ДД): " new_promo_end_date
                if date -d "$new_promo_end_date" >/dev/null 2>&1; then
                    break
                else
                    error "Некорректная дата. Используйте формат ГГГГ-ММ-ДД"
                fi
            done
            break
            ;;
        3)
            new_promo_rate="null"
            new_promo_end_date="null"
            break
            ;;
        *)
            error "Введите 1, 2 или 3"
            ;;
        esac
    done

    echo ""
    echo "Подтвердите изменения:"
    echo "  Новая основная ставка: $new_rate%"
    if [[ "$new_promo_rate" != "null" ]]; then
        echo "  Новая промо-ставка: $new_promo_rate%"
        echo "  Дата окончания промо: $new_promo_end_date"
    else
        echo "  Промо-ставка: будет удалена"
    fi
    echo ""

    while true; do
        read -p "Подтвердить обновление? [y/N]: " confirm
        case $confirm in
        [Yy]*)
            break
            ;;
        [Nn]*)
            echo "Отмена обновления"
            return 0
            ;;
        *)
            echo "Отмена обновления"
            return 0
            ;;
        esac
    done

    log "Обновление ставки вклада '$name'..."

    local temp_file
    temp_file=$(mktemp)

    if [[ "$new_promo_rate" == "null" ]]; then
        jq --arg name "$name" \
            --arg bank "$bank" \
            --arg new_rate "$new_rate" \
            '(.deposits[] | select(.name == $name and .bank == $bank)) |= 
            (.interest_rate = ($new_rate | tonumber) | del(.promo_rate) | del(.promo_end_date))' \
            "$DEPOSITS_FILE" >"$temp_file"
    else
        jq --arg name "$name" \
            --arg bank "$bank" \
            --arg new_rate "$new_rate" \
            --arg new_promo_rate "$new_promo_rate" \
            --arg new_promo_end_date "$new_promo_end_date" \
            '(.deposits[] | select(.name == $name and .bank == $bank)) |= 
            (.interest_rate = ($new_rate | tonumber) | .promo_rate = ($new_promo_rate | tonumber) | .promo_end_date = $new_promo_end_date)' \
            "$DEPOSITS_FILE" >"$temp_file"
    fi

    if [[ $? -eq 0 ]]; then
        mv "$temp_file" "$DEPOSITS_FILE"
        log "Ставка по вкладу '$name' успешно обновлена"
        echo "✅ Ставка по вкладу успешно обновлена"
    else
        error "Ошибка при обновлении ставки"
        rm -f "$temp_file"
        return 1
    fi
}
accrue_interest_auto() {
    echo "=========================================="
    echo "Автоматическое начисление процентов"
    echo "=========================================="

    log "Запуск автоматического начисления процентов..."

    deposit-manager accrue-interest

    local result=$?

    if [[ $result -eq 0 ]]; then
        log "Автоматическое начисление процентов завершено"
    else
        error "Ошибка при автоматическом начислении процентов"
    fi

    return $result
}

main_menu() {
    echo "=========================================="
    echo "Управление вкладами - deposit-manager"
    echo "=========================================="
    echo ""
    echo "Выберите действие:"
    echo "1) Добавить новый вклад или пополнить существующий"
    echo "2) Просмотреть список вкладов"
    echo "3) Проверить уведомления"
    echo "4) Рассчитать доход"
    echo "5) Обновить ставку по вкладу"
    echo "6) Выход"
    echo ""
}

show_existing_deposits() {
    echo "=========================================="
    echo "Существующие вклады:"
    echo "=========================================="

    if [[ -f "$DEPOSITS_FILE" ]]; then
        jq -r '.deposits[] | "\(.id) | \(.name) | \(.bank) | \(.amount / 100) руб."' "$DEPOSITS_FILE" 2>/dev/null ||
            echo "Ошибка чтения файла вкладов"
    else
        echo "Файл вкладов не найден: $DEPOSITS_FILE"
    fi
}

check_dependencies() {
    if ! command -v deposit-manager &>/dev/null; then
        error "deposit-manager не найден. Убедитесь, что он установлен и доступен в PATH"
        exit 1
    fi

    if ! command -v bc &>/dev/null; then
        error "Утилита bc не найдена. Установите её: sudo apt-get install bc"
        exit 1
    fi
}

main() {
    check_dependencies

    while true; do
        main_menu
        read -p "Ваш выбор [1-9]: " choice

        case $choice in
        1)
            add_or_update_deposit
            ;;
        2)
            echo ""
            deposit-manager list
            ;;
        3)
            echo ""
            deposit-manager notifications
            ;;
        4)
            calculate_income_interactive
            ;;
        5)
            update_deposit_rate_interactive
            ;;
        6)
            echo "Выход..."
            exit 0
            ;;
        *)
            error "Неверный выбор"
            ;;
        esac

        echo ""
        read -p "Нажмите Enter для продолжения..."
    done
}

case "${1:-}" in
"add" | "create")
    add_or_update_deposit
    ;;
"list")
    deposit-manager list
    ;;
"list-ids")
    show_existing_deposits
    ;;
"find")
    if [[ $# -ge 3 ]]; then
        find_deposit_id "$2" "$3"
    else
        error "Использование: $0 find <name> <bank>"
        exit 1
    fi
    ;;
"notifications")
    deposit-manager notifications
    ;;
"topup")
    if [[ $# -ge 3 ]]; then
        deposit-manager topup "$2" "$3"
    else
        error "Использование: $0 topup <deposit_id> <amount>"
        exit 1
    fi
    ;;
"calculate")
    if [[ $# -ge 3 ]]; then
        deposit-manager calculate "$2" "$3"
    else
        calculate_income_interactive
    fi
    ;;
"accrue-interest")
    accrue_interest_auto
    ;;
"update-rate")
    update_deposit_rate_interactive
    ;;
"ledger-path")
    echo "Файл ledger: $LEDGER_PATH"
    if [[ -f "$LEDGER_PATH" ]]; then
        echo "Последние записи:"
        tail -10 "$LEDGER_PATH"
    else
        echo "Файл не существует"
    fi
    ;;
"help" | "-h" | "--help")
    echo "Использование: $0 [command]"
    echo ""
    echo "Команды:"
    echo "  add, create    - Интерактивное добавление/обновление вклада"
    echo "  list           - Показать список вкладов"
    echo "  notifications  - Проверить уведомления"
    echo "  topup <id> <amount> - Пополнить вклад"
    echo "  calculate      - Рассчитать доход (интерактивно)"
    echo "  calculate <id> <days> - Рассчитать доход по ID"
    echo "  update-rate    - Обновить ставку по вкладу"
    echo "  ledger-path    - Показать путь и последние записи ledger"
    echo "  help           - Показать эту справку"
    echo ""
    echo "Без аргументов - интерактивный режим"
    echo ""
    echo "Ledger: $LEDGER_PATH"
    ;;
*)
    if [[ -z "$1" ]]; then
        main
    else
        error "Неизвестная команда: $1"
        echo "Используйте '$0 help' для справки"
        exit 1
    fi
    ;;
esac
