package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

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
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get home directory: %v", err)
	}

	envPaths := []string{
		filepath.Join(home, "nixos/scripts/payments-cli/configs/.env"),
		filepath.Join(home, "nixos/scripts/payment-cli/configs/.env"),
		"./configs/.env",
		".env",
	}

	var loaded bool
	for _, envPath := range envPaths {
		if err := godotenv.Load(envPath); err == nil {
			fmt.Printf("✅ Loaded .env from: %s\n", envPath)
			loaded = true
			break
		}
	}

	if !loaded {
		fmt.Println("⚠️  No .env file found, using environment variables")
	}

	dataPath, err := expandPath(getEnv("DATA_PATH", "~/.config/waybar/payments.json"))
	if err != nil {
		return fmt.Errorf("expand data path: %v", err)
	}

	depositsDataPath, err := expandPath(getEnv("DEPOSITS_DATA_PATH", "~/.config/waybar/deposits.json"))
	if err != nil {
		return fmt.Errorf("expand deposits data path: %v", err)
	}

	ledgerPath, err := expandPath(getEnv("LEDGER_PATH", "~/ObsidianVault/finances/transactions.ledger"))
	if err != nil {
		return fmt.Errorf("expand ledger path: %v", err)
	}

	AppConfig = &Config{
		TelegramToken:    getEnv("TELEGRAM_BOT_TOKEN", ""),
		TelegramUserID:   getEnvInt64("TELEGRAM_USER_ID", 0),
		DataPath:         dataPath,
		DepositsDataPath: depositsDataPath,
		LedgerPath:       ledgerPath,
	}

	return nil
}

func expandPath(path string) (string, error) {
	if path == "" {
		return "", fmt.Errorf("path cannot be empty")
	}

	if strings.HasPrefix(path, "~/") || path == "~" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", fmt.Errorf("get home directory: %v", err)
		}

		if path == "~" {
			return home, nil
		}
		return filepath.Join(home, path[2:]), nil
	}

	return filepath.Abs(path)
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
