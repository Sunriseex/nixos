package main

import (
	"context"
	"fmt"
	"os/exec"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
)

func runCmd(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	cmd.Env = []string{} // isolate from user env for predictability
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func main() {
	s := server.NewMCPServer(
		"mcp-docker",
		"1.0.0",
		server.WithToolCapabilities(true),
	)

	s.AddTool(mcp.NewTool("docker_ps",
		mcp.WithDescription("List running Docker containers"),
		mcp.WithBoolean("all", mcp.Description("Show all containers including stopped")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		args := []string{"ps", "--format", "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"}
		if all, _ := req.Params.Arguments["all"].(bool); all {
			args = append(args, "-a")
		}
		out, err := runCmd("docker", args...)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("docker ps failed: %s", out)), nil
		}
		return mcp.NewToolResultText(out), nil
	})

	s.AddTool(mcp.NewTool("docker_logs",
		mcp.WithDescription("Get logs from a Docker container"),
		mcp.WithString("container", mcp.Required(), mcp.Description("Container name or ID")),
		mcp.WithNumber("tail", mcp.Description("Number of lines to show (default 50)")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		container := req.Params.Arguments["container"].(string)
		tail := "50"
		if t, ok := req.Params.Arguments["tail"].(float64); ok {
			tail = fmt.Sprintf("%d", int(t))
		}
		out, err := runCmd("docker", "logs", "--tail", tail, container)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("docker logs failed: %s", out)), nil
		}
		return mcp.NewToolResultText(out), nil
	})

	s.AddTool(mcp.NewTool("docker_compose_ps",
		mcp.WithDescription("Show Docker Compose services status. Runs in current directory."),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		out, err := runCmd("docker", "compose", "ps", "--format", "table {{.Name}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}")
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("docker compose ps failed: %s", out)), nil
		}
		return mcp.NewToolResultText(out), nil
	})

	s.AddTool(mcp.NewTool("docker_compose_logs",
		mcp.WithDescription("Get logs from all Docker Compose services. Runs in current directory."),
		mcp.WithNumber("tail", mcp.Description("Number of lines to show (default 50)")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		tail := "50"
		if t, ok := req.Params.Arguments["tail"].(float64); ok {
			tail = fmt.Sprintf("%d", int(t))
		}
		out, err := runCmd("docker", "compose", "logs", "--tail", tail)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("docker compose logs failed: %s", out)), nil
		}
		return mcp.NewToolResultText(out), nil
	})

	s.AddTool(mcp.NewTool("docker_compose_up",
		mcp.WithDescription("Start Docker Compose services in detached mode. Runs in current directory."),
		mcp.WithString("services", mcp.Description("Specific services to start (space-separated, optional)")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		args := []string{"compose", "up", "-d"}
		if svc, ok := req.Params.Arguments["services"].(string); ok && svc != "" {
			args = append(args, strings.Fields(svc)...)
		}
		out, err := runCmd("docker", args...)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("docker compose up failed: %s", out)), nil
		}
		return mcp.NewToolResultText(out), nil
	})

	s.AddTool(mcp.NewTool("docker_compose_down",
		mcp.WithDescription("Stop and remove Docker Compose services. Runs in current directory."),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		out, err := runCmd("docker", "compose", "down")
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("docker compose down failed: %s", out)), nil
		}
		return mcp.NewToolResultText(out), nil
	})

	s.AddTool(mcp.NewTool("docker_exec",
		mcp.WithDescription("Execute a command inside a running Docker container"),
		mcp.WithString("container", mcp.Required(), mcp.Description("Container name or ID")),
		mcp.WithString("command", mcp.Required(), mcp.Description("Command to execute")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		container := req.Params.Arguments["container"].(string)
		cmdStr := req.Params.Arguments["command"].(string)
		args := []string{"exec", container}
		args = append(args, strings.Fields(cmdStr)...)
		out, err := runCmd("docker", args...)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("docker exec failed: %s", out)), nil
		}
		return mcp.NewToolResultText(out), nil
	})

	s.AddTool(mcp.NewTool("docker_inspect",
		mcp.WithDescription("Show detailed info about a Docker container"),
		mcp.WithString("container", mcp.Required(), mcp.Description("Container name or ID")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		container := req.Params.Arguments["container"].(string)
		out, err := runCmd("docker", "inspect", container)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("docker inspect failed: %s", out)), nil
		}
		return mcp.NewToolResultText(out), nil
	})

	server.ServeStdio(s)
}
