package storage

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/sunriseex/payments-cli/internal/models"
)

func LoadDeposits(dataPath string) (*models.DepositsData, error) {
	expandedPath := ExpandPath(dataPath)
	if _, err := os.Stat(expandedPath); os.IsNotExist(err) {
		return &models.DepositsData{Deposits: []models.Deposit{}}, nil
	}
	file, err := os.ReadFile(expandedPath)
	if err != nil {
		return nil, fmt.Errorf("error read file: %v", err)
	}
	var depositsData models.DepositsData
	if err := json.Unmarshal(file, &depositsData); err != nil {
		return nil, fmt.Errorf("error parse JSON: %v", err)
	}
	return &depositsData, nil
}

func SaveDeposit(data models.DepositsData, dataPath string) error {
	expandedPath := ExpandPath(dataPath)
	dir := filepath.Dir(expandedPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("error creating dir: %v", err)
	}
	file, err := json.MarshalIndent(data, "", " ")
	if err != nil {
		return fmt.Errorf("error serialize JSON: %v", err)
	}
	if err := os.WriteFile(expandedPath, file, 0644); err != nil {
		return fmt.Errorf("error write file: %v", err)
	}
	return nil
}

func CreateDeposit(deposit *models.Deposit, dataPath string) error {
	data, err := LoadDeposits(dataPath)
	if err != nil {
		return fmt.Errorf("error load deposits while create: %v", err)
	}
	now := time.Now()
	deposit.CreatedAt = now
	deposit.UpdatedAt = now
	if deposit.ID == "" {
		deposit.ID = generateDepositID(deposit.Name)
	}
	data.Deposits = append(data.Deposits, *deposit)
	return SaveDeposit(*data, dataPath)
}

func UpdateDepositAmount(depositID string, amount int, dataPath string) error {
	data, err := LoadDeposits(dataPath)
	if err != nil {
		return fmt.Errorf("error loading deposits while update: %w", err)
	}
	for i := range data.Deposits {
		if data.Deposits[i].ID == depositID {
			data.Deposits[i].Amount += amount
			data.Deposits[i].UpdatedAt = time.Now()
			return SaveDeposit(*data, dataPath)
		}
	}
	return fmt.Errorf("deposit with ID %s not found", depositID)
}

func UpdateDeposit(updatedDeposit *models.Deposit, dataPath string) error {
	data, err := LoadDeposits(dataPath)
	if err != nil {
		return fmt.Errorf("error loading deposits while update: %w", err)
	}

	found := false
	for i := range data.Deposits {
		if data.Deposits[i].ID == updatedDeposit.ID {
			created := data.Deposits[i].CreatedAt
			data.Deposits[i] = *updatedDeposit
			data.Deposits[i].CreatedAt = created
			data.Deposits[i].UpdatedAt = time.Now()
			found = true
			break
		}
	}

	if !found {
		return fmt.Errorf("deposit with ID %s not found", updatedDeposit.ID)
	}

	return SaveDeposit(*data, dataPath)
}

func GetDepositByID(depositID string, dataPath string) (*models.Deposit, error) {
	data, err := LoadDeposits(dataPath)
	if err != nil {
		return nil, fmt.Errorf("error loading deposits: %w", err)
	}

	for _, deposit := range data.Deposits {
		if deposit.ID == depositID {
			return &deposit, nil
		}
	}

	return nil, fmt.Errorf("deposit with ID %s not found", depositID)
}

func FindDepositByNameAndBank(name, bank string, dataPath string) (*models.Deposit, error) {
	data, err := LoadDeposits(dataPath)
	if err != nil {
		return nil, fmt.Errorf("error loading deposits: %w", err)
	}

	for i := range data.Deposits {
		if data.Deposits[i].Name == name && data.Deposits[i].Bank == bank {
			return &data.Deposits[i], nil
		}
	}

	return nil, nil
}

func generateDepositID(name string) string {
	base := strings.ToLower(strings.ReplaceAll(name, " ", "-"))
	return fmt.Sprintf("%s-%d", base, time.Now().Unix())
}
