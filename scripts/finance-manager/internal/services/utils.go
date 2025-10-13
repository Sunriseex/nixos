package services

import (
	"github.com/sunriseex/finance-manager/internal/models"
	"github.com/sunriseex/finance-manager/pkg/calculator"
	"github.com/sunriseex/finance-manager/pkg/dates"
)

func CheckPromoStatus(deposit models.Deposit) (bool, int) {
	return calculator.CheckPromoStatus(deposit)
}

func CalculateMaturityDate(startDate string, termMonths int) (string, error) {
	return dates.CalculateMaturityDate(startDate, termMonths)
}

func CalculateTopUpEndDate(startDate string) string {
	return dates.CalculateTopUpEndDate(startDate)
}

func IsDepositExpired(deposit models.Deposit) bool {
	return dates.IsDepositExpired(deposit.EndDate)
}

func CanBeProlonged(deposit models.Deposit) bool {
	return dates.CanBeProlonged(deposit.EndDate)
}

func DaysUntil(dateStr string) int {
	return dates.DaysUntil(dateStr)
}
