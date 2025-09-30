package storage

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/sunriseex/payments-cli/internal/models"
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
		return nil, err
	}

	if data.Payments == nil {
		data.Payments = []models.Payment{}
	}

	return &data, nil
}

func SavePayments(data *models.PaymentData, dataPath string) error {
	expandedPath := ExpandPath(dataPath)
	return security.AtomicWriteJSON(data, expandedPath)
}
