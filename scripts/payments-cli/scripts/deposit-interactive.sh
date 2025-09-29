#!/bin/bash

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

record_interest_interactive() {
    echo "=========================================="
    echo "Запись начисленных процентов в ledger"
    echo "=========================================="

    echo "Список вкладов:"
    deposit-manager list

    echo ""
    read -p "Введите название вклада: " name
    read -p "Введите банк: " bank
    read -p "Введите сумму процентов: " amount
    read -p "Введите количество дней: " days

    if [[ ! $amount =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] || [[ $(echo "$amount <= 0" | bc -l) -eq 1 ]]; then
        error "Некорректная сумма"
        return 1
    fi

    if [[ ! $days =~ ^[0-9]+$ ]] || [[ $days -le 0 ]]; then
        error "Некорректное количество дней"
        return 1
    fi

    local to_account=$(get_default_account "$bank" "to")
    echo "Счет для зачисления процентов:"
    read -p "  [по умолчанию: $to_account]: " custom_to_account
    to_account=${custom_to_account:-$to_account}

    record_interest "$name" "$amount" "$days" "$to_account"
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

    log "Создание нового вклада: $name"

    select_accounts "$bank"

    local command="deposit-manager create --name \"$name\" --bank \"$bank\" --type \"$deposit_type\" --amount \"$amount\" --rate \"$rate\""

    if [[ "$deposit_type" == "term" && -n "$term" ]]; then
        command="$command --term \"$term\""
    fi

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

    # Получаем ID существующего вклада
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

            read -p "Есть ли промо-ставка? [y/N]: " promo_rate
            if [[ $promo_rate =~ ^[Yy]$ ]]; then
                read -p "Введите промо-ставку: " promo_rate_value
                read -p "Введите дату окончания промо-ставки (ГГГГ-ММ-ДД): " promo_end_date
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
        if [[ -n "$capitalization" ]]; then
            echo "Капитализация: $capitalization"
        fi
        echo "=========================================="

        while true; do
            read -p "Создать вклад? [y/N]: " confirm
            case $confirm in
            [Yy]*)
                create_new_deposit "$name" "$bank" "$deposit_type" "$amount" "$rate" "$term"
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

bulk_topup() {
    echo "=========================================="
    echo "Массовое пополнение вкладов"
    echo "=========================================="

    echo "Список ваших вкладов:"
    deposit-manager list

    echo ""
    read -p "Введите сумму для пополнения всех вкладов: " amount

    if [[ ! $amount =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] || [[ $(echo "$amount <= 0" | bc -l) -eq 1 ]]; then
        error "Некорректная сумма"
        return 1
    fi

    warn "Функция массового пополнения требует доработки для парсинга списка вкладов"
    info "Используйте 'deposit-manager list' для просмотра ID вкладов"
    info "Затем используйте 'deposit-manager topup <id> <amount>' для каждого вклада"
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
    echo "4) Массовое пополнение"
    echo "5) Рассчитать доход"
    echo "6) Записать начисление процентов в ledger"
    echo "7) Показать заработанные проценты"
    echo "8) Выход"
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

show_earned_interest() {
    echo "=========================================="
    echo "Заработанные проценты по вкладам"
    echo "=========================================="

    echo "Расчет заработанных процентов на текущий момент..."

    deposit-manager list | grep -A 5 "Заработано на текущий момент" ||
        info "Для просмотра заработанных процентов используйте: deposit-manager list"
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
        read -p "Ваш выбор [1-8]: " choice

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
            bulk_topup
            ;;
        5)
            echo ""
            read -p "Введите ID вклада: " deposit_id
            read -p "Введите количество дней для расчета: " days
            deposit-manager calculate "$deposit_id" "$days"
            ;;
        6)
            record_interest_interactive
            ;;
        7)
            show_earned_interest
            ;;
        8)
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
        error "Использование: $0 calculate <deposit_id> <days>"
        exit 1
    fi
    ;;
"interest")
    if [[ $# -ge 4 ]]; then
        record_interest "$2" "$3" "$4"
    else
        error "Использование: $0 interest <deposit_name> <amount> <days>"
        exit 1
    fi
    ;;
"earned")
    show_earned_interest
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
    echo "  calculate <id> <days> - Рассчитать доход"
    echo "  interest <name> <amount> <days> - Записать начисление процентов"
    echo "  earned         - Показать заработанные проценты"
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
