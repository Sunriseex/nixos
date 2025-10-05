package calculator

import (
	"math/big"
	"time"

	"github.com/sunriseex/payments-cli/internal/models"
)

func calculateIncomeWithPromoTransition(deposit models.Deposit, amount *big.Float, totalDays, promoDaysRemaining int) *big.Float {
	var incomePromo *big.Float
	if deposit.PromoRate != nil {
		promoRate := big.NewFloat(*deposit.PromoRate)
		switch deposit.Capitalization {
		case "daily":
			incomePromo = calculateDailyCapitalization(amount, promoRate, promoDaysRemaining, 365)
		case "monthly":
			incomePromo = calculateMonthlyCapitalization(amount, promoRate, promoDaysRemaining)
		case "end":
			incomePromo = calculateEndTerm(amount, promoRate, promoDaysRemaining)
		default:
			incomePromo = calculateEndTerm(amount, promoRate, promoDaysRemaining)

		}

	} else {
		incomePromo = new(big.Float).SetInt64(0)
	}
	amountAfterPromo := new(big.Float).Add(amount, incomePromo)
	remainingDays := totalDays - promoDaysRemaining
	baseRate := big.NewFloat(deposit.InterestRate)
	var incomeRemaining *big.Float
	switch deposit.Capitalization {
	case "daily":
		incomeRemaining = calculateDailyCapitalization(amountAfterPromo, baseRate, remainingDays, 365)
	case "monthly":
		incomeRemaining = calculateMonthlyCapitalization(amountAfterPromo, baseRate, remainingDays)
	case "end":
		incomeRemaining = calculateEndTerm(amountAfterPromo, baseRate, remainingDays)
	default:
		incomeRemaining = calculateEndTerm(amountAfterPromo, baseRate, remainingDays)
	}
	return new(big.Float).Add(incomePromo, incomeRemaining)
}

func CalculateIncome(deposit models.Deposit, days int) *big.Float {
	if deposit.Amount <= 0 || days <= 0 {
		return new(big.Float).SetInt64(0)
	}

	amount := new(big.Float).SetInt64(int64(deposit.Amount))
	amount.Quo(amount, big.NewFloat(100.0))

	active, daysUntilPromoEnd := CheckPromoStatus(deposit)

	if active && daysUntilPromoEnd > 0 && days > daysUntilPromoEnd {
		return calculateIncomeWithPromoTransition(deposit, amount, days, daysUntilPromoEnd)
	}

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
