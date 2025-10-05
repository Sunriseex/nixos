package storage

import (
	"log/slog"
	"os"
	"time"

	"github.com/google/uuid"

	"github.com/sunriseex/payments-cli/internal/models"
	"github.com/sunriseex/payments-cli/pkg/errors"
	"github.com/sunriseex/payments-cli/pkg/security"
)

func generateDepositID() string {
	return uuid.New().String()
}

func CreateDeposit(deposit *models.Deposit, dataPath string) error {

	slog.Debug("Создание вклада в хранилище", "name", deposit.Name, "path", dataPath)

	data, err := LoadDeposits(dataPath)
	if err != nil {
		if os.IsNotExist(err) {
			data = &models.DepositsData{
				Deposits: []models.Deposit{},
			}
		} else {
			return errors.WrapError(
				errors.ErrStorage,
				"ошибка загрузки вкладов при создании",
				err,
			)
		}
	}

	now := time.Now()
	deposit.CreatedAt = now
	deposit.UpdatedAt = now

	if deposit.ID == "" {
		deposit.ID = generateDepositID()
	}

	for _, existingDeposit := range data.Deposits {
		if existingDeposit.Name == deposit.Name && existingDeposit.Bank == deposit.Bank {
			return errors.NewValidationError(
				"вклад с таким названием уже существует в этом банке",
				map[string]interface{}{
					"name": deposit.Name,
					"bank": deposit.Bank,
				},
			)
		}
	}

	data.Deposits = append(data.Deposits, *deposit)

	if err := SaveDeposit(*data, dataPath); err != nil {
		return err
	}

	return nil
}

func LoadDeposits(dataPath string) (*models.DepositsData, error) {
	slog.Debug("Загрузка вкладов из файла", "path", dataPath)

	expandedPath := ExpandPath(dataPath)
	var data models.DepositsData

	if err := security.SafeReadJSON(expandedPath, &data); err != nil {

		slog.Error("Ошибка чтения файла вкладов",
			"path", expandedPath,
			"error", err)

		return nil, errors.NewStorageError("чтение файла вкладов", err)
	}

	if data.Deposits == nil {
		data.Deposits = []models.Deposit{}
	}
	slog.Debug("Вклады загружены", "count", len(data.Deposits))
	return &data, nil
}

func SaveDeposit(data models.DepositsData, dataPath string) error {

	slog.Debug("Сохранение вкладов", "count", len(data.Deposits), "path", dataPath)

	expandedPath := ExpandPath(dataPath)

	if err := security.AtomicWriteJSON(data, expandedPath); err != nil {
		return errors.NewStorageError("сохранение вкладов", err)
	}

	return nil
}

func UpdateDepositAmount(depositID string, amount int, dataPath string) error {

	slog.Debug("Обновление суммы вклада", "deposit_id", depositID, "amount", amount)

	data, err := LoadDeposits(dataPath)
	if err != nil {

		slog.Error("Ошибка загрузки вкладов при обновлении суммы",
			"deposit_id", depositID,
			"error", err)

		return errors.WrapError(
			errors.ErrStorage,
			"ошибка загрузки вкладов при обновлении суммы",
			err,
		)
	}

	found := false
	for i := range data.Deposits {
		if data.Deposits[i].ID == depositID {
			newAmount := data.Deposits[i].Amount + amount
			if newAmount < 0 {

				slog.Error("Недостаточно средств на вкладе",
					"deposit_id", depositID,
					"current_amount", data.Deposits[i].Amount,
					"requested_change", amount,
					"resulting_amount", newAmount)

				return errors.NewBusinessLogicError(
					"недостаточно средств на вкладе",
					map[string]interface{}{
						"deposit_id":       depositID,
						"current_amount":   data.Deposits[i].Amount,
						"requested_change": amount,
						"resulting_amount": newAmount,
					},
				)
			}

			data.Deposits[i].Amount = newAmount
			data.Deposits[i].UpdatedAt = time.Now()
			found = true
			slog.Debug("Сумма вклада обновлена",
				"deposit_id", depositID,
				"previous_amount", data.Deposits[i].Amount-amount,
				"new_amount", newAmount)

			break
		}
	}

	if !found {
		slog.Warn("Вклад не найден для обновления суммы", "deposit_id", depositID)
		return errors.NewNotFoundError("вклад", depositID)
	}

	return SaveDeposit(*data, dataPath)
}

func UpdateDeposit(updatedDeposit *models.Deposit, dataPath string) error {
	data, err := LoadDeposits(dataPath)
	if err != nil {
		return errors.WrapError(
			errors.ErrStorage,
			"ошибка загрузки вкладов при обновлении",
			err,
		)
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
		return errors.NewNotFoundError("вклад", updatedDeposit.ID)
	}

	return SaveDeposit(*data, dataPath)
}

func GetDepositByID(depositID string, dataPath string) (*models.Deposit, error) {

	slog.Debug("Поиск вклада по ID", "deposit_id", depositID)

	data, err := LoadDeposits(dataPath)
	if err != nil {

		slog.Error("Ошибка загрузки вкладов при поиске по ID",
			"deposit_id", depositID,
			"error", err)

		return nil, errors.WrapError(
			errors.ErrStorage,
			"ошибка загрузки вкладов при поиске по ID",
			err,
		)
	}

	for _, deposit := range data.Deposits {
		if deposit.ID == depositID {

			slog.Debug("Вклад найден", "deposit_id", depositID, "name", deposit.Name)

			return &deposit, nil
		}
	}
	slog.Warn("Вклад не найден", "deposit_id", depositID)
	return nil, errors.NewNotFoundError("вклад", depositID)
}

func FindDepositByNameAndBank(name, bank string, dataPath string) (*models.Deposit, error) {

	slog.Debug("Поиск вклада по имени и банку", "name", name, "bank", bank)

	data, err := LoadDeposits(dataPath)
	if err != nil {

		slog.Error("Ошибка загрузки вкладов при поиске по имени и банку",
			"name", name,
			"bank", bank,
			"error", err)

		return nil, errors.WrapError(
			errors.ErrStorage,
			"ошибка загрузки вкладов при поиске по имени и банку",
			err,
		)
	}

	for i := range data.Deposits {
		if data.Deposits[i].Name == name && data.Deposits[i].Bank == bank {
			slog.Debug("Вклад найден по имени и банку", "name", name, "bank", bank)
			return &data.Deposits[i], nil
		}
	}
	slog.Debug("Вклад не найден по имени и банку", "name", name, "bank", bank)
	return nil, nil
}
