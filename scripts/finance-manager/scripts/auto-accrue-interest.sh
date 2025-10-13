#!/usr/bin/env bash

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

# Логируем запуск
info "$(date): Запуск автоматического начисления процентов"

# Выполняем начисление
if "/home/snrx/nixos/scripts/finance-manager/scripts/deposit-interactive.sh" accrue-interest; then
    info "$(date): Начисление процентов завершено успешно"
else
    error "$(date): Ошибка при начислении процентов (код: $?)"
    exit 1
fi
