package storage

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/sunriseex/payments-cli/internal/models"
	"github.com/sunriseex/payments-cli/pkg/errors"
	"github.com/sunriseex/payments-cli/pkg/security"
)

func ExpandPath(path string) string {
	if strings.HasPrefix(path, "~/") {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, path[2:])
	}
	return path
}

func LoadPayments(dataPath string) (*models.PaymentData, error) {
	expandedPath := ExpandPath(dataPath)
	var data models.PaymentData

	if err := security.SafeReadJSON(expandedPath, &data); err != nil {
		return nil, errors.NewStorageError("чтение файла платежей", err)
	}

	if data.Payments == nil {
		data.Payments = []models.Payment{}
	}

	return &data, nil
}

func SavePayments(data *models.PaymentData, dataPath string) error {
	expandedPath := ExpandPath(dataPath)
	if err := security.AtomicWriteJSON(data, expandedPath); err != nil {
		return errors.NewStorageError("сохранение платежей", err)
	}
	return nil
}

func InitializeDepositsFile(dataPath string) error {
	expandedPath := ExpandPath(dataPath)
	if _, err := os.Stat(expandedPath); os.IsNotExist(err) {
		initialData := &models.DepositsData{
			Deposits: []models.Deposit{},
		}
		return security.AtomicWriteJSON(initialData, expandedPath)
	}
	return nil
}

func InitializePaymentFile(dataPath string) error {
	expandedPath := ExpandPath(dataPath)
	if _, err := os.Stat(expandedPath); os.IsNotExist(err) {
		initialData := &models.PaymentData{
			Payments: []models.Payment{},
		}
		return security.AtomicWriteJSON(initialData, expandedPath)
	}
	return nil
}
