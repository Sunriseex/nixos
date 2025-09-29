package config

import (
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	TelegramToken    string
	TelegramUserID   int64
	DataPath         string
	DepositsDataPath string
	LedgerPath       string
}

var AppConfig *Config

func Init() error {
	godotenv.Load("~/scripts/payments-cli/configs/.env")

	AppConfig = &Config{
		TelegramToken:    getEnv("TELEGRAM_BOT_TOKEN", ""),
		TelegramUserID:   getEnvInt64("TELEGRAM_USER_ID", 0),
		DataPath:         getEnv("DATA_PATH", "~/.config/waybar/payments.json"),
		DepositsDataPath: getEnv("DEPOSITS_DATA_PATH", "~/.config/waybar/deposits.json"),
		LedgerPath:       getEnv("LEDGER_PATH", "~/ObsidianVault/finances/transactions.ledger"),
	}

	return nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt64(key string, defaultValue int64) int64 {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.ParseInt(value, 10, 64); err == nil {
			return intValue
		}
	}
	return defaultValue
}
