package telegram

import (
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/robfig/cron/v3"
	tele "gopkg.in/telebot.v4"

	"github.com/sunriseex/payments-cli/internal/config"
	"github.com/sunriseex/payments-cli/internal/services"
)

type Bot struct {
	bot       *tele.Bot
	services  *Services
	states    *StateManager
	scheduler *cron.Cron
	mu        sync.RWMutex
	isRunning bool
}

type Services struct {
	Deposits *services.DepositService
	Payments *services.PaymentService
	Interest *services.InterestService
}

func NewBot(services *Services) (*Bot, error) {
	if config.AppConfig.TelegramToken == "" {
		return nil, fmt.Errorf("telegram token not configured")
	}

	pref := tele.Settings{
		Token:  config.AppConfig.TelegramToken,
		Poller: &tele.LongPoller{Timeout: 10 * time.Second},
	}

	bot, err := tele.NewBot(pref)
	if err != nil {
		return nil, fmt.Errorf("create bot: %w", err)
	}

	tgBot := &Bot{
		bot:       bot,
		services:  services,
		states:    NewStateManager(),
		scheduler: cron.New(),
		isRunning: false,
	}

	return tgBot, nil
}

func (b *Bot) Start() error {
	slog.Info("Starting Telegram bot",
		"token_length", len(config.AppConfig.TelegramToken),
		"user_id", config.AppConfig.TelegramUserID)

	// Регистрируем обработчики
	b.registerHandlers()
	b.registerMiddleware()

	// Запускаем планировщик
	b.startScheduler()

	// Запускаем бота
	b.mu.Lock()
	b.isRunning = true
	b.mu.Unlock()

	go func() {
		b.bot.Start()

		b.mu.Lock()
		b.isRunning = false
		b.mu.Unlock()

		slog.Info("Telegram bot stopped")
	}()

	slog.Info("Telegram bot started successfully")
	return nil
}

func (b *Bot) Stop() {
	slog.Info("Stopping Telegram bot")

	b.mu.Lock()
	defer b.mu.Unlock()

	if b.scheduler != nil {
		b.scheduler.Stop()
	}

	if b.bot != nil {
		b.bot.Stop()
	}

	b.isRunning = false
	slog.Info("Telegram bot stopped")
}

func (b *Bot) IsRunning() bool {
	b.mu.RLock()
	defer b.mu.RUnlock()
	return b.isRunning
}

func (b *Bot) registerHandlers() {
	// Команды
	b.bot.Handle("/start", b.handleStart)
	b.bot.Handle("/help", b.handleHelp)
	b.bot.Handle("/payments", b.handlePayments)
	b.bot.Handle("/deposits", b.handleDeposits)
	b.bot.Handle("/report", b.handleReport)

	// Обработка текстовых сообщений (reply-кнопок и ввода)
	b.bot.Handle(tele.OnText, b.handleText)

	slog.Debug("Telegram bot handlers registered", "handlers_count", 5)
}

func (b *Bot) registerMiddleware() {
	// Middleware для логирования
	b.bot.Use(b.loggingMiddleware)
}

func (b *Bot) startScheduler() {
	// Здесь позже добавим регулярные отчёты
	b.scheduler.Start()
}

func (b *Bot) SendMessage(userID int64, text string) error {
	user := &tele.User{ID: userID}
	_, err := b.bot.Send(user, text)
	return err
}
