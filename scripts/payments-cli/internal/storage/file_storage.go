package storage

import (
	"log/slog"
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

	slog.Debug("Загрузка платежей из файла", "path", dataPath)

	expandedPath := ExpandPath(dataPath)
	var data models.PaymentData

	if err := security.SafeReadJSON(expandedPath, &data); err != nil {
		slog.Error("Ошибка чтения файла платежей", "path", expandedPath, "error", err)
		return nil, errors.NewStorageError("чтение файла платежей", err)
	}

	if data.Payments == nil {
		data.Payments = []models.Payment{}
	}
	slog.Debug("Платежи загружены", "count", len(data.Payments))
	return &data, nil
}

func SavePayments(data *models.PaymentData, dataPath string) error {

	slog.Debug("Сохранение платежей", "count", len(data.Payments), "path", dataPath)

	expandedPath := ExpandPath(dataPath)
	if err := security.AtomicWriteJSON(data, expandedPath); err != nil {
		slog.Error("Ошибка сохранения платежей", "path", expandedPath, "error", err)
		return errors.NewStorageError("сохранение платежей", err)
	}

	slog.Debug("Платежи успешно сохранены", "count", len(data.Payments))

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
