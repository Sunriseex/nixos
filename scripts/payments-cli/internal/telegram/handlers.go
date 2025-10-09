package telegram

import (
	"fmt"
	"log/slog"
	"strconv"
	"strings"
	"time"

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
	b.states.SetState(c.Sender().ID, StateAddingPaymentName, nil)

	msg := `💳 *Добавление платежа*

Введите название платежа:`

	return c.Send(msg, BackToMainMenu())
}

func (b *Bot) handleText(c tele.Context) error {
	userID := c.Sender().ID
	text := c.Text()

	slog.Debug("Processing text message",
		"user_id", userID,
		"text", text,
		"trimmed", strings.TrimSpace(text))

	if b.isCancellationRequest(text) {
		b.states.ClearState(userID)
		return c.Send("❌ Операция отменена. Возврат в главное меню.", MainMenu())
	}

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

func (b *Bot) isCancellationRequest(text string) bool {
	return strings.TrimSpace(text) == "❌ Отмена" ||
		strings.TrimSpace(text) == "/cancel" ||
		strings.ToLower(strings.TrimSpace(text)) == "отмена"
}

func (b *Bot) handleStateInput(c tele.Context, text string, state *UserState) error {
	switch state.CurrentState {
	case StateAddingPaymentName:
		return b.handlePaymentNameInput(c, text)
	case StateAddingPaymentAmount:
		return b.handlePaymentAmountInput(c, text)
	case StateAddingPaymentDate:
		return b.handlePaymentDateInput(c, text)
	case StateAddingPaymentType:
		return b.handlePaymentTypeInput(c, text)
	case StateAddingPaymentCategory:
		return b.handlePaymentCategoryInput(c, text)
	case StateAddingPaymentConfirm:
		return b.handlePaymentConfirmation(c, text)
	case StateAddingDepositName:
		return b.handleDepositNameInput(c, text)
	default:
		b.states.ClearState(c.Sender().ID)
		slog.Warn("Unknown state cleared", "user_id", c.Sender().ID, "state", state.CurrentState)
		return c.Send("Неизвестное состояние. Возврат в главное меню:", MainMenu())
	}
}

func (b *Bot) handlePaymentConfirmation(c tele.Context, confirmation string) error {
	switch strings.TrimSpace(confirmation) {
	case "✅ Да, добавить":
		return b.savePayment(c)
	case "✏️ Редактировать":
		return b.startPaymentEditing(c)
	default:
		return c.Send("Пожалуйста, выберите действие:", CancelMenu())
	}
}

func (b *Bot) savePayment(c tele.Context) error {
	state, _ := b.states.GetState(c.Sender().ID)
	name := getStringFromState(state, "name")
	amount := getStringFromState(state, "amount")
	b.states.ClearState(c.Sender().ID)
	msg := `✅ *Платеж добавлен!*

💳 ` + name + ` на ` + amount + ` руб.

Данные получены и готовы к сохранению. Реальная интеграция с системой будет в следующем обновлении.`

	return c.Send(msg, MainMenu())
}

func (b *Bot) startPaymentEditing(c tele.Context) error {
	b.states.SetState(c.Sender().ID, StateAddingDepositName, nil)
	return c.Send("Редактирование платежа. Введите новое название:", CancelMenu())
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
	name = strings.TrimSpace(name)
	if name == "" {
		return c.Send("❌ Название не может быть пустым. Введите название платежа:", CancelMenu())
	}
	if len(name) > 100 {
		return c.Send("❌ Название слишком длинное (макс. 100 символов). Введите другое название:", CancelMenu())
	}

	b.states.UpdateStateData(c.Sender().ID, "name", name)
	b.states.SetState(c.Sender().ID, StateAddingPaymentAmount, nil)

	msg := `💳 *Добавление платежа*

Название: ` + name + `

Теперь введите сумму платежа (например: 1500.50):`

	return c.Send(msg, CancelMenu())
}

func (b *Bot) handleDepositNameInput(c tele.Context, name string) error {
	b.states.UpdateStateData(c.Sender().ID, "name", name)
	b.states.SetState(c.Sender().ID, StateAddingDepositName, nil)

	msg := `💰 *Добавление вклада*

Название: ` + name + `

Теперь введите сумму вклада (например: 50000):`

	return c.Send(msg, BackToMainMenu())
}

func (b *Bot) handlePaymentAmountInput(c tele.Context, amountStr string) error {

	amountStr = strings.Replace(amountStr, ",", ".", -1)
	amount, err := strconv.ParseFloat(amountStr, 64)
	if err != nil {
		return c.Send("❌ Неверный формат суммы. Введите число (например: 1500.50):", CancelMenu())
	}
	if amount <= 0 {
		return c.Send("❌ Сумма должна быть положительной. Введите сумму:", CancelMenu())
	}

	if amount > 1000000 {
		return c.Send("❌ Сумма слишком большая (макс. 1,000,000 руб). Введите другую сумму:", CancelMenu())
	}

	b.states.UpdateStateData(c.Sender().ID, "amount", amount)
	b.states.SetState(c.Sender().ID, StateAddingPaymentDate, nil)

	state, _ := b.states.GetState(c.Sender().ID)
	name := ""
	if state.Data["name"] != nil {
		name = state.Data["name"].(string)
	}

	msg := `💳 *Добавление платежа*

Название: ` + name + `
Сумма: ` + amountStr + ` руб.

Теперь введите дату (ГГГГ-ММ-ДД) или количество дней:`

	return c.Send(msg, CancelMenu())
}

func (b *Bot) handlePaymentDateInput(c tele.Context, dateInput string) error {

	dateInput = strings.TrimSpace(dateInput)
	var finalDate string
	_, err := time.Parse("2006-01-02", dateInput)
	if err == nil {
		finalDate = dateInput
	} else {
		days, err := strconv.Atoi(dateInput)
		if err != nil || days <= 0 {
			return c.Send("❌ Неверный формат даты. Введите дату (ГГГГ-ММ-ДД) или количество дней:", CancelMenu())
		}
		finalDate = time.Now().AddDate(0, 0, days).Format("2006-01-02")
	}
	b.states.UpdateStateData(c.Sender().ID, "date", finalDate)

	state, _ := b.states.GetState(c.Sender().ID)
	name := ""
	amount := ""
	if state.Data["name"] != nil {
		name = state.Data["name"].(string)
	}
	if state.Data["amount"] != nil {
		amount = state.Data["amount"].(string)
	}

	msg := `💳 *Платеж добавлен!*

Данные получены:
• Название: ` + name + `
• Сумма: ` + amount + ` руб.
• Дата: ` + finalDate + `

Теперь выберите тип платежа:`

	menu := &tele.ReplyMarkup{ResizeKeyboard: true}
	btnOneTime := menu.Text("🔄 Разовый")
	btnMonthly := menu.Text("📅 Ежемесячный")
	btnYearly := menu.Text("🎄 Ежегодный")
	btnCancel := menu.Text("❌ Отмена")

	menu.Reply(menu.Row(btnOneTime, btnMonthly),
		menu.Row(btnYearly),
		menu.Row(btnCancel),
	)
	b.states.SetState(c.Sender().ID, StateAddingPaymentType, nil)
	return c.Send(msg, menu)
}

func (b *Bot) handlePaymentTypeInput(c tele.Context, paymentType string) error {
	var typeCode string
	switch strings.TrimSpace(paymentType) {
	case "🔄 Разовый":
		typeCode = "one-time"
	case "📅 Ежемесячный":
		typeCode = "monthly"
	case "🎄 Ежегодный":
		typeCode = "yearly"
	default:
		return c.Send("❌ Пожалуйста, выберите тип платежа из предложенных вариантов:", CancelMenu())
	}
	b.states.UpdateStateData(c.Sender().ID, "type", typeCode)
	b.states.SetState(c.Sender().ID, StateAddingPaymentCategory, nil)

	msg := `💳 *Добавление платежа*

Выберите категорию платежа (или введите свою):`

	menu := &tele.ReplyMarkup{ResizeKeyboard: true}
	btnSubscriptions := menu.Text("📱 Подписки")
	btnUtilities := menu.Text("🏠 Коммунальные")
	btnFood := menu.Text("🍕 Еда")
	btnTransport := menu.Text("🚗 Транспорт")
	btnSkip := menu.Text("⏩ Пропустить")
	btnCancel := menu.Text("❌ Отмена")

	menu.Reply(
		menu.Row(btnSubscriptions, btnUtilities),
		menu.Row(btnFood, btnTransport),
		menu.Row(btnSkip, btnCancel),
	)
	return c.Send(msg, menu)
}

func (b *Bot) handlePaymentCategoryInput(c tele.Context, category string) error {
	var finalCategory string
	switch strings.TrimSpace(category) {
	case "📱 Подписки":
		finalCategory = "subscriptions"
	case "🏠 Коммунальные":
		finalCategory = "utilities"
	case "🍕 Еда":
		finalCategory = "food"
	case "🚗 Транспорт":
		finalCategory = "transport"
	case "⏩ Пропустить":
		finalCategory = ""
	default:
		finalCategory = category
	}
	if len(finalCategory) > 50 {
		return c.Send("❌ Название категории слишком длинное (макс. 50 символов). Введите другую категорию:", CancelMenu())
	}
	b.states.UpdateStateData(c.Sender().ID, "category", finalCategory)
	return b.showPaymentConfirmation(c)
}
func (b *Bot) showPaymentConfirmation(c tele.Context) error {

	state, _ := b.states.GetState(c.Sender().ID)
	name := getStringFromState(state, "name")
	amount := getStringFromState(state, "amount")
	date := getStringFromState(state, "date")
	paymentType := getStringFromState(state, "type")
	category := getStringFromState(state, "category")
	var typeDisplay string
	switch paymentType {
	case "one-time":
		typeDisplay = "🔄 Разовый"
	case "monthly":
		typeDisplay = "📅 Ежемесячный"
	case "yearly":
		typeDisplay = "🎄 Ежегодный"
	default:
		typeDisplay = paymentType
	}
	var categoryDisplay string
	if category == "" {
		categoryDisplay = "Не указана"
	} else {
		categoryDisplay = category
	}
	msg := `💳 *Подтверждение добавления платежа*

📋 *Сводка:*
• *Название:* ` + name + `
• *Сумма:* ` + amount + ` руб.
• *Дата:* ` + date + `
• *Тип:* ` + typeDisplay + `
• *Категория:* ` + categoryDisplay + `

Всё верно?`

	menu := &tele.ReplyMarkup{ResizeKeyboard: true}
	btnConfirm := menu.Text("✅ Да, добавить")
	btnEdit := menu.Text("✏️ Редактировать")
	btnCancel := menu.Text("❌ Отмена")

	menu.Reply(
		menu.Row(btnConfirm, btnEdit),
		menu.Row(btnCancel),
	)
	b.states.SetState(c.Sender().ID, StateAddingPaymentConfirm, nil)
	return c.Send(msg, menu)
}
func getStringFromState(state *UserState, key string) string {
	if state.Data[key] != nil {
		return state.Data[key].(string)
	}
	return ""
}
