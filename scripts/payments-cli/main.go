package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

type Payment struct {
	ID            string `json:"id"`
	Name          string `json:"name"`
	Amount        int    `json:"amount"`
	DueDate       string `json:"due_date"`
	PaymentDate   string `json:"payment_date,omitempty"`
	Type          string `json:"type"`
	Category      string `json:"category,omitempty"`
	LedgerAccount string `json:"ledger_account,omitempty"`
	DaysInterval  int    `json:"days_interval,omitempty"`
}

type PaymentsData struct {
	Payments []Payment `json:"payments"`
}

const (
	dataFile   = ".config/waybar/payments.json"
	ledgerFile = "ObsidianVault/finances/transactions.ledger"
)

func getDataPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, dataFile)
}

func getLedgerPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ledgerFile)
}

func rublesToKopecks(rublesStr string) (int, error) {
	rublesStr = strings.Replace(rublesStr, ",", ".", -1)

	amount, err := strconv.ParseFloat(rublesStr, 64)
	if err != nil {
		return 0, fmt.Errorf("неверный формат суммы: %v", err)
	}

	return int(amount * 100), nil
}

func formatRubles(kopecks int) string {
	rubles := float64(kopecks) / 100.0
	return fmt.Sprintf("%.2f", rubles)
}

func loadPayments() (*PaymentsData, error) {
	dataPath := getDataPath()
	if _, err := os.Stat(dataPath); os.IsNotExist(err) {
		return &PaymentsData{Payments: []Payment{}}, nil
	}
	file, err := os.ReadFile(dataPath)
	if err != nil {
		return nil, err
	}
	var data PaymentsData
	err = json.Unmarshal(file, &data)
	if err != nil {
		return nil, err
	}

	data = cleanupOldPayments(data)

	return &data, nil
}

func cleanupOldPayments(data PaymentsData) PaymentsData {
	var validPayments []Payment
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

func savePayments(data *PaymentsData) error {
	dataPath := getDataPath()
	dir := filepath.Dir(dataPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	file, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(dataPath, file, 0644)
}

func recordToLedger(payment Payment) error {
	ledgerPath := getLedgerPath()
	dir := filepath.Dir(ledgerPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	file, err := os.OpenFile(ledgerPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer file.Close()

	today := time.Now().Format("2006/01/02")

	expenseAccount := "Expenses:Subscriptions"
	if payment.Category != "" {
		expenseAccount = "Expenses:" + strings.ReplaceAll(payment.Category, ":", ":")
	}

	paymentAccount := payment.LedgerAccount
	if paymentAccount == "" {
		paymentAccount = "Liabilities:YandexPay"
	}

	amount := fmt.Sprintf("%.2f RUB", float64(payment.Amount)/100.0)

	entry := fmt.Sprintf("%s * \"%s\"\n    %-40s  %s\n    %s\n\n",
		today,
		payment.Name,
		expenseAccount,
		amount,
		paymentAccount)

	_, err = file.WriteString(entry)
	return err
}

func daysUntil(dueDate string) int {
	today := time.Now()
	due, err := time.Parse("2006-01-02", dueDate)
	if err != nil {
		return 999
	}
	return int(due.Sub(today).Hours() / 24)
}

func getNearestPayment() *Payment {
	data, err := loadPayments()
	if err != nil || len(data.Payments) == 0 {
		return nil
	}
	var nearest *Payment
	minDays := 999
	for i := range data.Payments {
		if data.Payments[i].PaymentDate != "" {
			continue
		}
		days := daysUntil(data.Payments[i].DueDate)
		if days < minDays {
			minDays = days
			nearest = &data.Payments[i]
		}
	}
	return nearest
}

func extendPaymentDate(payment Payment) string {
	due, err := time.Parse("2006-01-02", payment.DueDate)
	if err != nil {
		due = time.Now()
	}

	if payment.DaysInterval > 0 {
		return due.AddDate(0, 0, payment.DaysInterval).Format("2006-01-02")
	}

	switch payment.Type {
	case "yearly":
		return due.AddDate(1, 0, 0).Format("2006-01-02")
	case "monthly":
		return due.AddDate(0, 1, 0).Format("2006-01-02")
	default:
		return due.Format("2006-01-02")
	}
}

func displayWidget() {
	payment := getNearestPayment()
	if payment == nil {
		fmt.Println("💳 Нет платежей")
		return
	}

	days := daysUntil(payment.DueDate)
	amount := formatRubles(payment.Amount)
	name := payment.Name
	if len(name) > 12 {
		name = name[:12] + "…"
	}

	var icon string
	if days < 0 {
		icon = "🔴"
	} else if days == 0 {
		icon = "🟠"
	} else if days <= 7 {
		icon = "🟡"
	} else {
		icon = "🟢"
	}

	intervalInfo := ""
	if payment.DaysInterval > 0 {
		intervalInfo = fmt.Sprintf(" [%dд]", payment.DaysInterval)
	}

	fmt.Printf("%s %s %s₽ · %dд%s\n", icon, name, amount, days, intervalInfo)
}

func markPaid() {
	data, err := loadPayments()
	if err != nil {
		fmt.Println("Ошибка загрузки данных")
		return
	}

	payment := getNearestPayment()
	if payment == nil {
		fmt.Println("Нет активных платежей")
		return
	}

	today := time.Now().Format("2006-01-02")

	if err := recordToLedger(*payment); err != nil {
		fmt.Printf("Ошибка записи в Ledger: %v\n", err)
	} else {
		fmt.Printf("Запись в Ledger добавлена\n")
	}

	for i := range data.Payments {
		if data.Payments[i].ID == payment.ID {
			data.Payments[i].PaymentDate = today

			if payment.Type != "one-time" || payment.DaysInterval > 0 {
				newDueDate := extendPaymentDate(data.Payments[i])
				data.Payments[i].DueDate = newDueDate
				data.Payments[i].PaymentDate = ""

				intervalInfo := ""
				if payment.DaysInterval > 0 {
					intervalInfo = fmt.Sprintf(" (интервал %d дней)", payment.DaysInterval)
				}

				fmt.Printf("✅ %s оплачен, следующий платеж: %s%s\n", payment.Name, newDueDate, intervalInfo)
			} else {
				fmt.Printf("✅ %s оплачен\n", payment.Name)
			}
			break
		}
	}

	savePayments(data)
	displayWidget()
}

func listPayments() {
	data, err := loadPayments()
	if err != nil || len(data.Payments) == 0 {
		fmt.Println("Нет активных платежей")
		return
	}

	var activePayments []Payment
	totalAmount := 0

	for _, p := range data.Payments {
		if p.PaymentDate == "" {
			activePayments = append(activePayments, p)
			totalAmount += p.Amount
		}
	}

	if len(activePayments) == 0 {
		fmt.Println("Нет активных платежей")
		return
	}

	sort.Slice(activePayments, func(i, j int) bool {
		return daysUntil(activePayments[i].DueDate) < daysUntil(activePayments[j].DueDate)
	})

	var overdue, urgent, upcoming []Payment

	for _, p := range activePayments {
		days := daysUntil(p.DueDate)
		if days < 0 {
			overdue = append(overdue, p)
		} else if days <= 7 {
			urgent = append(urgent, p)
		} else {
			upcoming = append(upcoming, p)
		}
	}

	fmt.Println("АКТИВНЫЕ ПЛАТЕЖИ:")
	fmt.Println("─────────────────")
	fmt.Println()

	if len(overdue) > 0 {
		fmt.Println("🔴 СРОЧНО (просрочено):")
		for _, p := range overdue {
			days := daysUntil(p.DueDate)
			amountRubles := formatRubles(p.Amount)
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
			days := daysUntil(p.DueDate)
			amountRubles := formatRubles(p.Amount)
			fmt.Printf("   • %s: %s₽ (%d дней) [%s]", p.Name, amountRubles, days, p.Type)
			if p.LedgerAccount != "" {
				fmt.Printf(" [%s]", p.LedgerAccount)
			}
			fmt.Println()
		}
		fmt.Println()
	}

	if len(upcoming) > 0 {
		fmt.Println("🟢 ОЖИДАЕМЫЕ:")
		for _, p := range upcoming {
			days := daysUntil(p.DueDate)
			amountRubles := formatRubles(p.Amount)
			fmt.Printf("   • %s: %s₽ (%d дней) [%s]", p.Name, amountRubles, days, p.Type)
			if p.LedgerAccount != "" {
				fmt.Printf(" [%s]", p.LedgerAccount)
			}
			fmt.Println()
		}
		fmt.Println()
	}

	totalRubles := formatRubles(totalAmount)
	fmt.Printf("📊 ИТОГО: %d платежей на %s₽\n", len(activePayments), totalRubles)
}

func addPayment() {
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
		fmt.Println("Ошибка: необходимо указать --name и --amount")
		addCmd.Usage()
		return
	}

	amount, err := rublesToKopecks(*amountStr)
	if err != nil {
		fmt.Printf("Ошибка: %v\n", err)
		return
	}

	var finalDueDate string
	if *days > 0 {
		finalDueDate = time.Now().AddDate(0, 0, *days).Format("2006-01-02")
	} else if *dueDate != "" {
		_, err = time.Parse("2006-01-02", *dueDate)
		if err != nil {
			fmt.Printf("Ошибка: некорректная дата. Используйте формат ГГГГ-ММ-ДД %v\n", err)
			return
		}
		finalDueDate = *dueDate
	} else {
		fmt.Printf("Ошибка: необходимо указать либо --date, либо --days\n")
		addCmd.Usage()
		return
	}

	validTypes := map[string]bool{
		"monthly":  true,
		"yearly":   true,
		"one-time": true,
	}
	if !validTypes[*paymentType] {
		fmt.Printf("Ошибка: некорректный тип. Допустимые: monthly, yearly, one-time\n")
		return
	}

	data, err := loadPayments()
	if err != nil {
		data = &PaymentsData{Payments: []Payment{}}
	}

	id := fmt.Sprintf("%s_%s_%s", strings.ToLower(strings.ReplaceAll(*name, " ", "_")), finalDueDate, *paymentType)

	newPayment := Payment{
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
	savePayments(data)

	intervalInfo := ""
	if *days > 0 {
		intervalInfo = fmt.Sprintf(" [интервал %d дней]", *days)
	}

	accountInfo := ""
	if *ledgerAccount != "" {
		accountInfo = fmt.Sprintf(" -> %s", *ledgerAccount)
	}

	amountRubles := formatRubles(amount)
	fmt.Printf("Платеж добавлен: %s - %s₽ - %s [%s]%s%s\n", *name, amountRubles, finalDueDate, *paymentType, intervalInfo, accountInfo)
}

func showLedger() {
	ledgerPath := getLedgerPath()
	if _, err := os.Stat(ledgerPath); os.IsNotExist(err) {
		fmt.Println("Ledger файл не существует")
		return
	}

	content, err := os.ReadFile(ledgerPath)
	if err != nil {
		fmt.Printf("Ошибка чтения Ledger файла: %v\n", err)
		return
	}

	lines := strings.Split(string(content), "\n")
	recentLines := lines[len(lines)-10:]
	fmt.Println("Последние записи в Ledger:")
	for _, line := range recentLines {
		if strings.TrimSpace(line) != "" {
			fmt.Println(line)
		}
	}
}

func showHelp() {
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

func main() {
	if len(os.Args) == 1 {
		displayWidget()
		return
	}

	switch os.Args[1] {
	case "paid":
		markPaid()
	case "list":
		listPayments()
	case "add":
		addPayment()
	case "ledger":
		showLedger()
	case "cleanup":
		data, err := loadPayments()
		if err != nil {
			fmt.Printf("Ошибка: %v\n", err)
			return
		}
		initialCount := len(data.Payments)

		*data = cleanupOldPayments(*data)
		savePayments(data)

		fmt.Printf("Очистка завершена. Удалено %d старых платежей\n", initialCount-len(data.Payments))
	case "help", "-h", "--help":
		showHelp()
	default:
		displayWidget()
	}
}
