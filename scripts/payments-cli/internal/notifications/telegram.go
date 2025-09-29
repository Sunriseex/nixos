package notifications

import (
	"fmt"
	"log"
	"time"

	telebot "gopkg.in/telebot.v4"

	"github.com/sunriseex/payments-cli/internal/config"
)

var bot *telebot.Bot

func Init() error {
	if config.AppConfig.TelegramToken == "" {
		return nil
	}

	pref := telebot.Settings{
		Token:  config.AppConfig.TelegramToken,
		Poller: &telebot.LongPoller{Timeout: 10 * time.Second},
	}

	var err error
	bot, err = telebot.NewBot(pref)
	return err
}

func SendTelegramNotification(message string) {
	if bot == nil || config.AppConfig.TelegramUserID == 0 {
		return
	}

	user := &telebot.User{ID: config.AppConfig.TelegramUserID}
	_, err := bot.Send(user, message)
	if err != nil {
		log.Printf("Ошибка отправки в Telegram: %v", err)
	}
}

func SendPaymentReminder(paymentName string, amount int, daysUntilDue int) {
	amountRubles := float64(amount) / 100.0
	var urgency string

	if daysUntilDue < 0 {
		urgency = "🔴 ПРОСРОЧЕНО"
	} else if daysUntilDue == 0 {
		urgency = "🟠 СЕГОДНЯ"
	} else if daysUntilDue <= 3 {
		urgency = "🟡 СКОРО"
	} else {
		urgency = "🟢 ОЖИДАЕТСЯ"
	}

	message := fmt.Sprintf(
		"%s\n💳 %s\n💰 %.2f руб.\n⏰ %d дней",
		urgency, paymentName, amountRubles, daysUntilDue,
	)

	SendTelegramNotification(message)
}
