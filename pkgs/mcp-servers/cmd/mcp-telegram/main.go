package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
)

func telegramAPI(method string, params map[string]string) (map[string]any, error) {
	token := os.Getenv("TELEGRAM_BOT_TOKEN")
	if token == "" {
		return nil, fmt.Errorf("TELEGRAM_BOT_TOKEN not set")
	}
	apiURL := fmt.Sprintf("https://api.telegram.org/bot%s/%s", token, method)
	vals := url.Values{}
	for k, v := range params {
		vals.Set(k, v)
	}
	resp, err := http.PostForm(apiURL, vals)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	var result map[string]any
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("invalid JSON: %s", string(body))
	}
	return result, nil
}

func main() {
	s := server.NewMCPServer(
		"mcp-telegram",
		"1.0.0",
		server.WithToolCapabilities(true),
	)

	s.AddTool(mcp.NewTool("telegram_send_message",
		mcp.WithDescription("Send a text message via Telegram bot. Requires TELEGRAM_BOT_TOKEN in env."),
		mcp.WithString("chat_id", mcp.Required(), mcp.Description("Target chat ID, channel username, or user ID")),
		mcp.WithString("text", mcp.Required(), mcp.Description("Message text (max 4096 chars, Markdown supported)")),
		mcp.WithString("parse_mode", mcp.Description("Parse mode: Markdown or HTML")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		params := map[string]string{
			"chat_id": req.Params.Arguments["chat_id"].(string),
			"text":    req.Params.Arguments["text"].(string),
		}
		if pm, ok := req.Params.Arguments["parse_mode"].(string); ok && pm != "" {
			params["parse_mode"] = pm
		}
		result, err := telegramAPI("sendMessage", params)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Telegram API error: %v", err)), nil
		}
		jsonBytes, _ := json.MarshalIndent(result, "", "  ")
		return mcp.NewToolResultText(string(jsonBytes)), nil
	})

	s.AddTool(mcp.NewTool("telegram_get_updates",
		mcp.WithDescription("Get recent updates/messages from the Telegram bot. Use for debugging."),
		mcp.WithNumber("limit", mcp.Description("Max number of updates (default 10, max 100)")),
		mcp.WithNumber("timeout", mcp.Description("Long polling timeout in seconds (default 0, no wait)")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		params := map[string]string{}
		if limit, ok := req.Params.Arguments["limit"].(float64); ok {
			params["limit"] = fmt.Sprintf("%d", int(limit))
		}
		if timeout, ok := req.Params.Arguments["timeout"].(float64); ok {
			params["timeout"] = fmt.Sprintf("%d", int(timeout))
		}
		result, err := telegramAPI("getUpdates", params)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Telegram API error: %v", err)), nil
		}
		jsonBytes, _ := json.MarshalIndent(result, "", "  ")
		return mcp.NewToolResultText(string(jsonBytes)), nil
	})

	s.AddTool(mcp.NewTool("telegram_get_me",
		mcp.WithDescription("Get info about the bot itself (username, ID). Use to verify token."),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		result, err := telegramAPI("getMe", nil)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Telegram API error: %v", err)), nil
		}
		jsonBytes, _ := json.MarshalIndent(result, "", "  ")
		return mcp.NewToolResultText(string(jsonBytes)), nil
	})

	s.AddTool(mcp.NewTool("telegram_send_document",
		mcp.WithDescription("Send a document/file via Telegram."),
		mcp.WithString("chat_id", mcp.Required(), mcp.Description("Target chat ID")),
		mcp.WithString("file_path", mcp.Required(), mcp.Description("Local path to the file to send")),
		mcp.WithString("caption", mcp.Description("Optional caption for the document")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		token := os.Getenv("TELEGRAM_BOT_TOKEN")
		if token == "" {
			return mcp.NewToolResultError("TELEGRAM_BOT_TOKEN not set"), nil
		}
		chatID := req.Params.Arguments["chat_id"].(string)
		filePath := req.Params.Arguments["file_path"].(string)
		caption, _ := req.Params.Arguments["caption"].(string)

		// Multipart upload for documents
		apiURL := fmt.Sprintf("https://api.telegram.org/bot%s/sendDocument", token)
		var b strings.Builder
		b.WriteString("--boundary\r\n")
		b.WriteString(fmt.Sprintf("Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n%s\r\n", chatID))
		b.WriteString("--boundary\r\n")
		b.WriteString(fmt.Sprintf("Content-Disposition: form-data; name=\"document\"; filename=\"%s\"\r\n", filePath))
		b.WriteString("Content-Type: application/octet-stream\r\n\r\n")

		fileData, err := os.ReadFile(filePath)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed to read file: %v", err)), nil
		}
		body := b.String() + string(fileData) + "\r\n--boundary--\r\n"

		resp, err := http.Post(apiURL, "multipart/form-data; boundary=boundary", strings.NewReader(body))
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Upload failed: %v", err)), nil
		}
		defer resp.Body.Close()
		respBytes, _ := io.ReadAll(resp.Body)
		var result map[string]any
		json.Unmarshal(respBytes, &result)
		jsonBytes, _ := json.MarshalIndent(result, "", "  ")

		_ = caption // available for future use with multipart
		return mcp.NewToolResultText(string(jsonBytes)), nil
	})

	server.ServeStdio(s)
}
