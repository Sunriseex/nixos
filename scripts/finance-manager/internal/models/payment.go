// Package models contains data models for payments-manager application
package models

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
type PaymentData struct {
	Payments []Payment `json:"payments"`
}
