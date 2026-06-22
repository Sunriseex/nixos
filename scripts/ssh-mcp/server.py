#!/usr/bin/env python3
import json
import subprocess
import sys
import os
import shlex


def log(msg):
    sys.stderr.write(f"[ssh-mcp] {msg}\n")
    sys.stderr.flush()


def run_ssh(host, command):
    cmd = ["ssh", "-o", "ConnectTimeout=10", "-o", "BatchMode=yes", host] + shlex.split(command)
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    return {
        "stdout": result.stdout,
        "stderr": result.stderr,
        "returncode": result.returncode,
    }


def upload_scp(host, local_path, remote_path):
    cmd = ["scp", "-o", "ConnectTimeout=10", "-o", "BatchMode=yes", local_path, f"{host}:{remote_path}"]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    return {
        "stdout": result.stdout,
        "stderr": result.stderr,
        "returncode": result.returncode,
    }


def list_hosts():
    config_path = os.path.expanduser("~/.ssh/config")
    hosts = []
    if os.path.exists(config_path):
        with open(config_path) as f:
            for line in f:
                line = line.strip()
                if line.lower().startswith("host "):
                    h = line.split(None, 1)[1].strip()
                    if h != "*":
                        hosts.append(h)
    return hosts


TOOLS = [
    {
        "name": "ssh_run",
        "description": "Run command on remote host via SSH. Use for server mgmt, logs, deploy.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "host": {"type": "string", "description": "SSH host (from ~/.ssh/config or user@hostname)"},
                "command": {"type": "string", "description": "Command to execute on remote host"},
            },
            "required": ["host", "command"],
        },
    },
    {
        "name": "ssh_upload",
        "description": "Copy local file to remote host via SCP.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "host": {"type": "string", "description": "SSH host"},
                "local_path": {"type": "string", "description": "Local file path"},
                "remote_path": {"type": "string", "description": "Remote destination path"},
            },
            "required": ["host", "local_path", "remote_path"],
        },
    },
    {
        "name": "ssh_hosts",
        "description": "List SSH hosts from ~/.ssh/config",
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
]


def handle_request(req):
    method = req.get("method", "")
    req_id = req.get("id")
    params = req.get("params", {}) or {}

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "ssh-mcp", "version": "1.0.0"},
            },
        }
    elif method == "notifications/initialized":
        return None
    elif method == "tools/list":
        return {"jsonrpc": "2.0", "id": req_id, "result": {"tools": TOOLS}}
    elif method == "tools/call":
        name = params.get("name", "")
        args = params.get("arguments", {}) or {}
        try:
            if name == "ssh_run":
                result = run_ssh(args["host"], args["command"])
            elif name == "ssh_upload":
                result = upload_scp(args["host"], args["local_path"], args["remote_path"])
            elif name == "ssh_hosts":
                result = list_hosts()
            else:
                return {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "error": {"code": -32601, "message": f"Unknown tool: {name}"},
                }
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {
                    "content": [{"type": "text", "text": json.dumps(result, indent=2)}]
                },
            }
        except subprocess.TimeoutExpired:
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": -32000, "message": "SSH command timed out"},
            }
        except Exception as e:
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": -32000, "message": str(e)},
            }
    return None


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            resp = handle_request(req)
            if resp:
                sys.stdout.write(json.dumps(resp) + "\n")
                sys.stdout.flush()
        except json.JSONDecodeError:
            log(f"Invalid JSON")
        except Exception as e:
            log(f"Error: {e}")


if __name__ == "__main__":
    main()
