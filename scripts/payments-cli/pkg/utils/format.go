package utils

import (
	"fmt"
	"strconv"
	"strings"
)

func FormatRubles(kopecks int) string {
	rubles := float64(kopecks) / 100.0
	return fmt.Sprintf("%.2f", rubles)
}
func RublesToKopecks(rublesStr string) (int, error) {
	rublesStr = strings.Replace(rublesStr, ",", ".", -1)

	amount, err := strconv.ParseFloat(rublesStr, 64)
	if err != nil {
		return 0, fmt.Errorf("неверный формат суммы: %v", err)
	}

	return int(amount * 100), nil
}

func TruncateString(str string, length int) string {
	if len(str) <= length {
		return str
	}
	return str[:length] + "..."
}
