package security

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"golang.org/x/sync/singleflight"
)

var fileGroup singleflight.Group

func AtomicWriteJSON(data interface{}, path string) error {

	_, err, _ := fileGroup.Do(path, func() (interface{}, error) {
		return nil, atomicWrite(data, path)
	})

	if err != nil {
		log.Printf("[DEBUG] AtomicWriteJSON: ошибка - %v", err)
	}

	return err
}

func atomicWrite(data interface{}, path string) error {

	dir := filepath.Dir(path)

	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("create directory: %v", err)
	}

	tempPath := path + ".tmp." + generateRandomSuffix()

	file, err := os.OpenFile(tempPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
	if err != nil {
		return fmt.Errorf("create temp file: %v", err)
	}
	defer os.Remove(tempPath)

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(data); err != nil {
		return fmt.Errorf("encode data: %v", err)
	}

	if err := file.Sync(); err != nil {
		return fmt.Errorf("sync file: %v", err)
	}

	if err := file.Close(); err != nil {
		return fmt.Errorf("close file: %v", err)
	}

	if err := os.Rename(tempPath, path); err != nil {
		return fmt.Errorf("atomic rename: %v", err)
	}

	return nil
}

func generateRandomSuffix() string {
	bytes := make([]byte, 8)
	rand.Read(bytes)
	return hex.EncodeToString(bytes)
}

func SafeReadJSON(path string, target interface{}) error {

	if _, err := os.Stat(path); os.IsNotExist(err) {
		return initializeEmptyFile(path, target)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read file: %v", err)
	}

	if len(data) == 0 {
		return initializeEmptyFile(path, target)
	}

	if err := json.Unmarshal(data, target); err != nil {
		return fmt.Errorf("unmarshal json: %v", err)
	}

	return nil
}

func initializeEmptyFile(path string, target interface{}) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	return AtomicWriteJSON(target, path)
}
