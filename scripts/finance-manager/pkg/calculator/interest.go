package calculator

import (
	"time"

	"github.com/shopspring/decimal"

	"github.com/sunriseex/finance-manager/internal/models"
)

func CalculateIncome(deposit models.Deposit, days int) decimal.Decimal {
	if deposit.Amount <= 0 || days <= 0 {
		return decimal.Zero
	}

	amount := decimal.NewFromInt(int64(deposit.Amount)).Div(decimal.NewFromInt(100))
	effectiveRate := getEffectiveRateDecimal(deposit)

	active, daysUntilPromoEnd := CheckPromoStatus(deposit)

	if active && daysUntilPromoEnd > 0 && days > daysUntilPromoEnd {
		return calculateIncomeWithPromoTransition(deposit, amount, days, daysUntilPromoEnd)
	}

	switch deposit.Capitalization {
	case "daily":
		return calculateDailyCapitalization(amount, effectiveRate, days)
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

func CalculateTotalTermIncome(deposit models.Deposit) decimal.Decimal {
	if deposit.Type != "term" || deposit.StartDate == "" || deposit.EndDate == "" {
		return decimal.Zero
	}

	start, err := time.Parse("2006-01-02", deposit.StartDate)
	if err != nil {
		return decimal.Zero
	}

	end, err := time.Parse("2006-01-02", deposit.EndDate)
	if err != nil {
		return decimal.Zero
	}

	totalDays := int(end.Sub(start).Hours() / 24)
	if totalDays <= 0 {
		return decimal.Zero
	}

	return CalculateIncome(deposit, totalDays)
}

func calculateIncomeWithPromoTransition(deposit models.Deposit, amount decimal.Decimal, totalDays, promoDaysRemaining int) decimal.Decimal {
	var incomePromo decimal.Decimal

	if deposit.PromoRate != nil {

		promoRate := decimal.NewFromFloat(*deposit.PromoRate)
		incomePromo = calculateByCapitalization(amount, promoRate, promoDaysRemaining, deposit.Capitalization)

	} else {

		incomePromo = decimal.Zero

	}
	amountAfterPromo := amount.Add(incomePromo)

	remainingDays := totalDays - promoDaysRemaining

	baseRate := decimal.NewFromFloat(deposit.InterestRate)

	var incomeRemaining decimal.Decimal

	incomeRemaining = calculateByCapitalization(amountAfterPromo, baseRate, remainingDays, deposit.Capitalization)

	return incomePromo.Add(incomeRemaining)
}

func calculateByCapitalization(amount, rate decimal.Decimal, days int, capitalization string) decimal.Decimal {
	switch capitalization {
	case "daily":
		return calculateDailyCapitalization(amount, rate, days)
	case "monthly":
		return calculateMonthlyCapitalization(amount, rate, days)
	case "end":
		return calculateEndTerm(amount, rate, days)
	default:
		return calculateEndTerm(amount, rate, days)
	}
}

func calculateDailyCapitalization(amount, rate decimal.Decimal, days int) decimal.Decimal {
	daysInYear := decimal.NewFromInt(365)
	dailyRate := rate.Div(decimal.NewFromInt(100)).Div(daysInYear)
	one := decimal.NewFromInt(1)

	factor := one.Add(dailyRate).Pow(decimal.NewFromInt(int64(days)))
	result := factor.Sub(one).Mul(amount)
	return result
}

func calculateMonthlyCapitalization(amount, rate decimal.Decimal, days int) decimal.Decimal {
	daysInMonth := decimal.NewFromFloat(30.44)
	months := decimal.NewFromInt(int64(days)).Div(daysInMonth)
	monthlyRate := rate.Div(decimal.NewFromInt(1200))
	one := decimal.NewFromInt(1)

	monthsInt := int(months.IntPart())
	if monthsInt > 0 {
		factor := one.Add(monthlyRate).Pow(decimal.NewFromInt(int64(monthsInt)))
		result := factor.Sub(one).Mul(amount)
		return result
	}

	return decimal.Zero
}

func calculateEndTerm(amount, rate decimal.Decimal, days int) decimal.Decimal {
	daysDecimal := decimal.NewFromInt(int64(days))
	daysInYear := decimal.NewFromInt(365)

	result := amount.Mul(rate).Div(decimal.NewFromInt(100))
	result = result.Mul(daysDecimal).Div(daysInYear)

	return result
}

func getEffectiveRateDecimal(deposit models.Deposit) decimal.Decimal {
	if deposit.PromoRate == nil || deposit.PromoEndDate == "" {
		return decimal.NewFromFloat(deposit.InterestRate)
	}
	active, _ := CheckPromoStatus(deposit)
	if active {
		return decimal.NewFromFloat(*deposit.PromoRate)
	}
	return decimal.NewFromFloat(deposit.InterestRate)
}
