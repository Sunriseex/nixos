package notifications

import (
	"fmt"
	"os/exec"
)

func SendLocalNotification(title, message string) error {
	cmd := exec.Command("notify-send", title, message)
	return cmd.Run()
}
func SendPaymentLocalNotification(paymentName string, days int) {
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
		return
	}

	SendLocalNotification(title, message)

}
