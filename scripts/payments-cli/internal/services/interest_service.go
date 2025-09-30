package services

import (
	"fmt"
	"time"

	"github.com/sunriseex/payments-cli/internal/config"
	"github.com/sunriseex/payments-cli/internal/models"
	"github.com/sunriseex/payments-cli/internal/storage"
	"github.com/sunriseex/payments-cli/pkg/calculator"
	"github.com/sunriseex/payments-cli/pkg/errors"
)

type InterestService struct{}

func NewInterestService() *InterestService {
	return &InterestService{}
}

type AccrueInterestRequest struct {
}

type AccrualResult struct {
	DepositID   string
	DepositName string
	Income      float64
	Success     bool
	Error       error
}

type AccrueInterestResponse struct {
	Success      bool
	TotalAccrued float64
	SuccessCount int
	ErrorCount   int
	Results      []AccrualResult
	Message      string
}

func (s *InterestService) AccrueInterest(req *AccrueInterestRequest) (*AccrueInterestResponse, error) {
	data, err := storage.LoadDeposits(config.AppConfig.DepositsDataPath)
	if err != nil {
		return nil, errors.NewStorageError("загрузка вкладов для начисления процентов", err)
	}

	response := &AccrueInterestResponse{
		Results: make([]AccrualResult, 0),
	}

	for _, deposit := range data.Deposits {
		result := s.processDepositAccrual(deposit)
		response.Results = append(response.Results, result)

		if result.Success {
			response.TotalAccrued += result.Income
			response.SuccessCount++
		} else {
			response.ErrorCount++
		}
	}

	response.Success = response.ErrorCount == 0
	if response.SuccessCount > 0 {
		response.Message = fmt.Sprintf("Начислено процентов: %.2f руб. по %d вкладам", response.TotalAccrued, response.SuccessCount)
	} else {
		response.Message = "Не найдено вкладов для начисления процентов"
	}

	return response, nil
}

func (s *InterestService) processDepositAccrual(deposit models.Deposit) AccrualResult {
	income, description := s.calculateDailyInterest(deposit)
	if income <= 0 {
		return AccrualResult{
			DepositID:   deposit.ID,
			DepositName: deposit.Name,
			Income:      0,
			Success:     false,
			Error:       errors.NewBusinessLogicError("нет дохода для начисления", nil),
		}
	}

	amountKopecks := int(income * 100)

	if err := storage.RecordDepositToLedger(deposit, "interest", amountKopecks, description, config.AppConfig.LedgerPath); err != nil {
		return AccrualResult{
			DepositID:   deposit.ID,
			DepositName: deposit.Name,
			Income:      income,
			Success:     false,
			Error: errors.WrapError(
				errors.ErrStorage,
				fmt.Sprintf("ошибка записи в ledger для вклада '%s'", deposit.Name),
				err,
			),
		}
	}

	if err := storage.UpdateDepositAmount(deposit.ID, amountKopecks, config.AppConfig.DepositsDataPath); err != nil {
		return AccrualResult{
			DepositID:   deposit.ID,
			DepositName: deposit.Name,
			Income:      income,
			Success:     false,
			Error: errors.WrapError(
				errors.ErrStorage,
				fmt.Sprintf("ошибка обновления суммы вклада '%s'", deposit.Name),
				err,
			),
		}
	}

	return AccrualResult{
		DepositID:   deposit.ID,
		DepositName: deposit.Name,
		Income:      income,
		Success:     true,
		Error:       nil,
	}
}

func (s *InterestService) calculateDailyInterest(deposit models.Deposit) (float64, string) {
	switch deposit.Type {
	case "savings":
		income := calculator.CalculateIncome(deposit, 1)
		incomeFloat, _ := income.Float64()
		return incomeFloat, "Ежедневная выплата процентов"
	case "term":
		if calculator.IsDepositExpired(deposit) {
			daysPassed := s.daysSince(deposit.StartDate)
			if daysPassed > 0 {
				income := calculator.CalculateIncome(deposit, daysPassed)
				incomeFloat, _ := income.Float64()
				return incomeFloat, "Выплата процентов по окончании срока"
			}
		}
	}
	return 0, ""
}

func (s *InterestService) daysSince(startDate string) int {
	start, err := time.Parse("2006-01-02", startDate)
	if err != nil {
		return 0
	}
	days := int(time.Since(start).Hours() / 24)
	if days < 0 {
		return 0
	}
	return days
}

type CalculateProjectedIncomeRequest struct {
	DepositID string
	Days      int
}

type CalculateProjectedIncomeResponse struct {
	Success         bool
	DepositName     string
	Amount          float64
	InterestRate    float64
	PeriodDays      int
	ProjectedIncome float64
	TotalAmount     float64
	Message         string
}

func (s *InterestService) CalculateProjectedIncome(req *CalculateProjectedIncomeRequest) (*CalculateProjectedIncomeResponse, error) {
	if req.Days <= 0 {
		return nil, errors.NewValidationError(
			"период расчета должен быть положительным",
			map[string]interface{}{
				"days": req.Days,
			},
		)
	}

	deposit, err := storage.GetDepositByID(req.DepositID, config.AppConfig.DepositsDataPath)
	if err != nil {
		return nil, errors.NewNotFoundError("вклад", req.DepositID)
	}

	income := calculator.CalculateIncome(*deposit, req.Days)
	incomeFloat, _ := income.Float64()
	amountRubles := float64(deposit.Amount) / 100.0

	return &CalculateProjectedIncomeResponse{
		Success:         true,
		DepositName:     deposit.Name,
		Amount:          amountRubles,
		InterestRate:    deposit.InterestRate,
		PeriodDays:      req.Days,
		ProjectedIncome: incomeFloat,
		TotalAmount:     amountRubles + incomeFloat,
		Message:         "Расчет projected income выполнен успешно",
	}, nil
}
