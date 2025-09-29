package notifications

import (
	"fmt"
	"time"

	"github.com/sunriseex/payments-cli/internal/models"
	"github.com/sunriseex/payments-cli/pkg/calculator"
)

func CheckDepositNotifications(deposits []models.Deposit) []string {
	var notifications []string
	today := time.Now()
	for _, deposit := range deposits {
		if deposit.PromoEndDate != "" {
			promoEnd, err := time.Parse("2006-01-02", deposit.PromoEndDate)
			if err == nil {
				daysUntilPromoEnd := int(promoEnd.Sub(today).Hours() / 24)

				if daysUntilPromoEnd == 7 {
					notifications = append(notifications,
						fmt.Sprintf("🟡 По вкладу '%s' до окончания акционной ставки осталось 7 дней", deposit.Name))
				} else if daysUntilPromoEnd == 3 {
					notifications = append(notifications,
						fmt.Sprintf("🟠 По вкладу '%s' до окончания акционной ставки осталось 3 дня", deposit.Name))
				} else if daysUntilPromoEnd == 1 {
					notifications = append(notifications,
						fmt.Sprintf("🔴 По вкладу '%s' акционная ставка заканчивается завтра!", deposit.Name))
				}
			}
		}
		if deposit.Type == "term" && deposit.EndDate != "" {
			endDate, err := time.Parse("2006-01-02", deposit.EndDate)
			if err == nil {
				daysUntilEnd := int(endDate.Sub(today).Hours() / 24)

				if daysUntilEnd == 30 {
					income := calculator.CalculateIncome(deposit, 30)
					notifications = append(notifications,
						fmt.Sprintf("📅 Срочный вклад '%s' заканчивается через 30 дней. Ожидаемый доход: %.2f руб.",
							deposit.Name, income))
				} else if daysUntilEnd <= 7 && daysUntilEnd > 0 {
					notifications = append(notifications,
						fmt.Sprintf("⏰ Вклад '%s' заканчивается через %d дней", deposit.Name, daysUntilEnd))
				}
			}
		}
		if deposit.TopUpEndDate != "" {
			topUpEnd, err := time.Parse("2006-01-02", deposit.TopUpEndDate)
			if err == nil {
				daysUntilTopUpEnd := int(topUpEnd.Sub(today).Hours() / 24)

				if daysUntilTopUpEnd == 3 {
					notifications = append(notifications,
						fmt.Sprintf("💳 По вкладу '%s' период пополнения заканчивается через 3 дня", deposit.Name))
				} else if daysUntilTopUpEnd == 1 {
					notifications = append(notifications,
						fmt.Sprintf("💰 Последний день пополнения вклада '%s'!", deposit.Name))
				}
			}
		}
	}
	return notifications
}

func SendDepositNotification(title, message string) {
	SendLocalNotification(title, message)
	SendTelegramNotification(fmt.Sprintf("%s: %s", title, message))
}
