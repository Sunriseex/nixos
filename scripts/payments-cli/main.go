package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"time"
)

type Payment struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Amount      int    `json:"amount"`
	DueDate     string `json:"due_date"`
	PaymentDate string `json:"payment_date,omitempty"`
}

type PaymentsData struct {
	Payments []Payment `json:"payments"`
}

func getDataPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config/waybar/payments.json")
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
	return &data, err
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

func daysUntil(dueDate string) int {
	today := time.Now()
	due, err := time.Parse("2006-01-02", dueDate)
	if err != nil {
		return 999
	}
	return int(due.Sub(today).Hours() / 24)
}

func formatAmount(amount int) string {
	if amount >= 1000 {
		return fmt.Sprintf("%d.%02d", amount/100, amount%100)
	}
	return fmt.Sprintf("%d", amount)
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

func displayWidget() {
	payment := getNearestPayment()
	if payment == nil {
		fmt.Println("💳 Нет платежей")
		return
	}
	days := daysUntil(payment.DueDate)
	amount := formatAmount(payment.Amount)
	name := payment.Name
	if len(name) > 12 {
		name = name[:12] + "…"
	}
	status := fmt.Sprintf("%dд", days)
	if days < 0 {
		status = fmt.Sprintf("%dд", days)
	}
	fmt.Printf("💳 %s %s₽ · %s\n", name, amount, status)
}

func markPaid() {
	data, err := loadPayments()
	if err != nil {
		return
	}
	payment := getNearestPayment()
	if payment == nil {
		fmt.Println("Нет активных платежей")
		return
	}
	today := time.Now().Format("2006-01-02")
	for i := range data.Payments {
		if data.Payments[i].ID == payment.ID {
			data.Payments[i].PaymentDate = today
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
	for _, p := range data.Payments {
		if p.PaymentDate == "" {
			activePayments = append(activePayments, p)
		}
	}
	if len(activePayments) == 0 {
		fmt.Println("Нет активных платежей")
		return
	}
	sort.Slice(activePayments, func(i, j int) bool {
		return daysUntil(activePayments[i].DueDate) < daysUntil(activePayments[j].DueDate)
	})
	for _, p := range activePayments {
		days := daysUntil(p.DueDate)
		fmt.Printf("• %s: %d₽ (%dд)\n", p.Name, p.Amount, days)
	}
}

func addPayment(name string, amountStr string, dueDate string) {
	amount := 0
	fmt.Sscanf(amountStr, "%d", &amount)

	_, err := time.Parse("2006-01-02", dueDate)
	if err != nil {
		fmt.Printf("Ошибка: некорректная дата\n")
		return
	}

	data, err := loadPayments()
	if err != nil {
		data = &PaymentsData{Payments: []Payment{}}
	}

	id := fmt.Sprintf("%s_%s", name, dueDate)
	newPayment := Payment{
		ID:      id,
		Name:    name,
		Amount:  amount,
		DueDate: dueDate,
	}

	data.Payments = append(data.Payments, newPayment)
	savePayments(data)
	fmt.Printf("Платеж добавлен: %s - %d₽ - %s\n", name, amount, dueDate)
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
		if len(os.Args) != 5 {
			fmt.Println("Использование: payments-cli add <name> <amount> <date>")
			return
		}
		addPayment(os.Args[2], os.Args[3], os.Args[4])
	default:
		displayWidget()
	}
}
