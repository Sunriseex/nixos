package storage

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"

	"github.com/sunriseex/payments-cli/internal/models"
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
	if _, err := os.Stat(expandedPath); os.IsNotExist(err) {
		return &models.PaymentData{Payments: []models.Payment{}}, nil
	}
	file, err := os.ReadFile(expandedPath)
	if err != nil {
		return nil, err
	}
	var data models.PaymentData
	err = json.Unmarshal(file, &data)
	if err != nil {
		return nil, err
	}
	return &data, err
}
func SavePayments(data *models.PaymentData, dataPath string) error {
	expandedPath := ExpandPath(dataPath)
	dir := filepath.Dir(expandedPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	file, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(expandedPath, file, 0644)
}
