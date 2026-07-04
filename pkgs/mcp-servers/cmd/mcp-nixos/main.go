package main

import (
	"context"
	"fmt"
	"os/exec"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
)

func runNixCmd(args ...string) (string, error) {
	cmd := exec.Command("sudo", append([]string{"nixos-rebuild"}, args...)...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func homeManagerCmd(args ...string) (string, error) {
	cmd := exec.Command("home-manager", args...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func main() {
	s := server.NewMCPServer(
		"mcp-nixos",
		"1.0.0",
		server.WithToolCapabilities(true),
	)

	s.AddTool(mcp.NewTool("nixos_rebuild_test",
		mcp.WithDescription("Test a NixOS rebuild (dry run). Validates config without applying. Use --flake .#desktop-pc."),
		mcp.WithString("flake", mcp.Description("Flake target, e.g. '.#desktop-pc'")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		flake := ".#desktop-pc"
		if f, ok := req.Params.Arguments["flake"].(string); ok && f != "" {
			flake = f
		}
		out, err := runNixCmd("test", "--flake", flake)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Build test FAILED:\n%s", out)), nil
		}
		return mcp.NewToolResultText(fmt.Sprintf("Build test PASSED\n%s", out)), nil
	})

	s.AddTool(mcp.NewTool("nixos_rebuild_switch",
		mcp.WithDescription("Build and activate a new NixOS system generation. Requires sudo."),
		mcp.WithString("flake", mcp.Description("Flake target, e.g. '.#desktop-pc'")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		flake := ".#desktop-pc"
		if f, ok := req.Params.Arguments["flake"].(string); ok && f != "" {
			flake = f
		}
		out, err := runNixCmd("switch", "--flake", flake)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Switch FAILED:\n%s", out)), nil
		}
		return mcp.NewToolResultText(fmt.Sprintf("Switch succeeded\n%s", out)), nil
	})

	s.AddTool(mcp.NewTool("nixos_rollback",
		mcp.WithDescription("Rollback to the previous NixOS system generation."),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		out, err := runNixCmd("--rollback")
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Rollback FAILED:\n%s", out)), nil
		}
		return mcp.NewToolResultText(fmt.Sprintf("Rollback succeeded\n%s", out)), nil
	})

	s.AddTool(mcp.NewTool("nixos_list_generations",
		mcp.WithDescription("List NixOS system generations."),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		cmd := exec.Command("sudo", "nix-env", "--list-generations", "--profile", "/nix/var/nix/profiles/system")
		out, err := cmd.CombinedOutput()
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(string(out)), nil
	})

	s.AddTool(mcp.NewTool("nixos_gc",
		mcp.WithDescription("Run nix store garbage collection. Frees disk space."),
		mcp.WithString("older_than", mcp.Description("Delete generations older than this, e.g. '7d', '14d'")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		args := []string{"nix-collect-garbage"}
		if days, ok := req.Params.Arguments["older_than"].(string); ok && days != "" {
			args = append(args, "--delete-older-than", days)
		}
		cmd := exec.Command("sudo", args...)
		out, err := cmd.CombinedOutput()
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("GC failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(string(out)), nil
	})

	s.AddTool(mcp.NewTool("nix_flake_check",
		mcp.WithDescription("Run nix flake check to validate the current flake."),
		mcp.WithString("path", mcp.Description("Path to the flake (default: cwd)")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		args := []string{"flake", "check"}
		path, _ := req.Params.Arguments["path"].(string)
		if path != "" {
			args = append(args, path)
		}
		cmd := exec.Command("nix", args...)
		out, err := cmd.CombinedOutput()
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Flake check FAILED:\n%s", out)), nil
		}
		return mcp.NewToolResultText(fmt.Sprintf("Flake check PASSED\n%s", out)), nil
	})

	s.AddTool(mcp.NewTool("nix_flake_update",
		mcp.WithDescription("Update a specific flake input or all inputs."),
		mcp.WithString("input", mcp.Description("Input name to update, e.g. 'nixpkgs'. Empty = update all")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		args := []string{"flake", "update"}
		if input, ok := req.Params.Arguments["input"].(string); ok && input != "" {
			args = append(args, input)
		}
		cmd := exec.Command("nix", args...)
		out, err := cmd.CombinedOutput()
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Update failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(string(out)), nil
	})

	s.AddTool(mcp.NewTool("home_manager_switch",
		mcp.WithDescription("Build and activate a new Home Manager generation."),
		mcp.WithString("flake", mcp.Description("Flake target, e.g. 'snrx@desktop-pc'")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		flake := "snrx@desktop-pc"
		if f, ok := req.Params.Arguments["flake"].(string); ok && f != "" {
			flake = f
		}
		out, err := homeManagerCmd("switch", "--flake", "."+flake)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Home Manager switch FAILED:\n%s", out)), nil
		}
		return mcp.NewToolResultText(fmt.Sprintf("Home Manager switch succeeded\n%s", out)), nil
	})

	server.ServeStdio(s)
}
