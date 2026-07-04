package main

import (
	"context"
	"fmt"
	"os/exec"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
)

func runVBox(args ...string) (string, error) {
	cmd := exec.Command("VBoxManage", args...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func main() {
	s := server.NewMCPServer(
		"mcp-vbox",
		"1.0.0",
		server.WithToolCapabilities(true),
	)

	s.AddTool(mcp.NewTool("vbox_list_vms",
		mcp.WithDescription("List all VirtualBox VMs and their states."),
		mcp.WithBoolean("long", mcp.Description("Show detailed info")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		args := []string{"list", "vms"}
		if long, _ := req.Params.Arguments["long"].(bool); long {
			args = append(args, "-l")
		}
		out, err := runVBox(args...)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(out), nil
	})

	s.AddTool(mcp.NewTool("vbox_list_running",
		mcp.WithDescription("List currently running VirtualBox VMs."),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		out, err := runVBox("list", "runningvms")
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		if out == "" {
			out = "No VMs running"
		}
		return mcp.NewToolResultText(out), nil
	})

	s.AddTool(mcp.NewTool("vbox_show_info",
		mcp.WithDescription("Show detailed info about a VirtualBox VM."),
		mcp.WithString("vm", mcp.Required(), mcp.Description("VM name or UUID")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		vm := req.Params.Arguments["vm"].(string)
		out, err := runVBox("showvminfo", vm, "--machinereadable")
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(out), nil
	})

	s.AddTool(mcp.NewTool("vbox_start",
		mcp.WithDescription("Start a VirtualBox VM headless."),
		mcp.WithString("vm", mcp.Required(), mcp.Description("VM name or UUID")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		vm := req.Params.Arguments["vm"].(string)
		out, err := runVBox("startvm", vm, "--type", "headless")
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(fmt.Sprintf("VM %s started\n%s", vm, out)), nil
	})

	s.AddTool(mcp.NewTool("vbox_stop",
		mcp.WithDescription("Stop a VirtualBox VM (acpi power button)."),
		mcp.WithString("vm", mcp.Required(), mcp.Description("VM name or UUID")),
		mcp.WithBoolean("force", mcp.Description("Power off forcefully instead of acpi")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		vm := req.Params.Arguments["vm"].(string)
		args := []string{"controlvm", vm}
		if force, _ := req.Params.Arguments["force"].(bool); force {
			args = append(args, "poweroff")
		} else {
			args = append(args, "acpipowerbutton")
		}
		out, err := runVBox(args...)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(fmt.Sprintf("VM %s stopping\n%s", vm, out)), nil
	})

	s.AddTool(mcp.NewTool("vbox_pause",
		mcp.WithDescription("Pause a running VirtualBox VM."),
		mcp.WithString("vm", mcp.Required(), mcp.Description("VM name or UUID")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		vm := req.Params.Arguments["vm"].(string)
		out, err := runVBox("controlvm", vm, "pause")
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(fmt.Sprintf("VM %s paused\n%s", vm, out)), nil
	})

	s.AddTool(mcp.NewTool("vbox_resume",
		mcp.WithDescription("Resume a paused VirtualBox VM."),
		mcp.WithString("vm", mcp.Required(), mcp.Description("VM name or UUID")),
	), func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		vm := req.Params.Arguments["vm"].(string)
		out, err := runVBox("controlvm", vm, "resume")
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Failed: %s\n%s", err, out)), nil
		}
		return mcp.NewToolResultText(fmt.Sprintf("VM %s resumed\n%s", vm, out)), nil
	})

	server.ServeStdio(s)
}
