package calculator

import (
	"math/big"
	"time"

	"github.com/sunriseex/payments-cli/internal/models"
)

func CalculateIncome(deposit models.Deposit, days int) *big.Float {
	if deposit.Amount <= 0 || days <= 0 {
		return new(big.Float).SetInt64(0)
	}

	amount := new(big.Float).SetInt64(int64(deposit.Amount))
	amount.Quo(amount, big.NewFloat(100.0))

	effectiveRate := getEffectiveRateBig(deposit)

	switch deposit.Capitalization {
	case "daily":
		return calculateDailyCapitalization(amount, effectiveRate, days, 365)
	case "monthly":
		return calculateMonthlyCapitalization(amount, effectiveRate, days)
	case "end":
		return calculateEndTerm(amount, effectiveRate, days)
	default:
		return calculateEndTerm(amount, effectiveRate, days)
	}
}

func calculateDailyCapitalization(amount, rate *big.Float, days int, daysInYear float64) *big.Float {
	dailyRate := new(big.Float).Quo(rate, big.NewFloat(daysInYear*100))
	one := big.NewFloat(1.0)

	factor := new(big.Float).Add(one, dailyRate)
	factor = pow(factor, days)

	result := new(big.Float).Sub(factor, one)
	result.Mul(result, amount)

	return result
}

func calculateMonthlyCapitalization(amount, rate *big.Float, days int) *big.Float {
	months := new(big.Float).Quo(big.NewFloat(float64(days)), big.NewFloat(30.44))
	monthlyRate := new(big.Float).Quo(rate, big.NewFloat(1200))
	one := big.NewFloat(1.0)

	factor := new(big.Float).Add(one, monthlyRate)
	monthsInt := int(months.Mul(months, big.NewFloat(1.0)).Sign())
	if monthsInt > 0 {
		factor = pow(factor, monthsInt)
	}

	result := new(big.Float).Sub(factor, one)
	result.Mul(result, amount)

	return result
}

func calculateEndTerm(amount, rate *big.Float, days int) *big.Float {
	result := new(big.Float).Mul(amount, rate)
	result.Quo(result, big.NewFloat(100.0))
	result.Mul(result, big.NewFloat(float64(days)))
	result.Quo(result, big.NewFloat(365.0))
	return result
}

func pow(x *big.Float, n int) *big.Float {
	if n == 0 {
		return big.NewFloat(1.0)
	}

	result := new(big.Float).Copy(x)
	for i := 1; i < n; i++ {
		result.Mul(result, x)
	}
	return result
}

func getEffectiveRateBig(deposit models.Deposit) *big.Float {
	if deposit.PromoRate == nil || deposit.PromoEndDate == "" {
		return big.NewFloat(deposit.InterestRate)
	}

	active, _ := CheckPromoStatus(deposit)
	if active {
		return big.NewFloat(*deposit.PromoRate)
	}

	return big.NewFloat(deposit.InterestRate)
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

func CalculateTotalTermIncome(deposit models.Deposit) *big.Float {
	if deposit.Type != "term" || deposit.StartDate == "" || deposit.EndDate == "" {
		return big.NewFloat(0.0)
	}

	start, err := time.Parse("2006-01-02", deposit.StartDate)
	if err != nil {
		return big.NewFloat(0.0)
	}

	end, err := time.Parse("2006-01-02", deposit.EndDate)
	if err != nil {
		return big.NewFloat(0.0)
	}

	totalDays := int(end.Sub(start).Hours() / 24)
	if totalDays <= 0 {
		return big.NewFloat(0.0)
	}

	return CalculateIncome(deposit, totalDays)
}
