package main

import (
	"fmt"
	"log"
	"os"

	"github.com/sunriseex/payments-cli/internal/commands"
	"github.com/sunriseex/payments-cli/internal/config"
	"github.com/sunriseex/payments-cli/internal/notifications"
)

func main() {
	if err := config.Init(); err != nil {
		log.Fatalf("Ошибка инициализации конфигурации: %v", err)
	}

	if err := notifications.Init(); err != nil {
		log.Printf("Предупреждение: ошибка инициализации Telegram: %v", err)
	}

	if len(os.Args) == 1 {
		if err := commands.DepositList(); err != nil {
			log.Fatal(err)
		}
		fmt.Println()
		if err := commands.DepositCheckNotifications(); err != nil {
			log.Fatal(err)
		}
		return
	}

	switch os.Args[1] {
	case "list":
		if err := commands.DepositList(); err != nil {
			log.Fatal(err)
		}
	case "topup":
		if len(os.Args) < 4 {
			log.Fatal("Использование: deposit-manager topup <deposit_id> <amount> [description]")
		}
		amount, err := parseAmount(os.Args[3])
		if err != nil {
			log.Fatalf("Неверная сумма: %v", err)
		}

		if err := commands.DepositTopUp(os.Args[2], amount); err != nil {
			log.Fatal(err)
		}
	case "notifications", "check":
		if err := commands.DepositCheckNotifications(); err != nil {
			log.Fatal(err)
		}
	case "calculate":
		if len(os.Args) < 4 {
			log.Fatal("Использование: deposit-manager calculate <deposit_id> <days>")
		}
		days, err := parseDays(os.Args[3])
		if err != nil {
			log.Fatalf("Неверное количество дней: %v", err)
		}
		if err := commands.DepositCalculateIncome(os.Args[2], days); err != nil {
			log.Fatal(err)
		}
	case "create":
		if len(os.Args) < 8 {
			showCreateUsage()
			os.Exit(1)
		}
		if err := handleDepositCreate(os.Args[2:]); err != nil {
			log.Fatal(err)
		}
	case "update":
		if len(os.Args) < 3 {
			log.Fatal("Использование: deposit-manager update <deposit_id>")
		}
		if err := commands.DepositUpdate(os.Args[2]); err != nil {
			log.Fatal(err)
		}
	case "accrue-interest":
		if err := commands.DepositAccrueInterest(); err != nil {
			log.Fatal(err)
		}
	case "help", "-h", "--help":
		showHelp()
	default:
		fmt.Printf("Неизвестная команда: %s\n\n", os.Args[1])
		showHelp()
		os.Exit(1)
	}
}

func parseAmount(amountStr string) (int, error) {
	amount, err := commands.ParseRubles(amountStr)
	if err != nil {
		return 0, fmt.Errorf("неверный формат суммы: %v", err)
	}
	return amount, nil
}

func parseDays(daysStr string) (int, error) {
	days, err := commands.ParseDays(daysStr)
	if err != nil {
		return 0, fmt.Errorf("неверный формат дней: %v", err)
	}
	return days, nil
}

func handleDepositCreate(args []string) error {
	var name, bank, depositType, promoEndDate string
	var amount int
	var rate float64
	var termMonths int
	var promoRate *float64

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--name":
			if i+1 < len(args) {
				name = args[i+1]
				i++
			}
		case "--bank":
			if i+1 < len(args) {
				bank = args[i+1]
				i++
			}
		case "--type":
			if i+1 < len(args) {
				depositType = args[i+1]
				i++
			}
		case "--amount":
			if i+1 < len(args) {
				amt, err := parseAmount(args[i+1])
				if err != nil {
					return err
				}
				amount = amt
				i++
			}
		case "--rate":
			if i+1 < len(args) {
				r, err := parseRate(args[i+1])
				if err != nil {
					return err
				}
				rate = r
				i++
			}
		case "--term":
			if i+1 < len(args) {
				term, err := parseTerm(args[i+1])
				if err != nil {
					return err
				}
				termMonths = term
				i++
			}
		case "--promo-rate":
			if i+1 < len(args) {
				pr, err := parseRate(args[i+1])
				if err != nil {
					return err
				}
				promoRate = &pr
				i++
			}
		case "--promo-end":
			if i+1 < len(args) {
				promoEndDate = args[i+1]
				i++
			}
		}
	}

	if name == "" {
		return fmt.Errorf("необходимо указать название вклада (--name)")
	}
	if bank == "" {
		return fmt.Errorf("необходимо указать банк (--bank)")
	}
	if depositType == "" {
		return fmt.Errorf("необходимо указать тип вклада (--type savings|term)")
	}
	if amount <= 0 {
		return fmt.Errorf("необходимо указать положительную сумму (--amount)")
	}
	if rate <= 0 {
		return fmt.Errorf("необходимо указать положительную процентную ставку (--rate)")
	}

	if depositType == "term" && termMonths <= 0 {
		return fmt.Errorf("для срочного вклада необходимо указать срок в месяцах (--term)")
	}

	if promoRate != nil && promoEndDate == "" {
		return fmt.Errorf("при указании промо-ставки необходимо указать дату окончания (--promo-end)")
	}

	return commands.DepositCreate(name, bank, depositType, amount, rate, termMonths, promoRate, promoEndDate)
}

func parseRate(rateStr string) (float64, error) {
	rate, err := commands.ParseRate(rateStr)
	if err != nil {
		return 0, fmt.Errorf("неверный формат процентной ставки: %v", err)
	}
	return rate, nil
}

func parseTerm(termStr string) (int, error) {
	term, err := commands.ParseTerm(termStr)
	if err != nil {
		return 0, fmt.Errorf("неверный формат срока: %v", err)
	}
	return term, nil
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
  deposit-manager topup <id> <amount> [desc] - Пополнить вклад
  deposit-manager notifications     - Проверить уведомления по вкладам
  deposit-manager calculate <id> <days> - Рассчитать доход по вкладу
  deposit-manager create            - Создать новый вклад
  deposit-manager update <id>       - Обновить даты вклада (пролонгация)
  deposit-manager accrue-interest   - Автоматическое начисление процентов
  deposit-manager help              - Показать эту справку

Примеры:
  deposit-manager create --name "Яндекс Сейв" --bank "Яндекс Банк" --type savings --amount 50000 --rate 17.0
  deposit-manager create --name "Яндекс Срочный" --bank "Яндекс Банк" --type term --amount 100000 --rate 17.0 --term 3
  deposit-manager accrue-interest`)
}
