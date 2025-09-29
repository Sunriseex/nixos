package storage

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/sunriseex/payments-cli/internal/models"
)

func RecordPaymentToLedger(payment models.Payment, ledgerPath string) error {
	expandedPath := ExpandPath(ledgerPath)
	dir := filepath.Dir(expandedPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	file, err := os.OpenFile(expandedPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer file.Close()
	today := time.Now().Format("2006-01-02")
	amount := fmt.Sprintf("₽%.2f", float64(payment.Amount)/100.0)
	expenseAccount := "Expenses:Subcriptions"
	if payment.Category != "" {
		expenseAccount = "Expenses:" + payment.Category
	}
	paymentAccount := payment.LedgerAccount
	if paymentAccount == "" {
		paymentAccount = "Liabilities:YandexPay"
	}
	entry := fmt.Sprintf("%s %s\n %-40s %s\n %s\n\n",
		today, payment.Name, expenseAccount, amount, paymentAccount,
	)
	_, err = file.WriteString(entry)
	return err
}

func RecordDepositToLedger(deposit models.Deposit, operationType string, amount int, description string, ledgerPath string) error {
	expandedPath := ExpandPath(ledgerPath)
	dir := filepath.Dir(expandedPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	file, err := os.OpenFile(expandedPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer file.Close()

	today := time.Now().Format("2006-01-02")
	amountRubles := fmt.Sprintf("₽%.2f", float64(amount)/100.0)

	var creditAccount, debitAccount string

	switch operationType {
	case "create":
		creditAccount = "Assets:Current"
		debitAccount = fmt.Sprintf("Assets:Deposits:%s", formatAccountName(deposit.Name))
		description = fmt.Sprintf("Открытие вклада: %s", deposit.Name)
	case "topup":
		creditAccount = "Assets:Current"
		debitAccount = fmt.Sprintf("Assets:Deposits:%s", formatAccountName(deposit.Name))
		if description == "" {
			description = fmt.Sprintf("Пополнение вклада: %s", deposit.Name)
		}
	case "interest":
		creditAccount = fmt.Sprintf("Income:Interest:%s", formatAccountName(deposit.Bank))
		debitAccount = fmt.Sprintf("Assets:Deposits:%s", formatAccountName(deposit.Name))
		description = fmt.Sprintf("Начисление процентов по вкладу: %s", deposit.Name)
	default:
		return fmt.Errorf("unknown deposit operation type: %s", operationType)
	}

	entry := fmt.Sprintf("%s %s\n %-40s %s\n %-40s %s\n\n",
		today, description,
		debitAccount, amountRubles,
		creditAccount, "-"+amountRubles,
	)

	_, err = file.WriteString(entry)
	return err
}

func formatAccountName(name string) string {
	reg, _ := regexp.Compile("[^a-zA-Z0-9а-яА-Я]+")
	safeName := reg.ReplaceAllString(name, "_")
	return strings.Trim(safeName, "_")
}
