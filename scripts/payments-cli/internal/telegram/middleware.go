package telegram

import (
	"log/slog"
	"time"

	tele "gopkg.in/telebot.v4"
)

func (b *Bot) loggingMiddleware(next tele.HandlerFunc) tele.HandlerFunc {
	return func(c tele.Context) error {
		start := time.Now()
		user := c.Sender()
		slog.Debug("Telegram request received",
			"user_id", user.ID,
			"username", user.Username,
			"text", c.Text(),
			"update_id", c.Update().ID)
		err := next(c)
		duration := time.Since(start)
		if err != nil {
			slog.Error("Telegram handler failed",
				"user_id", user.ID,
				"duration", duration,
				"error", err)

		} else {
			slog.Debug("Telegram handle completed",
				"user_id", user.ID,
				"duration", duration)
		}
		return err
	}
}
