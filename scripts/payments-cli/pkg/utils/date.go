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
