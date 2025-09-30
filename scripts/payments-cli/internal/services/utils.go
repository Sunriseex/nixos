package services

import (
	"time"

	"github.com/sunriseex/payments-cli/internal/models"
	"github.com/sunriseex/payments-cli/pkg/calculator"
)

// CheckPromoStatus проверяет статус промо-ставки (перенесена из calculator для избежания циклических импортов)
func CheckPromoStatus(deposit models.Deposit) (bool, int) {
	return calculator.CheckPromoStatus(deposit)
}

// CalculateMaturityDate вычисляет дату окончания вклада (перенесена из calculator)
func CalculateMaturityDate(startDate string, termMonths int) (string, error) {
	return calculator.CalculateMaturityDate(startDate, termMonths)
}

// CalculateTopUpEndDate вычисляет дату окончания пополнения (перенесена из calculator)
func CalculateTopUpEndDate(startDate string) string {
	return calculator.CalculateTopUpEndDate(startDate)
}

// IsDepositExpired проверяет, истек ли срок вклада (перенесена из calculator)
func IsDepositExpired(deposit models.Deposit) bool {
	return calculator.IsDepositExpired(deposit)
}

// CanBeProlonged проверяет, можно ли пролонгировать вклад (перенесена из calculator)
func CanBeProlonged(deposit models.Deposit) bool {
	return calculator.CanBeProlonged(deposit)
}

// DaysUntil вычисляет количество дней до указанной даты (перенесена из utils)
func DaysUntil(dateStr string) int {
	if dateStr == "" {
		return 999
	}

	today := time.Now()
	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		return 999
	}
	return int(date.Sub(today).Hours() / 24)
}
