package services

import (
	"time"

	"github.com/sunriseex/payments-cli/internal/config"
	"github.com/sunriseex/payments-cli/internal/models"
	"github.com/sunriseex/payments-cli/internal/storage"
	"github.com/sunriseex/payments-cli/pkg/calculator"
	"github.com/sunriseex/payments-cli/pkg/dates"
	"github.com/sunriseex/payments-cli/pkg/errors"
	"github.com/sunriseex/payments-cli/pkg/validation"
)

type DepositService struct {
	validator *validation.DepositValidator
}

func NewDepositService() *DepositService {
	return &DepositService{
		validator: validation.NewDepositValidator(),
	}
}

type CreateDepositRequest struct {
	Name         string
	Bank         string
	Type         string
	Amount       int
	InterestRate float64
	TermMonths   int
	PromoRate    *float64
	PromoEndDate string
}

type CreateDepositResponse struct {
	Deposit   *models.Deposit
	DepositID string
	Success   bool
	Message   string
}

func (s *DepositService) Create(req *CreateDepositRequest) (*CreateDepositResponse, error) {
	if err := s.validator.ValidateCreateRequest(
		req.Name, req.Bank, req.Type, req.Amount, req.InterestRate,
		req.TermMonths, req.PromoRate, req.PromoEndDate,
	); err != nil {
		return nil, errors.NewValidationError(
			"некорректные параметры вклада",
			map[string]interface{}{
				"name":          req.Name,
				"bank":          req.Bank,
				"type":          req.Type,
				"amount":        req.Amount,
				"interest_rate": req.InterestRate,
				"term_months":   req.TermMonths,
			},
		)
	}

	deposit := &models.Deposit{
		Name:           req.Name,
		Bank:           req.Bank,
		Type:           req.Type,
		Amount:         req.Amount,
		InitialAmount:  req.Amount,
		InterestRate:   req.InterestRate,
		PromoRate:      req.PromoRate,
		PromoEndDate:   req.PromoEndDate,
		StartDate:      time.Now().Format("2006-01-02"),
		AutoRenewal:    true,
		Capitalization: s.getCapitalizationType(req.Bank),
	}

	if req.Type == "term" {
		deposit.TermMonths = req.TermMonths
		endDate, err := dates.CalculateMaturityDate(deposit.StartDate, req.TermMonths)
		if err != nil {
			return nil, errors.NewCalculationError(
				"ошибка расчета даты окончания вклада",
				err,
			)
		}
		deposit.EndDate = endDate
		deposit.TopUpEndDate = dates.CalculateTopUpEndDate(deposit.StartDate)
	}

	if err := s.validator.Validate(deposit); err != nil {
		return nil, errors.NewValidationError(
			"ошибка валидации данных вклада",
			map[string]interface{}{
				"deposit_name":     deposit.Name,
				"validation_error": err.Error(),
			},
		)
	}

	if err := storage.CreateDeposit(deposit, config.AppConfig.DepositsDataPath); err != nil {
		return nil, errors.NewStorageError("создание вклада", err)
	}

	return &CreateDepositResponse{
		Deposit:   deposit,
		DepositID: deposit.ID,
		Success:   true,
		Message:   "Вклад успешно создан",
	}, nil
}

type TopUpRequest struct {
	DepositID   string
	Amount      int
	Description string
}

type TopUpResponse struct {
	Success        bool
	NewAmount      int
	PreviousAmount int
	Message        string
}

func (s *DepositService) TopUp(req *TopUpRequest) (*TopUpResponse, error) {
	if req.Amount <= 0 {
		return nil, errors.NewValidationError(
			"сумма пополнения должна быть положительной",
			map[string]interface{}{
				"amount":     req.Amount,
				"deposit_id": req.DepositID,
			},
		)
	}

	if req.Amount > 10000000 {
		return nil, errors.NewValidationError(
			"сумма пополнения слишком большая",
			map[string]interface{}{
				"amount":      req.Amount,
				"max_allowed": 10000000,
				"deposit_id":  req.DepositID,
			},
		)
	}

	deposit, err := storage.GetDepositByID(req.DepositID, config.AppConfig.DepositsDataPath)
	if err != nil {
		return nil, errors.WrapError(
			errors.ErrStorage,
			"ошибка получения данных вклада",
			err,
		)
	}

	previousAmount := deposit.Amount

	if err := storage.UpdateDepositAmount(req.DepositID, req.Amount, config.AppConfig.DepositsDataPath); err != nil {
		return nil, errors.WrapError(
			errors.ErrStorage,
			"ошибка пополнения вклада",
			err,
		)
	}

	return &TopUpResponse{
		Success:        true,
		NewAmount:      previousAmount + req.Amount,
		PreviousAmount: previousAmount,
		Message:        "Вклад успешно пополнен",
	}, nil
}

type CalculateIncomeRequest struct {
	DepositID string
	Days      int
}

type CalculateIncomeResponse struct {
	Success        bool
	DepositName    string
	Amount         float64
	InterestRate   float64
	Capitalization string
	PeriodDays     int
	ExpectedIncome float64
	TotalAmount    float64
}

func (s *DepositService) CalculateIncome(req *CalculateIncomeRequest) (*CalculateIncomeResponse, error) {
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
		return nil, errors.WrapError(
			errors.ErrStorage,
			"ошибка получения данных вклада для расчета",
			err,
		)
	}

	income := calculator.CalculateIncome(*deposit, req.Days)
	incomeFloat, _ := income.Float64()
	amountRubles := float64(deposit.Amount) / 100.0

	return &CalculateIncomeResponse{
		Success:        true,
		DepositName:    deposit.Name,
		Amount:         amountRubles,
		InterestRate:   deposit.InterestRate,
		Capitalization: deposit.Capitalization,
		PeriodDays:     req.Days,
		ExpectedIncome: incomeFloat,
		TotalAmount:    amountRubles + incomeFloat,
	}, nil
}

type UpdateDepositRequest struct {
	DepositID string
}

type UpdateDepositResponse struct {
	Success      bool
	DepositName  string
	StartDate    string
	EndDate      string
	TopUpEndDate string
	Message      string
}

func (s *DepositService) Update(req *UpdateDepositRequest) (*UpdateDepositResponse, error) {
	deposit, err := storage.GetDepositByID(req.DepositID, config.AppConfig.DepositsDataPath)
	if err != nil {
		return nil, errors.NewNotFoundError("вклад", req.DepositID)
	}

	if deposit.Type != "term" {
		return nil, errors.NewBusinessLogicError(
			"только срочные вклады могут быть обновлены (пролонгированы)",
			map[string]interface{}{
				"deposit_id":   req.DepositID,
				"deposit_type": deposit.Type,
			},
		)
	}

	if !dates.CanBeProlonged(deposit.EndDate) {
		return nil, errors.NewBusinessLogicError(
			"вклад не может быть пролонгирован в данный момент",
			map[string]interface{}{
				"deposit_id": req.DepositID,
				"end_date":   deposit.EndDate,
			},
		)
	}

	today := time.Now().Format("2006-01-02")
	deposit.StartDate = today

	endDate, err := dates.CalculateMaturityDate(today, deposit.TermMonths)
	if err != nil {
		return nil, errors.NewCalculationError(
			"ошибка расчета даты окончания при обновлении вклада",
			err,
		)
	}
	deposit.EndDate = endDate
	deposit.TopUpEndDate = dates.CalculateTopUpEndDate(today)

	if err := s.validator.Validate(deposit); err != nil {
		return nil, errors.NewValidationError(
			"ошибка валидации данных после обновления",
			map[string]interface{}{
				"deposit_name":     deposit.Name,
				"validation_error": err.Error(),
			},
		)
	}

	if err := storage.UpdateDeposit(deposit, config.AppConfig.DepositsDataPath); err != nil {
		return nil, errors.NewStorageError("обновление вклада", err)
	}

	return &UpdateDepositResponse{
		Success:      true,
		DepositName:  deposit.Name,
		StartDate:    deposit.StartDate,
		EndDate:      deposit.EndDate,
		TopUpEndDate: deposit.TopUpEndDate,
		Message:      "Вклад успешно обновлен",
	}, nil
}

type ListDepositsResponse struct {
	Success     bool
	Deposits    []models.Deposit
	TotalCount  int
	TotalAmount int
	Message     string
}

func (s *DepositService) List() (*ListDepositsResponse, error) {
	data, err := storage.LoadDeposits(config.AppConfig.DepositsDataPath)
	if err != nil {
		return nil, errors.NewStorageError("загрузка списка вкладов", err)
	}

	totalAmount := 0
	for _, deposit := range data.Deposits {
		totalAmount += deposit.Amount
	}

	return &ListDepositsResponse{
		Success:     true,
		Deposits:    data.Deposits,
		TotalCount:  len(data.Deposits),
		TotalAmount: totalAmount,
		Message:     "Список вкладов успешно загружен",
	}, nil
}

type GetDepositRequest struct {
	DepositID string
}

type GetDepositResponse struct {
	Success bool
	Deposit *models.Deposit
	Message string
}

func (s *DepositService) Get(req *GetDepositRequest) (*GetDepositResponse, error) {
	deposit, err := storage.GetDepositByID(req.DepositID, config.AppConfig.DepositsDataPath)
	if err != nil {
		return nil, errors.NewNotFoundError("вклад", req.DepositID)
	}

	return &GetDepositResponse{
		Success: true,
		Deposit: deposit,
		Message: "Вклад найден",
	}, nil
}

type FindDepositRequest struct {
	Name string
	Bank string
}

type FindDepositResponse struct {
	Success bool
	Deposit *models.Deposit
	Found   bool
	Message string
}

func (s *DepositService) Find(req *FindDepositRequest) (*FindDepositResponse, error) {
	deposit, err := storage.FindDepositByNameAndBank(req.Name, req.Bank, config.AppConfig.DepositsDataPath)
	if err != nil {
		return nil, errors.NewStorageError("поиск вклада", err)
	}

	if deposit == nil {
		return &FindDepositResponse{
			Success: true,
			Deposit: nil,
			Found:   false,
			Message: "Вклад не найден",
		}, nil
	}

	return &FindDepositResponse{
		Success: true,
		Deposit: deposit,
		Found:   true,
		Message: "Вклад найден",
	}, nil
}

func (s *DepositService) getCapitalizationType(bank string) string {
	if bank == "Яндекс Банк" || bank == "Yandex" {
		return "daily"
	}
	return "daily"
}
