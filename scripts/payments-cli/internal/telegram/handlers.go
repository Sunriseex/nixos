package telegram

import (
	"fmt"
	"log/slog"
	"strings"

	tele "gopkg.in/telebot.v4"
)

func (b *Bot) handleStart(c tele.Context) error {
	user := c.Sender()

	slog.Info("User started bot",
		"user_id", user.ID,
		"username", user.Username,
		"first_name", user.FirstName)

	welcomeMsg := fmt.Sprintf(
		"👋 Добро пожаловать, %s!\n\n"+
			"Я помогу вам управлять финансами:\n"+
			"• 💳 Управление платежами\n"+
			"• 💰 Управление вкладами\n"+
			"• 📊 Финансовые отчёты\n\n"+
			"Выберите действие:",
		user.FirstName,
	)

	return c.Send(welcomeMsg, MainMenu())
}

func (b *Bot) handleHelp(c tele.Context) error {
	helpMsg := `📖 *Помощь по боту*

*Основные команды:*
/start - Главное меню
/help - Эта справка
/payments - Управление платежами  
/deposits - Управление вкладами
/report - Получить отчёт

*Возможности:*
• Добавление и управление платежами
• Создание и пополнение вкладов
• Расчет доходности вкладов
• Автоматические напоминания
• Регулярные отчёты

Для начала работы выберите действие в главном меню.`

	return c.Send(helpMsg, BackToMainMenu())
}

func (b *Bot) handleMainMenu(c tele.Context) error {
	return c.Send("🏠 Главное меню", MainMenu())
}

func (b *Bot) handlePayments(c tele.Context) error {
	menu := PaymentsMenu()
	msg := `💳 *Управление платежами*

Выберите действие:
• 📋 Список платежей - просмотр всех активных платежей
• ➕ Добавить платеж - создать новый платеж
• ✅ Отметить оплаченным - отметить ближайший платеж как оплаченный`

	return c.Send(msg, menu)
}

func (b *Bot) handleDeposits(c tele.Context) error {
	menu := DepositsMenu()
	msg := `💰 *Управление вкладами*

Выберите действие:
• 📋 Список вкладов - просмотр всех активных вкладов
• ➕ Добавить вклад - создать новый вклад
• 💵 Пополнить вклад - увеличить сумму вклада
• 📈 Расчет дохода - рассчитать ожидаемый доход`

	return c.Send(msg, menu)
}

func (b *Bot) handleReport(c tele.Context) error {
	msg := `📊 *Функция отчётов*

В разработке...
Скоро здесь будут доступны:
• Еженедельные отчёты
• Ежемесячная статистика
• Анализ расходов и доходов`

	return c.Send(msg, BackToMainMenu())
}

func (b *Bot) handleAddPaymentStart(c tele.Context) error {
	b.states.SetState(c.Sender().ID, StateAddingPayment, nil)

	msg := `💳 *Добавление платежа*

Введите название платежа:`

	return c.Send(msg, BackToMainMenu())
}

func (b *Bot) handleAddDepositStart(c tele.Context) error {
	b.states.SetState(c.Sender().ID, StateAddingDeposit, nil)

	msg := `💰 *Добавление вклада*

Введите название вклада:`

	return c.Send(msg, BackToMainMenu())
}

func (b *Bot) handleText(c tele.Context) error {
	userID := c.Sender().ID
	text := c.Text()

	slog.Debug("Processing text message",
		"user_id", userID,
		"text", text,
		"trimmed", strings.TrimSpace(text))

	state, exists := b.states.GetState(userID)
	if exists {
		slog.Debug("User has active state", "state", state.CurrentState)
		return b.handleStateInput(c, text, state)
	}

	trimmedText := strings.TrimSpace(text)

	slog.Debug("Checking text against known commands", "trimmed_text", trimmedText)

	switch trimmedText {
	case "💳 Платежи":
		slog.Debug("Handling Payments command")
		return b.handlePayments(c)
	case "💰 Вклады":
		slog.Debug("Handling Deposits command")
		return b.handleDeposits(c)
	case "➕ Добавить платеж":
		slog.Debug("Handling Add Payment command")
		return b.handleAddPaymentStart(c)
	case "➕ Добавить вклад":
		slog.Debug("Handling Add Deposit command")
		return b.handleAddDepositStart(c)
	case "📊 Отчёт":
		slog.Debug("Handling Report command")
		return b.handleReport(c)
	case "❓ Помощь":
		slog.Debug("Handling Help command")
		return b.handleHelp(c)
	case "📋 Список платежей":
		slog.Debug("Handling List Payments command")
		return b.handleListPayments(c)
	case "✅ Отметить оплаченным":
		slog.Debug("Handling Mark Paid command")
		return b.handleMarkPaid(c)
	case "📋 Список вкладов":
		slog.Debug("Handling List Deposits command")
		return b.handleListDeposits(c)
	case "💵 Пополнить вклад":
		slog.Debug("Handling Top Up Deposit command")
		return b.handleTopUpDepositStart(c)
	case "📈 Расчет дохода":
		slog.Debug("Handling Calculate Income command")
		return b.handleCalculateIncomeStart(c)
	case "🏠 Главное меню":
		slog.Debug("Handling Main Menu command")
		return b.handleMainMenu(c)
	default:
		slog.Debug("Unknown command, showing main menu", "received_text", trimmedText)
		return c.Send("Неизвестная команда. Используйте меню ниже:", MainMenu())
	}
}

func (b *Bot) handleStateInput(c tele.Context, text string, state *UserState) error {
	switch state.CurrentState {
	case StateAddingPayment:
		return b.handlePaymentNameInput(c, text)
	case StateAddingDeposit:
		return b.handleDepositNameInput(c, text)
	case StateWaitingForAmount:
		return b.handleAmountInput(c, text)
	case StateWaitingForDate:
		return b.handleDateInput(c, text)
	default:
		b.states.ClearState(c.Sender().ID)
		slog.Warn("Unknown state cleared", "user_id", c.Sender().ID, "state", state.CurrentState)
		return c.Send("Неизвестное состояние. Возврат в главное меню:", MainMenu())
	}
}

func (b *Bot) handleListPayments(c tele.Context) error {
	// TODO: Реализовать получение списка платежей
	msg := `📋 *Список платежей*

Функция в разработке...
Скоро здесь будет отображаться список всех активных платежей.`

	return c.Send(msg, PaymentsMenu())
}

func (b *Bot) handleMarkPaid(c tele.Context) error {
	// TODO: Реализовать отметку платежа как оплаченного
	msg := `✅ *Отметить оплаченным*

Функция в разработке...
Скоро здесь можно будет отметить ближайший платеж как оплаченный.`

	return c.Send(msg, PaymentsMenu())
}

func (b *Bot) handleListDeposits(c tele.Context) error {
	// TODO: Реализовать получение списка вкладов
	msg := `📋 *Список вкладов*

Функция в разработке...
Скоро здесь будет отображаться список всех активных вкладов.`

	return c.Send(msg, DepositsMenu())
}

func (b *Bot) handleTopUpDepositStart(c tele.Context) error {
	// TODO: Реализовать пополнение вклада
	msg := `💵 *Пополнение вклада*

Функция в разработке...
Скоро здесь можно будет пополнить выбранный вклад.`

	return c.Send(msg, DepositsMenu())
}

func (b *Bot) handleCalculateIncomeStart(c tele.Context) error {
	// TODO: Реализовать расчет дохода
	msg := `📈 *Расчет дохода*

Функция в разработке...
Скоро здесь можно будет рассчитать ожидаемый доход по вкладу.`

	return c.Send(msg, DepositsMenu())
}

func (b *Bot) handlePaymentNameInput(c tele.Context, name string) error {
	b.states.UpdateStateData(c.Sender().ID, "name", name)
	b.states.SetState(c.Sender().ID, StateWaitingForAmount, nil)

	msg := `💳 *Добавление платежа*

Название: ` + name + `

Теперь введите сумму платежа (например: 1500.50):`

	return c.Send(msg, BackToMainMenu())
}

func (b *Bot) handleDepositNameInput(c tele.Context, name string) error {
	b.states.UpdateStateData(c.Sender().ID, "name", name)
	b.states.SetState(c.Sender().ID, StateWaitingForAmount, nil)

	msg := `💰 *Добавление вклада*

Название: ` + name + `

Теперь введите сумму вклада (например: 50000):`

	return c.Send(msg, BackToMainMenu())
}

func (b *Bot) handleAmountInput(c tele.Context, amount string) error {
	b.states.UpdateStateData(c.Sender().ID, "amount", amount)
	b.states.SetState(c.Sender().ID, StateWaitingForDate, nil)

	state, _ := b.states.GetState(c.Sender().ID)
	name := ""
	if state.Data["name"] != nil {
		name = state.Data["name"].(string)
	}

	var msg string
	if state.CurrentState == StateAddingPayment {
		msg = `💳 *Добавление платежа*

Название: ` + name + `
Сумма: ` + amount + ` руб.

Теперь введите дату (ГГГГ-ММ-ДД) или количество дней:`
	} else {
		msg = `💰 *Добавление вклада*

Название: ` + name + `
Сумма: ` + amount + ` руб.

Теперь введите дату (ГГГГ-ММ-ДД) или количество дней:`
	}

	return c.Send(msg, BackToMainMenu())
}

func (b *Bot) handleDateInput(c tele.Context, date string) error {
	state, _ := b.states.GetState(c.Sender().ID)
	name := ""
	amount := ""
	if state.Data["name"] != nil {
		name = state.Data["name"].(string)
	}
	if state.Data["amount"] != nil {
		amount = state.Data["amount"].(string)
	}

	b.states.ClearState(c.Sender().ID)

	var msg string
	if state.CurrentState == StateAddingPayment {
		msg = `💳 *Платеж добавлен!*

Данные получены:
• Название: ` + name + `
• Сумма: ` + amount + ` руб.
• Дата: ` + date + `

Функция сохранения в разработке...`
	} else {
		msg = `💰 *Вклад добавлен!*

Данные получены:
• Название: ` + name + `
• Сумма: ` + amount + ` руб.
• Дата: ` + date + `

Функция сохранения в разработке...`
	}

	return c.Send(msg, MainMenu())
}
