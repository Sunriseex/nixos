package services

import (
	"github.com/sunriseex/payments-cli/internal/models"
	"github.com/sunriseex/payments-cli/pkg/calculator"
	"github.com/sunriseex/payments-cli/pkg/dates"
)

// CheckPromoStatus проверяет статус промо-ставки (перенесена из calculator для избежания циклических импортов)
func CheckPromoStatus(deposit models.Deposit) (bool, int) {
	return calculator.CheckPromoStatus(deposit)
}

// CalculateMaturityDate вычисляет дату окончания вклада (перенесена из calculator)
func CalculateMaturityDate(startDate string, termMonths int) (string, error) {
	return dates.CalculateMaturityDate(startDate, termMonths)
}

// CalculateTopUpEndDate вычисляет дату окончания пополнения (перенесена из calculator)
func CalculateTopUpEndDate(startDate string) string {
	return dates.CalculateTopUpEndDate(startDate)
}

// IsDepositExpired проверяет, истек ли срок вклада (перенесена из calculator)
func IsDepositExpired(deposit models.Deposit) bool {
	return dates.IsDepositExpired(deposit.EndDate)
}

// CanBeProlonged проверяет, можно ли пролонгировать вклад (перенесена из calculator)
func CanBeProlonged(deposit models.Deposit) bool {
	return dates.CanBeProlonged(deposit.EndDate)
}

// DaysUntil вычисляет количество дней до указанной даты (перенесена из utils)
func DaysUntil(dateStr string) int {
	return dates.DaysUntil(dateStr)
}
