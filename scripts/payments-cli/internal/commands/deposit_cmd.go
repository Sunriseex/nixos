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
)

func DepositCreate(name, bank, depositType string, amount int, interestRate float64, termMonths int) error {
	deposit := &models.Deposit{
		Name:           name,
		Bank:           bank,
		Type:           depositType,
		Amount:         amount,
		InterestRate:   interestRate,
		PromoRate:      nil,
		StartDate:      time.Now().Format("2006-01-02"),
		Capitalization: "daily",
		AutoRenewal:    true,
	}

	if depositType == "term" {
		deposit.TermMonths = termMonths
		endDate, err := calculator.CalculateMaturityDate(deposit.StartDate, termMonths)
		if err != nil {
			return err
		}
		deposit.EndDate = endDate
		deposit.TopUpEndDate = calculator.CalculateTopUpEndDate(deposit.StartDate)
	}

	if err := validateDeposit(deposit); err != nil {
		return fmt.Errorf("deposit validation failed: %v", err)
	}

	if err := storage.CreateDeposit(deposit, config.AppConfig.DepositsDataPath); err != nil {
		return fmt.Errorf("error creating deposit: %v", err)
	}

	fmt.Printf("✅ Вклад '%s' успешно создан\n", name)
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
	totalEarned := 0.0

	for i, deposit := range data.Deposits {
		amountRubles := float64(deposit.Amount) / 100.0
		totalAmount += deposit.Amount

		fmt.Printf("%d. %s (%s)\n", i+1, deposit.Name, deposit.Bank)
		fmt.Printf("   Сумма: %.2f руб.\n", amountRubles)
		fmt.Printf("   Ставка: %.2f%%\n", deposit.InterestRate)
		fmt.Printf("   Тип: %s\n", deposit.Type)

		if deposit.Type == "term" && deposit.EndDate != "" {
			daysLeft := utils.DaysUntil(deposit.EndDate)
			fmt.Printf("   До окончания: %d дней\n", daysLeft)

			if deposit.StartDate != "" {
				daysPassed := daysSince(deposit.StartDate)
				if daysPassed > 0 {
					earned := calculator.CalculateIncome(deposit, daysPassed)
					fmt.Printf("   Заработано на текущий момент: ~%.2f руб.\n", earned)
					totalEarned += earned
				}
			}
		} else {
			if deposit.StartDate != "" {
				daysPassed := daysSince(deposit.StartDate)
				if daysPassed > 0 {
					earned := calculator.CalculateIncome(deposit, daysPassed)
					fmt.Printf("   Заработано на текущий момент: ~%.2f руб.\n", earned)
					totalEarned += earned
				}
			}
		}

		monthlyIncome := calculator.CalculateIncome(deposit, 30)
		fmt.Printf("   Доход в месяц: ~%.2f руб.\n", monthlyIncome)
		fmt.Println()
	}

	totalRubles := float64(totalAmount) / 100.0
	fmt.Printf("📊 ИТОГО: %d вкладов на сумму %.2f руб.\n", len(data.Deposits), totalRubles)
	fmt.Printf("💵 Всего заработано: ~%.2f руб.\n", totalEarned)

	return nil
}

func DepositTopUp(depositID string, amount int) error {

	if err := storage.UpdateDepositAmount(depositID, amount, config.AppConfig.DepositsDataPath); err != nil {
		return fmt.Errorf("error topup deposit: %v", err)
	}

	fmt.Printf("✅ Вклад успешно пополнен на %d руб.\n", amount)
	return nil
}

func DepositCheckNotifications() error {
	data, err := storage.LoadDeposits(config.AppConfig.DepositsDataPath)
	if err != nil {
		return fmt.Errorf("error load deposits for check notification: %v", err)
	}
	notifications := notifications.CheckDepositNotifications(data.Deposits)
	if len(notifications) == 0 {
		fmt.Println("✅ Нет активных уведомлений по вкладам")
		return nil
	}
	fmt.Println("🔔 УВЕДОМЛЕНИЯ ПО ВКЛАДАМ:")
	fmt.Println("=========================")
	for _, notification := range notifications {
		fmt.Printf("• %s\n", notification)
	}
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
			amountRubles := float64(deposit.Amount) / 100.0

			fmt.Printf("📈 Расчет дохода по вкладу '%s':\n", deposit.Name)
			fmt.Printf("   Сумма вклада: %.2f руб.\n", amountRubles)
			fmt.Printf("   Процентная ставка: %.2f%%\n", deposit.InterestRate)
			fmt.Printf("   Капитализация: %s\n", deposit.Capitalization)
			fmt.Printf("   Период: %d дней\n", days)
			fmt.Printf("   Ожидаемый доход: %.2f руб.\n", income)
			fmt.Printf("   Общая сумма: %.2f руб.\n", amountRubles+income)

			fmt.Printf("\n💾 Записать начисление процентов в ledger? [y/N]: ")
			var response string
			fmt.Scanln(&response)

			if strings.ToLower(response) == "y" {
				if err := DepositRecordInterest(depositID, income, days); err != nil {
					fmt.Printf("❌ Ошибка записи в ledger: %v\n", err)
				}
			}

			return nil
		}
	}

	return fmt.Errorf("deposit with ID %s not found", depositID)
}

func ParseRubles(amountStr string) (int, error) {
	amount, err := strconv.ParseFloat(amountStr, 64)
	if err != nil {
		return 0, fmt.Errorf("неверный формат суммы: %v", err)
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
	rate, err := strconv.ParseFloat(rateStr, 64)
	if err != nil {
		return 0, fmt.Errorf("неверный формат процентной ставки: %v", err)
	}
	if rate <= 0 {
		return 0, fmt.Errorf("процентная ставка должна быть положительной")
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
	return term, nil
}

func DepositUpdate(depositID string) error {
	deposit, err := storage.GetDepositByID(depositID, config.AppConfig.DepositsDataPath)
	if err != nil {
		return fmt.Errorf("error getting deposit: %v", err)
	}

	if deposit.Type != "term" {
		return fmt.Errorf("only term deposits can be updated (prolonged)")
	}

	today := time.Now().Format("2006-01-02")

	deposit.StartDate = today

	endDate, err := calculator.CalculateMaturityDate(today, deposit.TermMonths)
	if err != nil {
		return fmt.Errorf("error calculating maturity date: %v", err)
	}
	deposit.EndDate = endDate

	deposit.TopUpEndDate = calculator.CalculateTopUpEndDate(today)

	if err := storage.UpdateDeposit(deposit, config.AppConfig.DepositsDataPath); err != nil {
		return fmt.Errorf("error updating deposit: %v", err)
	}

	fmt.Printf("✅ Вклад '%s' успешно обновлен\n", deposit.Name)
	fmt.Printf("   Новая дата начала: %s\n", deposit.StartDate)
	fmt.Printf("   Новая дата окончания: %s\n", deposit.EndDate)
	fmt.Printf("   Дата окончания пополнения: %s\n", deposit.TopUpEndDate)

	return nil
}

func validateDeposit(deposit *models.Deposit) error {
	if deposit.Amount <= 0 {
		return fmt.Errorf("deposit amount must be positive")
	}
	if deposit.InterestRate <= 0 {
		return fmt.Errorf("interest rate must be positive")
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

	if deposit.Type == "term" && deposit.EndDate != "" {
		if _, err := time.Parse("2006-01-02", deposit.EndDate); err != nil {
			return fmt.Errorf("invalid end date format: %v", err)
		}
	}

	return nil
}

func DepositRecordInterest(depositID string, income float64, days int) error {
	data, err := storage.LoadDeposits(config.AppConfig.DepositsDataPath)
	if err != nil {
		return fmt.Errorf("error loading deposits: %v", err)
	}

	var deposit models.Deposit
	found := false
	for _, d := range data.Deposits {
		if d.ID == depositID {
			deposit = d
			found = true
			break
		}
	}

	if !found {
		return fmt.Errorf("deposit with ID %s not found", depositID)
	}

	incomeKopecks := int(income * 100)

	description := fmt.Sprintf("Начисление процентов за %d дней", days)
	if err := storage.RecordDepositToLedger(deposit, "interest", incomeKopecks, description, config.AppConfig.LedgerPath); err != nil {
		return fmt.Errorf("error recording interest to ledger: %v", err)
	}

	fmt.Printf("✅ Начисление процентов записано в ledger: %.2f руб.\n", income)
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
