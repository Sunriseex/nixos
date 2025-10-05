package main

import (
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/sunriseex/payments-cli/internal/commands"
	"github.com/sunriseex/payments-cli/internal/config"
	"github.com/sunriseex/payments-cli/internal/notifications"
	"github.com/sunriseex/payments-cli/internal/storage"
	"github.com/sunriseex/payments-cli/pkg/errors"
)

func main() {
	if err := config.Init(); err != nil {
		log.Fatalf("Ошибка инициализации конфигурации: %v", err)
	}

	if err := initializeDataFiles(); err != nil {
		fmt.Printf("Предупреждение: не удалось инициализировать файл данных: %v", err)
	}

	if err := notifications.Init(); err != nil {
		log.Printf("Предупреждение: ошибка инициализации Telegram: %v", err)
	}

	if len(os.Args) == 1 {
		executeDefaultCommand()
		return
	}

	if err := executeCommand(os.Args[1], os.Args[2:]); err != nil {
		userMsg := errors.GetUserFriendlyMessage(err)
		log.Printf("Ошибка: %s", userMsg)
		if appErr, ok := err.(*errors.AppError); ok && appErr.Original != nil {
			log.Printf("Детали: %s", appErr.Original)
		}

		os.Exit(1)
	}
}

func initializeDataFiles() error {
	if err := storage.InitializeDepositsFile(config.AppConfig.DepositsDataPath); err != nil {
		return fmt.Errorf("инициализация файла вкладов: %w", err)
	}
	if err := storage.InitializePaymentFile(config.AppConfig.DataPath); err != nil {
		return fmt.Errorf("инициализация файла платежей: %w", err)
	}
	return nil
}

func executeDefaultCommand() {
	if err := commands.DepositList(); err != nil {
		log.Fatal(err)
	}
	fmt.Println()
	if err := commands.DepositCheckNotifications(); err != nil {
		log.Fatal(err)
	}
}

func executeCommand(command string, args []string) error {
	switch command {
	case "list":
		return commands.DepositList()
	case "topup":
		return handleTopUpCommand(args)
	case "notifications", "check":
		return commands.DepositCheckNotifications()
	case "calculate":
		return handleCalculateCommand(args)
	case "create":
		return handleCreateCommand(args)
	case "update":
		return handleUpdateCommand(args)
	case "accrue-interest":
		return commands.DepositAccrueInterest()
	case "find":
		return handleFindCommand(args)
	case "help", "-h", "--help":
		showHelp()
		return nil
	default:
		return fmt.Errorf("неизвестная команда: %s\n\nИспользуйте 'deposit-manager help' для справки", command)
	}
}

func handleTopUpCommand(args []string) error {
	if len(args) < 2 {
		return fmt.Errorf("использование: deposit-manager topup <deposit_id> <amount>")
	}

	amount, err := commands.ParseRubles(args[1])
	if err != nil {
		return err
	}

	return commands.DepositTopUp(args[0], amount)
}

func handleCalculateCommand(args []string) error {
	if len(args) < 2 {
		return fmt.Errorf("использование: deposit-manager calculate <deposit_id> <days>")
	}

	days, err := commands.ParseDays(args[1])
	if err != nil {
		return err
	}

	return commands.DepositCalculateIncome(args[0], days)
}

func handleUpdateCommand(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("использование: deposit-manager update <deposit_id>")
	}

	return commands.DepositUpdate(args[0])
}

func handleFindCommand(args []string) error {
	if len(args) < 2 {
		return fmt.Errorf("использование: deposit-manager find <name> <bank>")
	}

	return commands.DepositFind(args[0], args[1])
}

func handleCreateCommand(args []string) error {
	if len(args) < 6 {
		showCreateUsage()
		return fmt.Errorf("недостаточно аргументов")
	}

	var createParams struct {
		name, bank, depositType, promoEndDate string
		amount                                int
		rate                                  float64
		termMonths                            int
		promoRate                             *float64
	}

	flagSet := flag.NewFlagSet("create", flag.ContinueOnError)
	flagSet.StringVar(&createParams.name, "name", "", "Название вклада")
	flagSet.StringVar(&createParams.bank, "bank", "", "Банк")
	flagSet.StringVar(&createParams.depositType, "type", "", "Тип вклада (savings|term)")
	flagSet.StringVar(&createParams.promoEndDate, "promo-end", "", "Дата окончания промо-ставки")

	var amountStr, rateStr, termStr, promoRateStr string
	flagSet.StringVar(&amountStr, "amount", "", "Сумма вклада")
	flagSet.StringVar(&rateStr, "rate", "", "Процентная ставка")
	flagSet.StringVar(&termStr, "term", "", "Срок в месяцах")
	flagSet.StringVar(&promoRateStr, "promo-rate", "", "Промо-ставка")

	if err := flagSet.Parse(args); err != nil {
		return err
	}

	if err := validateAndParseCreateParams(&createParams, amountStr, rateStr, termStr, promoRateStr); err != nil {
		return err
	}

	return commands.DepositCreate(
		createParams.name,
		createParams.bank,
		createParams.depositType,
		createParams.amount,
		createParams.rate,
		createParams.termMonths,
		createParams.promoRate,
		createParams.promoEndDate,
	)
}

func validateAndParseCreateParams(params *struct {
	name, bank, depositType, promoEndDate string
	amount                                int
	rate                                  float64
	termMonths                            int
	promoRate                             *float64
}, amountStr, rateStr, termStr, promoRateStr string) error {
	if params.name == "" {
		return fmt.Errorf("необходимо указать название вклада (--name)")
	}
	if params.bank == "" {
		return fmt.Errorf("необходимо указать банк (--bank)")
	}
	if params.depositType == "" {
		return fmt.Errorf("необходимо указать тип вклада (--type savings|term)")
	}

	amount, err := commands.ParseRubles(amountStr)
	if err != nil {
		return err
	}
	params.amount = amount

	rate, err := commands.ParseRate(rateStr)
	if err != nil {
		return err
	}
	params.rate = rate

	if params.depositType == "term" {
		term, err := commands.ParseTerm(termStr)
		if err != nil {
			return err
		}
		params.termMonths = term
	}

	if promoRateStr != "" {
		promoRate, err := commands.ParseRate(promoRateStr)
		if err != nil {
			return err
		}
		params.promoRate = &promoRate
	}

	return nil
}

func showCreateUsage() {
	fmt.Println("Использование: deposit-manager create --name <name> --bank <bank> --type <savings|term> --amount <amount> --rate <interest_rate> [--term <months>] [--promo-rate <rate> --promo-end <date>]")
	fmt.Println()
	fmt.Println("Примеры:")
	fmt.Println("  deposit-manager create --name \"Яндекс Сейв\" --bank \"Яндекс Банк\" --type savings --amount 50000 --rate 17.0")
	fmt.Println("  deposit-manager create --name \"Яндекс Срочный\" --bank \"Яндекс Банк\" --type term --amount 100000 --rate 17.0 --term 3")
	fmt.Println("  deposit-manager create --name \"Яндекс Промо\" --bank \"Яндекс Банк\" --type savings --amount 50000 --rate 12.0 --promo-rate 17.0 --promo-end 2024-12-31")
}

func showHelp() {
	fmt.Println(`Deposit Manager - Управление банковскими вкладами

Команды:
  deposit-manager                    - Показать список вкладов и уведомления
  deposit-manager list              - Показать список всех вкладов
  deposit-manager topup <id> <amount> - Пополнить вклад
  deposit-manager notifications     - Проверить уведомления по вкладам
  deposit-manager calculate <id> <days> - Рассчитать доход по вкладу
  deposit-manager create            - Создать новый вклад
  deposit-manager update <id>       - Обновить даты вклада (пролонгация)
  deposit-manager accrue-interest   - Автоматическое начисление процентов
  deposit-manager find <name> <bank> - Найти вклад по имени и банку
  deposit-manager help              - Показать эту справку

Примеры:
  deposit-manager create --name "Яндекс Сейв" --bank "Яндекс Банк" --type savings --amount 50000 --rate 17.0
  deposit-manager create --name "Яндекс Срочный" --bank "Яндекс Банк" --type term --amount 100000 --rate 17.0 --term 3
  deposit-manager accrue-interest`)
}
