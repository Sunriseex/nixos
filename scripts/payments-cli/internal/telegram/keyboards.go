package telegram

import tele "gopkg.in/telebot.v4"

func MainMenu() *tele.ReplyMarkup {
	menu := &tele.ReplyMarkup{ResizeKeyboard: true}

	btnPayments := menu.Text("💳 Платежи")
	btnDeposits := menu.Text("💰 Вклады")
	btnAddPayment := menu.Text("➕ Добавить платеж")
	btnAddDeposit := menu.Text("➕ Добавить вклад")
	btnReport := menu.Text("📊 Отчёт")
	btnHelp := menu.Text("❓ Помощь")

	menu.Reply(
		menu.Row(btnPayments, btnDeposits),
		menu.Row(btnAddPayment, btnAddDeposit),
		menu.Row(btnReport, btnHelp),
	)
	return menu
}

func PaymentsMenu() *tele.ReplyMarkup {
	menu := &tele.ReplyMarkup{ResizeKeyboard: true}

	btnListPayments := menu.Text("📋 Список платежей")
	btnAddPayment := menu.Text("➕ Добавить платеж")
	btnMarkPaid := menu.Text("✅ Отметить оплаченным")
	btnMainMenu := menu.Text("🏠 Главное меню")

	menu.Reply(
		menu.Row(btnListPayments, btnAddPayment),
		menu.Row(btnMarkPaid),
		menu.Row(btnMainMenu),
	)
	return menu
}

func DepositsMenu() *tele.ReplyMarkup {
	menu := &tele.ReplyMarkup{ResizeKeyboard: true}

	btnListDeposits := menu.Text("📋 Список вкладов")
	btnAddDeposit := menu.Text("➕ Добавить вклад")
	btnTopUpDeposit := menu.Text("💵 Пополнить вклад")
	btnCalculateIncome := menu.Text("📈 Расчет дохода")
	btnMainMenu := menu.Text("🏠 Главное меню")

	menu.Reply(
		menu.Row(btnListDeposits, btnAddDeposit),
		menu.Row(btnTopUpDeposit, btnCalculateIncome),
		menu.Row(btnMainMenu),
	)
	return menu
}

func BackToMainMenu() *tele.ReplyMarkup {
	menu := &tele.ReplyMarkup{ResizeKeyboard: true}

	btnMainMenu := menu.Text("🏠 Главное меню")

	menu.Reply(
		menu.Row(btnMainMenu),
	)
	return menu
}

func CreatePaymentActions(paymentID string) *tele.ReplyMarkup {
	menu := &tele.ReplyMarkup{}
	btnMark := menu.Data("✅ Оплатить", "mark_paid", paymentID)
	btnEdit := menu.Data("✏️ Редактировать", "edit_payment", paymentID)
	btnDelete := menu.Data("🗑 Удалить", "delete_payment", paymentID)

	menu.Inline(
		menu.Row(btnMark),
		menu.Row(btnEdit, btnDelete),
	)
	return menu
}

func CreateDepositActions(depositID string) *tele.ReplyMarkup {
	menu := &tele.ReplyMarkup{}
	btnTopUp := menu.Data("💵 Пополнить", "topup_deposit", depositID)
	btnCalculate := menu.Data("📈 Расчет", "calculate_deposit", depositID)
	btnUpdate := menu.Data("🔄 Обновить", "update_deposit", depositID)

	menu.Inline(
		menu.Row(btnTopUp, btnCalculate),
		menu.Row(btnUpdate),
	)
	return menu
}
