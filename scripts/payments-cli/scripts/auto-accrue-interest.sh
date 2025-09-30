#!/bin/bash

# Скрипт для автоматического начисления процентов (для cron)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEDGER_PATH="$HOME/ObsidianVault/finances/transactions.ledger"

# Логируем запуск
echo "$(date): Запуск автоматического начисления процентов" >>"$SCRIPT_DIR/interest-accrual.log"

# Выполняем начисление
"$SCRIPT_DIR/deposit-interactive.sh" accrue-interest

# Проверяем результат
if [ $? -eq 0 ]; then
    echo "$(date): Начисление процентов завершено успешно" >>"$SCRIPT_DIR/interest-accrual.log"
else
    echo "$(date): Ошибка при начислении процентов" >>"$SCRIPT_DIR/interest-accrual.log"
fi
