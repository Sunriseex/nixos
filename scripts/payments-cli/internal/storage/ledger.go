package storage

import (
	"fmt"
	"os"
	"path/filepath"
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
	today := time.Now().Format("2006/01/02")
	amount := fmt.Sprintf("₽%.2f", float64(payment.Amount)/100.0)
	expenseAccount := "e:Subcriptions"
	if payment.Category != "" {
		expenseAccount = "e:" + payment.Category
	}
	paymentAccount := payment.LedgerAccount
	if paymentAccount == "" {
		paymentAccount = "l:YandexPay"
	}
	entry := fmt.Sprintf("%s %s\n  %s %s\n  %s\n\n",
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

	today := time.Now().Format("2006/01/02")
	amountRubles := fmt.Sprintf("₽%.2f", float64(amount)/100.0)

	var creditAccount, debitAccount string
	bankShort := formatBankNameForLedger(deposit.Bank)

	switch operationType {
	case "create":
		creditAccount = fmt.Sprintf("b:%s", bankShort)
		debitAccount = fmt.Sprintf("b:%s:Savings", bankShort)
		if description == "" {
			description = fmt.Sprintf("Открытие вклада %s", deposit.Name)
		}
	case "topup":
		creditAccount = fmt.Sprintf("b:%s", bankShort)
		debitAccount = fmt.Sprintf("b:%s:Savings", bankShort)
		if description == "" {
			description = fmt.Sprintf("Пополнение вклада %s", deposit.Name)
		}
	case "interest":
		creditAccount = "i:Interest:Bank"
		debitAccount = fmt.Sprintf("b:%s:Savings", bankShort)
		if description == "" {
			description = "Выплата процентов"
		}
	default:
		return fmt.Errorf("unknown deposit operation type: %s", operationType)
	}

	entry := fmt.Sprintf("%s %s\n  %s %s\n  %s\n\n",
		today, description,
		debitAccount, amountRubles,
		creditAccount,
	)

	_, err = file.WriteString(entry)
	return err
}

func formatBankNameForLedger(bank string) string {
	switch bank {
	case "Яндекс Банк", "Yandex":
		return "Yandex"
	case "Альфа Банк", "Alfa":
		return "AlfaBank"
	case "Тинькофф", "Tinkoff":
		return "Tbank"
	default:
		safeName := strings.ReplaceAll(bank, " ", "")
		safeName = strings.ReplaceAll(safeName, "-", "")
		return safeName
	}
}
