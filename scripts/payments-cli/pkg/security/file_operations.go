package security

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"golang.org/x/sync/singleflight"
)

var fileGroup singleflight.Group

func AtomicWriteJSON(data interface{}, path string) error {
	_, err, _ := fileGroup.Do(path, func() (interface{}, error) {
		return nil, atomicWrite(data, path)
	})
	return err
}

func atomicWrite(data interface{}, path string) error {
	tempPath := path + ".tmp." + generateRandomSuffix()

	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return fmt.Errorf("create directory: %v", err)
	}

	file, err := os.OpenFile(tempPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0600)
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
	file.Close()

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
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("read file: %v", err)
	}

	if err := json.Unmarshal(data, target); err != nil {
		return fmt.Errorf("unmarshal json: %v", err)
	}

	return nil
}
