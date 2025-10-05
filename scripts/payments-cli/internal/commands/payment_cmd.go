// Package commands
package commands

import (
	"flag"
	"fmt"
	"os"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/sunriseex/payments-cli/internal/config"
	"github.com/sunriseex/payments-cli/internal/models"
	"github.com/sunriseex/payments-cli/internal/storage"
	"github.com/sunriseex/payments-cli/pkg/utils"
)

func getNearestPayment() *models.Payment {
	data, err := storage.LoadPayments(config.AppConfig.DataPath)
	if err != nil {
		fmt.Printf("Ошибка загрузки данных: %v\n", err)
		return nil
	}

	if data == nil || len(data.Payments) == 0 {
		return nil
	}

	var nearest *models.Payment
	minDays := 999

	for i := range data.Payments {
		currentPayment := data.Payments[i]

		if currentPayment.PaymentDate != "" {
			continue
		}

		if currentPayment.DueDate == "" {
			continue
		}

		days := utils.DaysUntil(currentPayment.DueDate)
		if days < minDays {
			minDays = days
			paymentCopy := currentPayment
			nearest = &paymentCopy
		}
	}

	return nearest
}

func DisplayWidget() {
	payment := getNearestPayment()
	if payment == nil {
		fmt.Println("💳 Нет платежей")
		return
	}

	if payment.DueDate == "" {
		fmt.Println("💳 Ошибка: нет даты платежа")
		return
	}

	days := utils.DaysUntil(payment.DueDate)
	amount := utils.FormatRubles(payment.Amount)

	name := payment.Name
	if len(name) > 15 {
		name = name[:15] + "…"
	}

	var icon string

	switch {
	case days < 0:
		icon = "🔴"
	case days == 0:
		icon = "🟠"
	case days <= 7:
		icon = "🟡"
	default:
		icon = "🟢"
	}
	intervalInfo := ""
	if payment.DaysInterval > 0 {
		intervalInfo = fmt.Sprintf(" [%dд]", payment.DaysInterval)
	}

	fmt.Printf("%s %s %s₽ · %dд%s\n", icon, name, amount, days, intervalInfo)
}
func MarkPaid() error {
	data, err := storage.LoadPayments(config.AppConfig.DataPath)
	if err != nil {
		return fmt.Errorf("ошибка загрузки данных: %v", err)
	}

	payment := getNearestPayment()
	if payment == nil {
		return fmt.Errorf("нет активных платежей")
	}

	today := time.Now().Format("2006-01-02")

	if err := storage.RecordPaymentToLedger(*payment, config.AppConfig.LedgerPath); err != nil {
		return fmt.Errorf("ошибка записи в ledger: %v", err)
	}

	fmt.Printf("Отладочная информация перед обновлением:\n")
	fmt.Printf("  Платеж: %s, ID: %s, Type: %s\n", payment.Name, payment.ID, payment.Type)

	found := false
	for i := range data.Payments {
		if data.Payments[i].ID == payment.ID {
			found = true
			fmt.Printf("  Найден платеж для обновления: %s\n", data.Payments[i].Name)

			if payment.Type == "one-time" {
				data.Payments[i].PaymentDate = today
				fmt.Printf("  ✅ Разовый платеж '%s' помечен как оплаченный\n", payment.Name)
			} else {
				newDueDate := extendPaymentDate(data.Payments[i])
				data.Payments[i].DueDate = newDueDate
				data.Payments[i].PaymentDate = ""

				intervalInfo := ""
				if payment.DaysInterval > 0 {
					intervalInfo = fmt.Sprintf(" (интервал %d дней)", payment.DaysInterval)
				}

				fmt.Printf("  ✅ Повторяющийся платеж '%s' обновлен. Следующий платеж: %s%s\n",
					payment.Name, newDueDate, intervalInfo)
			}
			break
		}
	}

	if !found {
		return fmt.Errorf("платеж с ID %s не найден в данных", payment.ID)
	}

	if err := storage.SavePayments(data, config.AppConfig.DataPath); err != nil {
		return fmt.Errorf("ошибка сохранения данных: %v", err)
	}

	fmt.Printf("  Данные успешно сохранены\n")

	DisplayWidget()
	return nil
}
func extendPaymentDate(payment models.Payment) string {
	baseDate := time.Now()

	if payment.Type == "one-time" {
		return baseDate.Format("2006-01-02")
	}

	if payment.DaysInterval > 0 {
		return baseDate.AddDate(0, 0, payment.DaysInterval).Format("2006-01-02")
	}
	switch payment.Type {
	case "yearly":
		return baseDate.AddDate(1, 0, 0).Format("2006-01-02")
	case "monthly":
		return baseDate.AddDate(0, 1, 0).Format("2006-01-02")
	default:
		return baseDate.AddDate(0, 1, 0).Format("2006-01-02")
	}
}

func ListPayments() error {
	data, err := storage.LoadPayments(config.AppConfig.DataPath)
	if err != nil {
		return fmt.Errorf("ошибка загрузки данных: %v", err)
	}
	var activePayments []models.Payment
	totalAmount := 0
	for _, p := range data.Payments {
		if p.PaymentDate == "" {
			activePayments = append(activePayments, p)
			totalAmount += p.Amount
		}
	}
	if len(activePayments) == 0 {
		fmt.Println("Нет активных платежей")
		return nil
	}
	sort.Slice(activePayments, func(i, j int) bool {
		return utils.DaysUntil(activePayments[i].DueDate) < utils.DaysUntil(activePayments[j].DueDate)
	})
	var overdue, urgent, upcoming []models.Payment
	for _, p := range activePayments {
		days := utils.DaysUntil(p.DueDate)
		switch {
		case days < 0:
			overdue = append(overdue, p)
		case days <= 7:
			urgent = append(urgent, p)
		default:
			upcoming = append(upcoming, p)
		}
	}
	fmt.Println("АКТИВНЫЕ ПЛАТЕЖИ:")
	fmt.Println("-----------------")
	fmt.Println("")
	if len(overdue) > 0 {
		fmt.Println("🔴 СРОЧНО (просрочено):")
		for _, p := range overdue {
			days := utils.DaysUntil(p.DueDate)
			amountRubles := utils.FormatRubles(p.Amount)
			fmt.Printf("   • %s: %s₽ (%d дней) [%s]", p.Name, amountRubles, -days, p.Type)
			if p.LedgerAccount != "" {
				fmt.Printf(" [%s]", p.LedgerAccount)
			}
			fmt.Println()
		}
		fmt.Println()
	}
	if len(urgent) > 0 {
		fmt.Println("🟡 БЛИЖАЙШИЕ:")
		for _, p := range urgent {
			days := utils.DaysUntil(p.DueDate)
			amountRubles := utils.FormatRubles(p.Amount)
			fmt.Printf("   • %s: %s₽ (%d дней) [%s]", p.Name, amountRubles, days, p.Type)
			if p.LedgerAccount != "" {
				fmt.Printf(" [%s]", p.PaymentDate)
			}
			fmt.Println()
		}
		fmt.Println()
	}
	if len(upcoming) > 0 {
		fmt.Println("🟢 ОЖИДАЕМЫЕ:")
		for _, p := range upcoming {
			days := utils.DaysUntil(p.DueDate)
			amountRubles := utils.FormatRubles(p.Amount)
			fmt.Printf("   • %s: %s₽ (%d дней) [%s]", p.Name, amountRubles, days, p.Type)
			if p.LedgerAccount != "" {
				fmt.Printf(" [%s]", p.LedgerAccount)
			}
			fmt.Println()
		}
		fmt.Println()
	}
	totalRubles := utils.FormatRubles(totalAmount)
	fmt.Printf("📊 ИТОГО: %d платежей на %s₽\n", len(activePayments), totalRubles)

	return nil
}

func AddPayment() error {
	addCmd := flag.NewFlagSet("add", flag.ExitOnError)
	name := addCmd.String("name", "", "Название платежа")
	amountStr := addCmd.String("amount", "", "Сумма платежа в рублях (например: 349.90)")
	dueDate := addCmd.String("date", "", "Дата окончания (ГГГГ-ММ-ДД)")
	days := addCmd.Int("days", 0, "Количество дней (альтернатива дате)")
	paymentType := addCmd.String("type", "monthly", "Тип: monthly, yearly, one-time")
	category := addCmd.String("category", "", "Категория")
	ledgerAccount := addCmd.String("ledger-account", "", "Счет для ledger")

	addCmd.Parse(os.Args[2:])

	if *name == "" || *amountStr == "" {
		return fmt.Errorf("необходимо указать --name и --amount")
	}
	amount, err := utils.RublesToKopecks(*amountStr)
	if err != nil {
		return fmt.Errorf("ошибка конвертации суммы: %v", err)
	}
	var finalDueDate string
	if *days > 0 {
		finalDueDate = time.Now().AddDate(0, 0, *days).Format("2006-01-02")
	} else if *dueDate != "" {
		_, err = time.Parse("2006-01-02", *dueDate)
		if err != nil {
			return fmt.Errorf("некорректная дата. Используйте формат YYYY-MM-DD: %v", err)
		}
		finalDueDate = *dueDate
	} else {
		return fmt.Errorf("необходимая указать либо --date, либо --days")
	}
	validTypes := map[string]bool{
		"monthly":  true,
		"yearly":   true,
		"one-time": true,
	}
	if !validTypes[*paymentType] {
		return fmt.Errorf("некорректный тип. Допустимые: monthly, yearly, one-time")
	}
	data, err := storage.LoadPayments(config.AppConfig.DataPath)
	if err != nil {
		data = &models.PaymentData{Payments: []models.Payment{}}
	}
	id := uuid.New().String()
	newPayment := models.Payment{
		ID:            id,
		Name:          *name,
		Amount:        amount,
		DueDate:       finalDueDate,
		Type:          *paymentType,
		Category:      *category,
		LedgerAccount: *ledgerAccount,
		DaysInterval:  *days,
	}
	data.Payments = append(data.Payments, newPayment)
	if err := storage.SavePayments(data, config.AppConfig.DataPath); err != nil {
		return fmt.Errorf("ошибка сохранения платежа: %v", err)
	}
	intervalInfo := ""
	if *days > 0 {
		intervalInfo = fmt.Sprintf(" [интервал %d дней]", *days)
	}
	accountInfo := ""
	if *ledgerAccount != "" {
		accountInfo = fmt.Sprintf(" -> %s", *ledgerAccount)
	}
	amountRubles := utils.FormatRubles(amount)
	fmt.Printf("Платеж добавлен: %s - %s₽ - %s [%s]%s%s\n", *name, amountRubles, finalDueDate, *paymentType, intervalInfo, accountInfo)

	return nil
}

func ShowLedger() error {
	ledgerPath := storage.ExpandPath(config.AppConfig.LedgerPath)
	if _, err := os.Stat(ledgerPath); os.IsNotExist(err) {
		return fmt.Errorf("ledger файл не существует")
	}
	content, err := os.ReadFile(ledgerPath)
	if err != nil {
		return fmt.Errorf("ошибка чтения ledger файл: %v", err)
	}
	lines := strings.Split(string(content), "\n")
	recentLines := lines[len(lines)-10:]
	fmt.Println("Послдение записи в Ledger:")
	for _, line := range recentLines {
		if strings.TrimSpace(line) != "" {
			fmt.Println(line)
		}
	}
	return nil
}

func CleanupPayments() error {
	data, err := storage.LoadPayments(config.AppConfig.DataPath)
	if err != nil {
		return fmt.Errorf("ошибка загрузки данных: %v", err)
	}
	initialCount := len(data.Payments)
	cleanedData := cleanupOldPayments(*data)
	if err := storage.SavePayments(&cleanedData, config.AppConfig.DataPath); err != nil {
		return fmt.Errorf("ошибка сохранения данных: %v", err)
	}
	fmt.Printf("Очистка завершена. Удалено %d старых платежей\n", initialCount-len(cleanedData.Payments))
	return nil
}

func cleanupOldPayments(data models.PaymentData) models.PaymentData {
	var validPayments []models.Payment
	now := time.Now()
	cutoffDate := now.AddDate(0, 0, -7)
	for _, payment := range data.Payments {
		if payment.PaymentDate != "" {
			validPayments = append(validPayments, payment)
			continue
		}
		due, err := time.Parse("2006-01-02", payment.DueDate)
		if err != nil {
			validPayments = append(validPayments, payment)
			continue
		}
		if due.After(cutoffDate) {
			validPayments = append(validPayments, payment)
		}
	}
	data.Payments = validPayments
	return data
}

func ShowHelp() {
	fmt.Println(`Payments CLI - Управление платежами

Команды:
  payments-cli                    - Показать виджет с ближайшим платежом
  payments-cli paid               - Отметить ближайший платеж как оплаченный
  payments-cli list               - Показать все активные платежи
  payments-cli add                - Добавить новый платеж
  payments-cli ledger             - Показать последние записи Ledger
  payments-cli cleanup            - Очистить старые платежи

Команда add (примеры):
  # С указанием даты
  payments-cli add --name "Yandex Plus" --amount 349.90 --date 2024-10-22 --type monthly --category subscriptions
  
  # С указанием дней
  payments-cli add --name "Хостинг" --amount 1500.00 --days 40 --type one-time --category hosting
  
  # С указанием счета Ledger
  payments-cli add --name "Интернет" --amount 500.00 --date 2024-11-01 --type monthly --category utilities --ledger-account Liabilities:AlfaBank`)
}
