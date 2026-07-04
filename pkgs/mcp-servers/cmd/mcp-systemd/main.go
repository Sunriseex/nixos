package main

import (
	"context"
	"fmt"
	"os/exec"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
)

func runSystemctl(args ...string) (string, error) {
	cmd := exec.Command("systemctl", append([]string{"--user"}, args...)...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func main() {
	s := server.NewMCPServer(
		"mcp-systemd",
		"1.0.0",
		server.WithToolCapabilities(true),
	)

	s.AddTool(mcp.NewTool("systemd_status",
		mcp.WithDescription("Show status of a user systemd service"),
		mcp.WithString("service", mcp.Required(), mcp.Description("Service name (e.g., 'open-design.service')")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		svc := req.Params.Arguments["service"].(string)
		out, err := runSystemctl("status", svc, "--no-pager", "-n", "20")
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(out), nil
	})

	s.AddTool(mcp.NewTool("systemd_list_services",
		mcp.WithDescription("List user systemd services"),
		mcp.WithString("state", mcp.Description("Filter by state: running, failed, enabled. Empty = all")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		args := []string{"list-units", "--type=service", "--no-legend", "--no-pager"}
		state, _ := req.Params.Arguments["state"].(string)
		if state != "" {
			args = append(args, "--state="+state)
		}
		out, err := runSystemctl(args...)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		if out == "" {
			out = "No services found"
		}
		return mcp.NewToolResultText(out), nil
	})

	s.AddTool(mcp.NewTool("systemd_logs",
		mcp.WithDescription("View logs for a user systemd service"),
		mcp.WithString("service", mcp.Required(), mcp.Description("Service name")),
		mcp.WithNumber("tail", mcp.Description("Number of lines (default 50)")),
		mcp.WithString("since", mcp.Description("Time range, e.g. '10 min ago', 'today'")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		svc := req.Params.Arguments["service"].(string)
		args := []string{"--user", "-u", svc, "--no-pager", "-n", "50"}
		if t, ok := req.Params.Arguments["tail"].(float64); ok {
			args[4] = fmt.Sprintf("%d", int(t))
		}
		if since, ok := req.Params.Arguments["since"].(string); ok && since != "" {
			args = append(args, "--since", since)
		}
		cmd := exec.Command("journalctl", args...)
		out, err := cmd.CombinedOutput()
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(string(out)), nil
	})

	s.AddTool(mcp.NewTool("systemd_restart",
		mcp.WithDescription("Restart a user systemd service"),
		mcp.WithString("service", mcp.Required(), mcp.Description("Service name")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		svc := req.Params.Arguments["service"].(string)
		out, err := runSystemctl("restart", svc)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(fmt.Sprintf("Restarted %s\n%s", svc, out)), nil
	})

	s.AddTool(mcp.NewTool("systemd_start",
		mcp.WithDescription("Start a user systemd service"),
		mcp.WithString("service", mcp.Required(), mcp.Description("Service name")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		svc := req.Params.Arguments["service"].(string)
		out, err := runSystemctl("start", svc)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(fmt.Sprintf("Started %s\n%s", svc, out)), nil
	})

	s.AddTool(mcp.NewTool("systemd_stop",
		mcp.WithDescription("Stop a user systemd service"),
		mcp.WithString("service", mcp.Required(), mcp.Description("Service name")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		svc := req.Params.Arguments["service"].(string)
		out, err := runSystemctl("stop", svc)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(fmt.Sprintf("Stopped %s\n%s", svc, out)), nil
	})

	s.AddTool(mcp.NewTool("systemd_enable",
		mcp.WithDescription("Enable a user systemd service to start on boot"),
		mcp.WithString("service", mcp.Required(), mcp.Description("Service name")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		svc := req.Params.Arguments["service"].(string)
		out, err := runSystemctl("enable", svc)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(fmt.Sprintf("Enabled %s\n%s", svc, out)), nil
	})

	s.AddTool(mcp.NewTool("systemd_disable",
		mcp.WithDescription("Disable a user systemd service"),
		mcp.WithString("service", mcp.Required(), mcp.Description("Service name")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		svc := req.Params.Arguments["service"].(string)
		out, err := runSystemctl("disable", svc)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(fmt.Sprintf("Disabled %s\n%s", svc, out)), nil
	})

	server.ServeStdio(s)
}
