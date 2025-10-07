package utils

import "time"

func DaysUntil(dueDate string) int {
	if dueDate == "" {
		return 999
	}

	today := time.Now()
	due, err := time.Parse("2006-01-02", dueDate)
	if err != nil {
		return 999
	}
	return int(due.Sub(today).Hours() / 24)
}
func ParseDate(dateStr string) (time.Time, error) {
	return time.Parse("2006-01-02", dateStr)
}
func FormatDate(date time.Time) string {
	return date.Format("2006-01-02")
}
func Today() string {
	return time.Now().Format("2006-01-02")
}
func AddDays(dateStr string, months int) (string, error) {
	date, err := ParseDate(dateStr)
	if err != nil {
		return "", err
	}
	return FormatDate(date.AddDate(0, months, 0)), nil
}

func AddMonths(dateStr string, months int) (string, error) {
	date, err := ParseDate(dateStr)
	if err != nil {
		return "", err
	}
	return FormatDate(date.AddDate(0, months, 0)), nil
}
func AddYears(dateStr string, years int) (string, error) {
	date, err := ParseDate(dateStr)
	if err != nil {
		return "", err
	}
	return FormatDate(date.AddDate(years, 0, 0)), nil
}
func DaysBetween(dateStr1, dateStr2 string) int {
	date1, err1 := time.Parse("2006-01-02", dateStr1)
	date2, err2 := time.Parse("2006-01-02", dateStr2)
	if err1 != nil || err2 != nil {
		return 0
	}
	date1 = time.Date(date1.Year(), date1.Month(), date1.Day(), 0, 0, 0, 0, time.UTC)
	date2 = time.Date(date2.Year(), date2.Month(), date2.Day(), 0, 0, 0, 0, time.UTC)
	hours := date2.Sub(date1).Hours()
	return int(hours / 24)
}
