package calculator

import (
	"math"
	"time"

	"github.com/sunriseex/payments-cli/internal/models"
)

func CalculateIncome(deposit models.Deposit, days int) float64 {
	if deposit.Amount == 0 || days <= 0 {
		return 0.0
	}

	amount := float64(deposit.Amount) / 100.0
	effectiveRate := getEffectiveRate(deposit)

	if deposit.Bank == "Яндекс Банк" || deposit.Bank == "Yandex" {
		dailyRate := effectiveRate / 360 / 100.0
		return amount * (math.Pow(1+dailyRate, float64(days)) - 1)
	}

	switch deposit.Capitalization {
	case "daily":
		dailyRate := effectiveRate / 365 / 100.0
		return amount * (math.Pow(1+dailyRate, float64(days)) - 1)
	case "monthly":
		months := float64(days) / 30.44
		monthlyRate := effectiveRate / 12.0 / 100.0
		return amount * (math.Pow(1+monthlyRate, months) - 1)
	case "end":
		return amount * effectiveRate / 100.0 * float64(days) / 365.0
	default:
		return amount * effectiveRate / 100.0 * float64(days) / 365.0
	}
}

func CalculateMaturityDate(startDate string, termMonths int) (string, error) {
	date, err := time.Parse("2006-01-02", startDate)
	if err != nil {
		return "", err
	}
	maturityDate := date.AddDate(0, termMonths, 0)
	return maturityDate.Format("2006-01-02"), nil
}

func CalculateTopUpEndDate(startDate string) string {
	date, err := time.Parse("2006-01-02", startDate)
	if err != nil {
		date = time.Now()
	}
	topUpEnd := date.AddDate(0, 0, 7)
	return topUpEnd.Format("2006-01-02")
}

func getEffectiveRate(deposit models.Deposit) float64 {
	if deposit.PromoRate == nil || deposit.PromoEndDate == "" {
		return deposit.InterestRate
	}

	active, _ := CheckPromoStatus(deposit)
	if active {
		return *deposit.PromoRate
	}

	return deposit.InterestRate
}

func CheckPromoStatus(deposit models.Deposit) (bool, int) {
	if deposit.PromoRate == nil || deposit.PromoEndDate == "" {
		return false, 0
	}

	promoEnd, err := time.Parse("2006-01-02", deposit.PromoEndDate)
	if err != nil {
		return false, 0
	}

	promoEnd = promoEnd.AddDate(0, 0, 1)
	daysUntilEnd := int(promoEnd.Sub(time.Now()).Hours() / 24)

	return daysUntilEnd > 0, daysUntilEnd
}

func IsDepositExpired(deposit models.Deposit) bool {
	if deposit.Type != "term" || deposit.EndDate == "" {
		return false
	}

	endDate, err := time.Parse("2006-01-02", deposit.EndDate)
	if err != nil {
		return false
	}

	return time.Now().After(endDate)
}

func CanBeProlonged(deposit models.Deposit) bool {
	if deposit.Type != "term" {
		return false
	}

	if deposit.EndDate == "" {
		return false
	}

	endDate, err := time.Parse("2006-01-02", deposit.EndDate)
	if err != nil {
		return false
	}

	daysUntilEnd := int(endDate.Sub(time.Now()).Hours() / 24)
	return daysUntilEnd <= 7
}

func CalculateTotalTermIncome(deposit models.Deposit) float64 {
	if deposit.Type != "term" || deposit.StartDate == "" || deposit.EndDate == "" {
		return 0.0
	}

	start, err := time.Parse("2006-01-02", deposit.StartDate)
	if err != nil {
		return 0.0
	}

	end, err := time.Parse("2006-01-02", deposit.EndDate)
	if err != nil {
		return 0.0
	}

	totalDays := int(end.Sub(start).Hours() / 24)
	if totalDays <= 0 {
		return 0.0
	}

	return CalculateIncome(deposit, totalDays)
}
