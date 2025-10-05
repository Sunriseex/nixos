package notifications

import (
	"fmt"
	"log/slog"
	"os/exec"
)

func SendLocalNotification(title, message string) error {
	slog.Debug("Отправка локального уведомелния", "title", title)

	cmd := exec.Command("notify-send", title, message)
	err := cmd.Run()
	if err != nil {

		slog.Error("Ошибка отправки локального уведомления",
			"title", title,
			"message", message,
			"error", err)

		return err
	}
	slog.Debug("Локальное уведомление отправлено", "title", title)
	return nil
}
func SendPaymentLocalNotification(paymentName string, days int) {

	slog.Debug("Отправка локального уведомления о платеже",
		"payment_name", paymentName,
		"days", days)

	var title, message string
	switch {
	case days < 0:
		title = "🔴 Просрочен платеж"
		message = fmt.Sprintf("%s просрочен на %d дней", paymentName, -days)
	case days == 0:
		title = "🟠 Платеж сегодня"
		message = fmt.Sprintf("%s должен быть оплачен сегодня", paymentName)
	case days <= 3:
		title = "🟡 Скоро платеж"
		message = fmt.Sprintf("%s через %d дней", paymentName, days)
	default:
		slog.Debug("Уведомелние не требуется", "payment_name", paymentName, "days", days)
		return
	}

	if err := SendLocalNotification(title, message); err != nil {
		slog.Error("Ошибка отправки уведомления о платеже",
			"payment_name", paymentName,
			"error", err)
	}

}
