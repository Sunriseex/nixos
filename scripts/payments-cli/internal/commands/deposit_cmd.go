package commands

import (
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/sunriseex/payments-cli/internal/config"
	"github.com/sunriseex/payments-cli/internal/models"
	"github.com/sunriseex/payments-cli/internal/notifications"
	"github.com/sunriseex/payments-cli/internal/storage"
	"github.com/sunriseex/payments-cli/pkg/calculator"
	"github.com/sunriseex/payments-cli/pkg/utils"
	"github.com/sunriseex/payments-cli/pkg/validation"
)

func DepositCreate(name, bank, depositType string, amount int, interestRate float64, termMonths int, promoRate *float64, promoEndDate string) error {
	validator := validation.NewDepositValidator()
	if err := validator.ValidateCreateRequest(name, bank, depositType, amount, interestRate, termMonths, promoRate, promoEndDate); err != nil {
		return fmt.Errorf("validation error: %v", err)
	}

	deposit := &models.Deposit{
		Name:          strings.TrimSpace(name),
		Bank:          bank,
		Type:          depositType,
		Amount:        amount,
		InitialAmount: amount,
		InterestRate:  interestRate,
		PromoRate:     promoRate,
		PromoEndDate:  promoEndDate,
		StartDate:     time.Now().Format("2006-01-02"),
		AutoRenewal:   true,
	}

	if bank == "Яндекс Банк" || bank == "Yandex" {
		deposit.Capitalization = "daily"
	} else {
		deposit.Capitalization = "daily"
	}

	if depositType == "term" {
		deposit.TermMonths = termMonths
		endDate, err := calculator.CalculateMaturityDate(deposit.StartDate, termMonths)
		if err != nil {
			return fmt.Errorf("error calculating maturity date: %v", err)
		}
		deposit.EndDate = endDate
		deposit.TopUpEndDate = calculator.CalculateTopUpEndDate(deposit.StartDate)
	}

	if err := validator.Validate(deposit); err != nil {
		return fmt.Errorf("deposit validation error: %v", err)
	}

	if err := storage.CreateDeposit(deposit, config.AppConfig.DepositsDataPath); err != nil {
		return fmt.Errorf("error creating deposit: %v", err)
	}

	fmt.Printf("✅ Вклад '%s' успешно создан\n", name)
	if promoRate != nil {
		fmt.Printf("   Промо-ставка: %.2f%% (до %s)\n", *promoRate, promoEndDate)
	}

	amountRubles := float64(amount) / 100.0
	fmt.Printf("   Сумма: %.2f руб.\n", amountRubles)
	fmt.Printf("   Базовая ставка: %.2f%%\n", interestRate)
	if deposit.Type == "term" {
		fmt.Printf("   Срок: %d месяцев\n", termMonths)
		fmt.Printf("   Дата окончания: %s\n", deposit.EndDate)
	}

	return nil
}

func DepositList() error {
	data, err := storage.LoadDeposits(config.AppConfig.DepositsDataPath)
	if err != nil {
		return fmt.Errorf("error loading deposits: %v", err)
	}
	if len(data.Deposits) == 0 {
		fmt.Println("💼 Нет активных вкладов")
		return nil
	}
	fmt.Println("💼 АКТИВНЫЕ ВКЛАДЫ:")
	fmt.Println("===================")
	totalAmount := 0

	for i, deposit := range data.Deposits {
		amountRubles := float64(deposit.Amount) / 100.0
		totalAmount += deposit.Amount

		fmt.Printf("%d. %s (%s)\n", i+1, deposit.Name, deposit.Bank)
		fmt.Printf("   Сумма: %.2f руб.\n", amountRubles)

		active, daysLeft := calculator.CheckPromoStatus(deposit)
		if active {
			fmt.Printf("   Промо-ставка: %.2f%% (до %s, осталось %d дн.)\n",
				*deposit.PromoRate, deposit.PromoEndDate, daysLeft)
		} else {
			fmt.Printf("   Ставка: %.2f%%\n", deposit.InterestRate)
		}

		fmt.Printf("   Тип: %s\n", deposit.Type)

		monthlyIncome := calculator.CalculateIncome(deposit, 30)
		monthlyIncomeFloat, _ := monthlyIncome.Float64()
		fmt.Printf("   Доход в месяц: ~%.2f руб.\n", monthlyIncomeFloat)
		fmt.Println()
	}

	totalRubles := float64(totalAmount) / 100.0
	fmt.Printf("📊 ИТОГО: %d вкладов на сумму %.2f руб.\n", len(data.Deposits), totalRubles)
	return nil
}

func DepositTopUp(depositID string, amount int) error {
	if amount <= 0 {
		return fmt.Errorf("amount must be positive")
	}

	if amount > 10000000 {
		return fmt.Errorf("amount too large for single top-up: %.2f rub", float64(amount)/100.0)
	}

	if err := storage.UpdateDepositAmount(depositID, amount, config.AppConfig.DepositsDataPath); err != nil {
		return fmt.Errorf("error topup deposit: %v", err)
	}

	fmt.Printf("✅ Вклад успешно пополнен на %.2f руб.\n", float64(amount)/100.0)
	return nil
}

func DepositCalculateIncome(depositID string, days int) error {
	data, err := storage.LoadDeposits(config.AppConfig.DepositsDataPath)
	if err != nil {
		return fmt.Errorf("error load deposits for calculate income: %v", err)
	}
	for _, deposit := range data.Deposits {
		if deposit.ID == depositID {
			income := calculator.CalculateIncome(deposit, days)
			incomeFloat, _ := income.Float64()
			amountRubles := float64(deposit.Amount) / 100.0

			fmt.Printf("📈 Расчет дохода по вкладу '%s':\n", deposit.Name)
			fmt.Printf("   Сумма вклада: %.2f руб.\n", amountRubles)
			fmt.Printf("   Процентная ставка: %.2f%%\n", deposit.InterestRate)
			fmt.Printf("   Капитализация: %s\n", deposit.Capitalization)
			fmt.Printf("   Период: %d дней\n", days)
			fmt.Printf("   Ожидаемый доход: %.2f руб.\n", incomeFloat)
			fmt.Printf("   Общая сумма: %.2f руб.\n", amountRubles+incomeFloat)

			return nil
		}

	}
	return fmt.Errorf("deposit with ID %s not found", depositID)
}

func DepositUpdate(depositID string) error {
	deposit, err := storage.GetDepositByID(depositID, config.AppConfig.DepositsDataPath)
	if err != nil {
		return fmt.Errorf("error getting deposit: %v", err)
	}

	if deposit.Type != "term" {
		return fmt.Errorf("only term deposits can be updated (prolonged)")
	}

	if !calculator.CanBeProlonged(*deposit) {
		return fmt.Errorf("deposit cannot be prolonged yet. Can be prolonged within 7 days before end date")
	}

	today := time.Now().Format("2006-01-02")

	deposit.StartDate = today

	endDate, err := calculator.CalculateMaturityDate(today, deposit.TermMonths)
	if err != nil {
		return fmt.Errorf("error calculating maturity date: %v", err)
	}
	deposit.EndDate = endDate

	deposit.TopUpEndDate = calculator.CalculateTopUpEndDate(today)

	validator := validation.NewDepositValidator()
	if err := validator.Validate(deposit); err != nil {
		return fmt.Errorf("validation error after update: %v", err)
	}

	if err := storage.UpdateDeposit(deposit, config.AppConfig.DepositsDataPath); err != nil {
		return fmt.Errorf("error updating deposit: %v", err)
	}

	fmt.Printf("✅ Вклад '%s' успешно обновлен\n", deposit.Name)
	fmt.Printf("   Новая дата начала: %s\n", deposit.StartDate)
	fmt.Printf("   Новая дата окончания: %s\n", deposit.EndDate)
	fmt.Printf("   Дата окончания пополнения: %s\n", deposit.TopUpEndDate)

	return nil
}

func DepositAccrueInterest() error {
	data, err := storage.LoadDeposits(config.AppConfig.DepositsDataPath)
	if err != nil {
		return fmt.Errorf("error loading deposits for interest accrual: %v", err)
	}

	totalAccrued := 0.0
	accruals := 0

	for _, deposit := range data.Deposits {
		var income float64
		var description string

		if deposit.Type == "savings" {
			incomeBig := calculator.CalculateIncome(deposit, 1)
			income, _ = incomeBig.Float64()
			description = "Выплата процентов"
		} else if deposit.Type == "term" {
			if calculator.IsDepositExpired(deposit) {
				daysPassed := daysSince(deposit.StartDate)
				if daysPassed > 0 {
					incomeBig := calculator.CalculateIncome(deposit, daysPassed)
					income, _ = incomeBig.Float64()
					description = "Выплата процентов по окончании срока"
				}
			} else {
				continue
			}
		}

		if income > 0 {
			amountKopecks := int(income * 100)

			if err := storage.RecordDepositToLedger(deposit, "interest", amountKopecks, description, config.AppConfig.LedgerPath); err != nil {
				fmt.Printf("⚠️  Ошибка записи в ledger для вклада %s: %v\n", deposit.Name, err)
				continue
			}

			if err := storage.UpdateDepositAmount(deposit.ID, amountKopecks, config.AppConfig.DepositsDataPath); err != nil {
				fmt.Printf("⚠️  Ошибка обновления суммы вклада %s: %v\n", deposit.Name, err)
				continue
			}

			totalAccrued += income
			accruals++

			fmt.Printf("✅ Начислены проценты по вкладу '%s': %.2f руб.\n", deposit.Name, income)
		}
	}

	if accruals > 0 {
		fmt.Printf("\n📊 Всего начислено: %.2f руб. по %d вкладам\n", totalAccrued, accruals)
	} else {
		fmt.Println("ℹ️  Не найдено вкладов для начисления процентов")
	}

	return nil
}

func ParseRubles(amountStr string) (int, error) {
	amountStr = strings.Replace(amountStr, ",", ".", -1)
	amount, err := strconv.ParseFloat(amountStr, 64)
	if err != nil {
		return 0, fmt.Errorf("неверный формат суммы: %v", err)
	}

	if amount <= 0 {
		return 0, fmt.Errorf("сумма должна быть положительной")
	}

	if amount > 1000000 {
		return 0, fmt.Errorf("сумма слишком большая: %.2f руб. Максимум: 1,000,000 руб.", amount)
	}

	return int(amount * 100), nil
}

func ParseDays(daysStr string) (int, error) {
	days, err := strconv.Atoi(daysStr)
	if err != nil {
		return 0, fmt.Errorf("неверный формат дней: %v", err)
	}
	if days <= 0 {
		return 0, fmt.Errorf("количество дней должно быть положительным")
	}
	return days, nil
}

func ParseRate(rateStr string) (float64, error) {
	rateStr = strings.Replace(rateStr, ",", ".", -1)
	rate, err := strconv.ParseFloat(rateStr, 64)
	if err != nil {
		return 0, fmt.Errorf("неверный формат процентной ставки: %v", err)
	}
	if rate <= 0 {
		return 0, fmt.Errorf("процентная ставка должна быть положительной")
	}
	if rate > 100 {
		return 0, fmt.Errorf("процентная ставка не может превышать 100%")
	}
	return rate, nil
}

func ParseTerm(termStr string) (int, error) {
	term, err := strconv.Atoi(termStr)
	if err != nil {
		return 0, fmt.Errorf("неверный формат срока: %v", err)
	}
	if term <= 0 {
		return 0, fmt.Errorf("срок должен быть положительным")
	}
	if term > 60 {
		return 0, fmt.Errorf("срок не может превышать 60 месяцев")
	}
	return term, nil
}

func validateDeposit(deposit *models.Deposit) error {
	if deposit.Amount <= 0 {
		return fmt.Errorf("deposit amount must be positive")
	}
	if deposit.InterestRate <= 0 {
		return fmt.Errorf("interest rate must be positive")
	}
	if deposit.PromoRate != nil && *deposit.PromoRate <= 0 {
		return fmt.Errorf("promo rate must be positive if set")
	}
	if deposit.Type == "term" && deposit.TermMonths <= 0 {
		return fmt.Errorf("term deposits must have positive term")
	}
	if deposit.Name == "" {
		return fmt.Errorf("deposit name cannot be empty")
	}
	if deposit.Bank == "" {
		return fmt.Errorf("bank name cannot be empty")
	}

	if _, err := time.Parse("2006-01-02", deposit.StartDate); err != nil {
		return fmt.Errorf("invalid start date format: %v", err)
	}

	if deposit.PromoEndDate != "" {
		if _, err := time.Parse("2006-01-02", deposit.PromoEndDate); err != nil {
			return fmt.Errorf("invalid promo end date format: %v", err)
		}
	}

	if deposit.Type == "term" && deposit.EndDate != "" {
		if _, err := time.Parse("2006-01-02", deposit.EndDate); err != nil {
			return fmt.Errorf("invalid end date format: %v", err)
		}
	}

	return nil
}

func DepositFind(name, bank string) error {
	deposit, err := storage.FindDepositByNameAndBank(name, bank, config.AppConfig.DepositsDataPath)
	if err != nil {
		return fmt.Errorf("error searching deposit: %v", err)
	}

	if deposit == nil {
		fmt.Printf("Вклад '%s' в банке '%s' не найден\n", name, bank)
		return nil
	}

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
			daysLeft := utils.DaysUntil(deposit.EndDate)
			fmt.Printf("  До окончания: %d дней\n", daysLeft)
		}
	}

	return nil
}

func daysSince(startDate string) int {
	start, err := time.Parse("2006-01-02", startDate)
	if err != nil {
		return 0
	}
	days := int(time.Since(start).Hours() / 24)
	if days < 0 {
		return 0
	}
	return days
}

func formatBankName(bank string) string {
	switch bank {
	case "Яндекс Банк", "Yandex":
		return "Yandex"
	case "Альфа Банк", "Alfa":
		return "AlfaBank"
	case "Тинькофф", "Tinkoff":
		return "Tbank"
	default:
		return strings.ReplaceAll(bank, " ", "")
	}
}

func DepositCheckNotifications() error {
	data, err := storage.LoadDeposits(config.AppConfig.DepositsDataPath)
	if err != nil {
		return fmt.Errorf("error loading deposits for notifications: %v", err)
	}

	notificationsList := notifications.CheckDepositNotifications(data.Deposits)

	if len(notificationsList) == 0 {
		fmt.Println("ℹ️  Нет уведомлений по вкладам")
		return nil
	}

	fmt.Println("Уведомления по вкладам:")
	fmt.Println("======================")
	for _, notification := range notificationsList {
		fmt.Println("•", notification)
	}

	return nil
}
