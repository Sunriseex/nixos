package commands

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/sunriseex/finance-manager/internal/config"
	"github.com/sunriseex/finance-manager/internal/services"
	"github.com/sunriseex/finance-manager/internal/storage"
	"github.com/sunriseex/finance-manager/pkg/dates"
	"github.com/sunriseex/finance-manager/pkg/errors"
)

func DepositCreate(name, bank, depositType string, amount int, interestRate float64, termMonths int, promoRate *float64, promoEndDate string) error {
	service := services.NewDepositService()

	req := &services.CreateDepositRequest{
		Name:         name,
		Bank:         bank,
		Type:         depositType,
		Amount:       amount,
		InterestRate: interestRate,
		TermMonths:   termMonths,
		PromoRate:    promoRate,
		PromoEndDate: promoEndDate,
	}

	response, err := service.Create(req)
	if err != nil {
		return err
	}

	fmt.Printf("✅ %s\n", response.Message)
	fmt.Printf("   Вклад: %s\n", response.Deposit.Name)
	fmt.Printf("   ID: %s\n", response.DepositID)
	fmt.Printf("   Сумма: %.2f руб.\n", float64(response.Deposit.Amount)/100.0)
	fmt.Printf("   Ставка: %.2f%%\n", response.Deposit.InterestRate)

	if promoRate != nil {
		fmt.Printf("   Промо-ставка: %.2f%% (до %s)\n", *promoRate, promoEndDate)
	}

	if depositType == "term" {
		fmt.Printf("   Срок: %d месяцев\n", termMonths)
		fmt.Printf("   Дата окончания: %s\n", response.Deposit.EndDate)
	}

	return nil
}

func DepositList() error {
	service := services.NewDepositService()

	response, err := service.List()
	if err != nil {
		return err
	}

	if response.TotalCount == 0 {
		fmt.Println("💼 Нет активных вкладов")
		return nil
	}

	fmt.Println("💼 АКТИВНЫЕ ВКЛАДЫ:")
	fmt.Println("===================")

	for i, deposit := range response.Deposits {
		amountRubles := float64(deposit.Amount) / 100.0

		fmt.Printf("%d. %s (%s)\n", i+1, deposit.Name, deposit.Bank)
		fmt.Printf("   Сумма: %.2f руб.\n", amountRubles)

		active, daysLeft := services.CheckPromoStatus(deposit)
		if active && deposit.PromoRate != nil {
			fmt.Printf("   Промо-ставка: %.2f%% (до %s, осталось %d дн.)\n",
				*deposit.PromoRate, deposit.PromoEndDate, daysLeft)
		} else {
			fmt.Printf("   Ставка: %.2f%%\n", deposit.InterestRate)
		}

		fmt.Printf("   Тип: %s\n", deposit.Type)
		fmt.Printf("   Дата начала: %s\n", deposit.StartDate)

		incomeReq30 := &services.CalculateIncomeRequest{
			DepositID: deposit.ID,
			Days:      30,
		}
		incomeResp30, err := service.CalculateIncome(incomeReq30)
		if err == nil {
			fmt.Printf("   Доход в месяц: ~%.2f руб.\n", incomeResp30.ExpectedIncome)
		} else {
			fmt.Printf("   Доход в месяц: расчет недоступен\n")
		}

		if deposit.Type == "term" && deposit.StartDate != "" && deposit.EndDate != "" {
			totalDays, err := dates.DaysBetween(deposit.StartDate, deposit.EndDate)
			if err == nil && totalDays > 0 {
				incomeReqTotal := &services.CalculateIncomeRequest{
					DepositID: deposit.ID,
					Days:      totalDays,
				}
				incomeRespTotal, err := service.CalculateIncome(incomeReqTotal)
				if err == nil {
					fmt.Printf("   Доход за весь срок (%d дн.): ~%.2f руб.\n",
						totalDays, incomeRespTotal.ExpectedIncome)

					totalAmount := amountRubles + incomeRespTotal.ExpectedIncome
					fmt.Printf("   Общая сумма к концу срока: ~%.2f руб.\n", totalAmount)

				}
			}
		}
		fmt.Println()
	}

	totalRubles := float64(response.TotalAmount) / 100.0
	fmt.Printf("📊 ИТОГО: %d вкладов на сумму %.2f руб.\n", response.TotalCount, totalRubles)

	return nil
}

func DepositTopUp(depositID string, amount int) error {
	service := services.NewDepositService()

	req := &services.TopUpRequest{
		DepositID:   depositID,
		Amount:      amount,
		Description: "Пополнение через CLI",
	}

	response, err := service.TopUp(req)
	if err != nil {
		return err
	}

	fmt.Printf("✅ %s\n", response.Message)
	fmt.Printf("   Предыдущая сумма: %.2f руб.\n", float64(response.PreviousAmount)/100.0)
	fmt.Printf("   Новая сумма: %.2f руб.\n", float64(response.NewAmount)/100.0)
	fmt.Printf("   Пополнено на: %.2f руб.\n", float64(amount)/100.0)

	return nil
}

func DepositCalculateIncome(depositID string, days int) error {
	service := services.NewDepositService()

	req := &services.CalculateIncomeRequest{
		DepositID: depositID,
		Days:      days,
	}

	response, err := service.CalculateIncome(req)
	if err != nil {
		return err
	}

	deposit, err := storage.GetDepositByID(depositID, config.AppConfig.DepositsDataPath)
	if err == nil && deposit.PromoRate != nil {
		active, daysUntilPromoEnd := services.CheckPromoStatus(*deposit)
		if active {
			fmt.Printf("🎯 Учтена промо-ставка: %.2f%% (действует еще %d дней)\n",
				*deposit.PromoRate, daysUntilPromoEnd)
		}
	}

	fmt.Printf("📈 Расчет дохода по вкладу '%s':\n", response.DepositName)
	fmt.Printf("   Сумма вклада: %.2f руб.\n", response.Amount)
	fmt.Printf("   Процентная ставка: %.2f%%\n", response.InterestRate)
	fmt.Printf("   Капитализация: %s\n", response.Capitalization)
	fmt.Printf("   Период: %d дней\n", response.PeriodDays)
	fmt.Printf("   Ожидаемый доход: %.2f руб.\n", response.ExpectedIncome)
	fmt.Printf("   Общая сумма: %.2f руб.\n", response.TotalAmount)

	return nil
}

func DepositUpdate(depositID string) error {
	service := services.NewDepositService()

	req := &services.UpdateDepositRequest{
		DepositID: depositID,
	}

	response, err := service.Update(req)
	if err != nil {
		return err
	}

	fmt.Printf("✅ %s\n", response.Message)
	fmt.Printf("   Вклад: %s\n", response.DepositName)
	fmt.Printf("   Новая дата начала: %s\n", response.StartDate)
	fmt.Printf("   Новая дата окончания: %s\n", response.EndDate)
	fmt.Printf("   Дата окончания пополнения: %s\n", response.TopUpEndDate)

	return nil
}

func DepositAccrueInterest() error {
	service := services.NewInterestService()

	req := &services.AccrueInterestRequest{}

	response, err := service.AccrueInterest(req)
	if err != nil {
		return err
	}

	if response.SuccessCount > 0 {
		fmt.Printf("✅ %s\n", response.Message)
	} else {
		fmt.Println("ℹ️  Не найдено вкладов для начисления процентов")
	}

	if response.ErrorCount > 0 {
		fmt.Printf("\n⚠️  Произошли ошибки при начислении процентов (%d ошибок):\n", response.ErrorCount)
		for _, result := range response.Results {
			if !result.Success {
				fmt.Printf("   • %s: %s\n", result.DepositName, errors.GetUserFriendlyMessage(result.Error))
			}
		}
	}

	return nil
}

func DepositFind(name, bank string) error {
	service := services.NewDepositService()

	req := &services.FindDepositRequest{
		Name: name,
		Bank: bank,
	}

	response, err := service.Find(req)
	if err != nil {
		return err
	}

	if !response.Found {
		fmt.Printf("Вклад '%s' в банке '%s' не найден\n", name, bank)
		return nil
	}

	deposit := response.Deposit
	amountRubles := float64(deposit.Amount) / 100.0
	fmt.Printf("Найден вклад:\n")
	fmt.Printf("  ID: %s\n", deposit.ID)
	fmt.Printf("  Название: %s\n", deposit.Name)
	fmt.Printf("  Банк: %s\n", deposit.Bank)
	fmt.Printf("  Тип: %s\n", deposit.Type)
	fmt.Printf("  Сумма: %.2f руб.\n", amountRubles)
	fmt.Printf("  Ставка: %.2f%%\n", deposit.InterestRate)

	if deposit.Type == "term" {
		fmt.Printf("  Срок: %d месяцев\n", deposit.TermMonths)
		if deposit.EndDate != "" {
			daysLeft := dates.DaysUntil(deposit.EndDate)
			fmt.Printf("  До окончания: %d дней\n", daysLeft)
		}
	}

	return nil
}

func ParseRubles(amountStr string) (int, error) {
	amountStr = strings.Replace(amountStr, ",", ".", -1)
	amount, err := strconv.ParseFloat(amountStr, 64)
	if err != nil {
		return 0, errors.NewValidationError(
			"неверный формат суммы",
			map[string]interface{}{
				"amount": amountStr,
				"error":  err.Error(),
			},
		)
	}

	if amount <= 0 {
		return 0, errors.NewValidationError(
			"сумма должна быть положительной",
			map[string]interface{}{
				"amount": amount,
			},
		)
	}

	if amount > 1000000 {
		return 0, errors.NewValidationError(
			"сумма слишком большая",
			map[string]interface{}{
				"amount":     amount,
				"max_amount": 1000000,
			},
		)
	}

	return int(amount * 100), nil
}

func ParseDays(daysStr string) (int, error) {
	days, err := strconv.Atoi(daysStr)
	if err != nil {
		return 0, errors.NewValidationError(
			"неверный формат количества дней",
			map[string]interface{}{
				"days":  daysStr,
				"error": err.Error(),
			},
		)
	}
	if days <= 0 {
		return 0, errors.NewValidationError(
			"количество дней должно быть положительным",
			map[string]interface{}{
				"days": days,
			},
		)
	}
	if days > 3650 {
		return 0, errors.NewValidationError(
			"количество дней слишком большое",
			map[string]interface{}{
				"days":     days,
				"max_days": 3650,
			},
		)
	}
	return days, nil
}

func ParseRate(rateStr string) (float64, error) {
	rateStr = strings.Replace(rateStr, ",", ".", -1)
	rate, err := strconv.ParseFloat(rateStr, 64)
	if err != nil {
		return 0, errors.NewValidationError(
			"неверный формат процентной ставки",
			map[string]interface{}{
				"rate":  rateStr,
				"error": err.Error(),
			},
		)
	}
	if rate <= 0 {
		return 0, errors.NewValidationError(
			"процентная ставка должна быть положительной",
			map[string]interface{}{
				"rate": rate,
			},
		)
	}
	if rate > 100 {
		return 0, errors.NewValidationError(
			"процентная ставка не может превышать 100%",
			map[string]interface{}{
				"rate": rate,
			},
		)
	}
	return rate, nil
}

func ParseTerm(termStr string) (int, error) {
	term, err := strconv.Atoi(termStr)
	if err != nil {
		return 0, errors.NewValidationError(
			"неверный формат срока",
			map[string]interface{}{
				"term":  termStr,
				"error": err.Error(),
			},
		)
	}
	if term <= 0 {
		return 0, errors.NewValidationError(
			"срок должен быть положительным",
			map[string]interface{}{
				"term": term,
			},
		)
	}
	if term > 60 {
		return 0, errors.NewValidationError(
			"срок не может превышать 60 месяцев",
			map[string]interface{}{
				"term":     term,
				"max_term": 60,
			},
		)
	}
	return term, nil
}
