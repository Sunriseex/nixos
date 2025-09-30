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
	"github.com/sunriseex/payments-cli/pkg/errors"
	"github.com/sunriseex/payments-cli/pkg/utils"
	"github.com/sunriseex/payments-cli/pkg/validation"
)

func DepositCreate(name, bank, depositType string, amount int, interestRate float64, termMonths int, promoRate *float64, promoEndDate string) error {
	validator := validation.NewDepositValidator()
	if err := validator.ValidateCreateRequest(name, bank, depositType, amount, interestRate, termMonths, promoRate, promoEndDate); err != nil {
		return errors.NewValidationError(
			"некорректные параметры вклада",
			map[string]interface{}{
				"name":          name,
				"bank":          bank,
				"type":          depositType,
				"amount":        amount,
				"interest_rate": interestRate,
				"term_months":   termMonths,
			},
		)
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
			return errors.WrapError(
				errors.ErrCalculation,
				"ошибка расчета даты окончания вклада",
				err,
			)
		}
		deposit.EndDate = endDate
		deposit.TopUpEndDate = calculator.CalculateTopUpEndDate(deposit.StartDate)
	}

	if err := validator.Validate(deposit); err != nil {
		return errors.NewValidationError(
			"ошибка валидации данных вклада",
			map[string]interface{}{
				"deposit_name":     deposit.Name,
				"validation_error": err.Error(),
			},
		)
	}

	if err := storage.CreateDeposit(deposit, config.AppConfig.DepositsDataPath); err != nil {
		return errors.NewStorageError("создание вклада", err)
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
		return errors.NewStorageError("загрузка списка вкладов", err)
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
		return errors.NewValidationError(
			"сумма пополнения должна быть положительной",
			map[string]interface{}{
				"amount":     amount,
				"deposit_id": depositID,
			},
		)
	}

	if amount > 10000000 {
		return errors.NewValidationError(
			"сумма пополнения слишком большая",
			map[string]interface{}{
				"amount":      amount,
				"max_allowed": 10000000,
				"deposit_id":  depositID,
			},
		)
	}

	if err := storage.UpdateDepositAmount(depositID, amount, config.AppConfig.DepositsDataPath); err != nil {
		return errors.WrapError(
			errors.ErrStorage,
			"ошибка пополнения вклада",
			err,
		)
	}

	fmt.Printf("✅ Вклад успешно пополнен на %.2f руб.\n", float64(amount)/100.0)
	return nil
}

func DepositCalculateIncome(depositID string, days int) error {
	data, err := storage.LoadDeposits(config.AppConfig.DepositsDataPath)
	if err != nil {
		return errors.NewStorageError("загрузка данных для расчета дохода", err)
	}

	var foundDeposit *models.Deposit
	for i := range data.Deposits {
		if data.Deposits[i].ID == depositID {
			foundDeposit = &data.Deposits[i]
			break
		}
	}

	if foundDeposit == nil {
		return errors.NewNotFoundError("вклад", depositID)
	}

	income := calculator.CalculateIncome(*foundDeposit, days)
	incomeFloat, _ := income.Float64()
	amountRubles := float64(foundDeposit.Amount) / 100.0

	fmt.Printf("📈 Расчет дохода по вкладу '%s':\n", foundDeposit.Name)
	fmt.Printf("   Сумма вклада: %.2f руб.\n", amountRubles)
	fmt.Printf("   Процентная ставка: %.2f%%\n", foundDeposit.InterestRate)
	fmt.Printf("   Капитализация: %s\n", foundDeposit.Capitalization)
	fmt.Printf("   Период: %d дней\n", days)
	fmt.Printf("   Ожидаемый доход: %.2f руб.\n", incomeFloat)
	fmt.Printf("   Общая сумма: %.2f руб.\n", amountRubles+incomeFloat)

	return nil
}

func DepositUpdate(depositID string) error {
	deposit, err := storage.GetDepositByID(depositID, config.AppConfig.DepositsDataPath)
	if err != nil {
		return errors.NewNotFoundError("вклад", depositID)
	}

	if deposit.Type != "term" {
		return errors.NewBusinessLogicError(
			"только срочные вклады могут быть обновлены (пролонгированы)",
			map[string]interface{}{
				"deposit_id":   depositID,
				"deposit_type": deposit.Type,
			},
		)
	}

	if !calculator.CanBeProlonged(*deposit) {
		return errors.NewBusinessLogicError(
			"вклад не может быть пролонгирован в данный момент",
			map[string]interface{}{
				"deposit_id": depositID,
				"end_date":   deposit.EndDate,
			},
		)
	}

	today := time.Now().Format("2006-01-02")
	deposit.StartDate = today

	endDate, err := calculator.CalculateMaturityDate(today, deposit.TermMonths)
	if err != nil {
		return errors.NewCalculationError(
			"ошибка расчета даты окончания при обновлении вклада",
			err,
		)
	}
	deposit.EndDate = endDate
	deposit.TopUpEndDate = calculator.CalculateTopUpEndDate(today)

	validator := validation.NewDepositValidator()
	if err := validator.Validate(deposit); err != nil {
		return errors.NewValidationError(
			"ошибка валидации данных после обновления",
			map[string]interface{}{
				"deposit_name":     deposit.Name,
				"validation_error": err.Error(),
			},
		)
	}

	if err := storage.UpdateDeposit(deposit, config.AppConfig.DepositsDataPath); err != nil {
		return errors.NewStorageError("обновление вклада", err)
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
		return errors.NewStorageError("загрузка вкладов для начисления процентов", err)
	}

	totalAccrued := 0.0
	accruals := 0
	var errorsList []error

	for _, deposit := range data.Deposits {
		var income float64
		var description string

		if deposit.Type == "savings" {
			incomeBig := calculator.CalculateIncome(deposit, 1)
			income, _ = incomeBig.Float64()
			description = "Ежедневная выплата процентов"
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
				errMsg := errors.WrapError(
					errors.ErrStorage,
					fmt.Sprintf("ошибка записи в ledger для вклада '%s'", deposit.Name),
					err,
				)
				errorsList = append(errorsList, errMsg)
				continue
			}

			if err := storage.UpdateDepositAmount(deposit.ID, amountKopecks, config.AppConfig.DepositsDataPath); err != nil {
				errMsg := errors.WrapError(
					errors.ErrStorage,
					fmt.Sprintf("ошибка обновления суммы вклада '%s'", deposit.Name),
					err,
				)
				errorsList = append(errorsList, errMsg)
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

	if len(errorsList) > 0 {
		fmt.Println("\n⚠️  Произошли ошибки при начислении процентов:")
		for _, err := range errorsList {
			fmt.Printf("   • %s\n", errors.GetUserFriendlyMessage(err))
		}
		return errors.NewBusinessLogicError(
			"не все проценты были начислены из-за ошибок",
			map[string]interface{}{
				"total_errors":        len(errorsList),
				"successful_accruals": accruals,
			},
		)
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

func DepositFind(name, bank string) error {
	deposit, err := storage.FindDepositByNameAndBank(name, bank, config.AppConfig.DepositsDataPath)
	if err != nil {
		return errors.NewStorageError("поиск вклада", err)
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
		return errors.NewStorageError("загрузка вкладов для проверки уведомлений", err)
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
