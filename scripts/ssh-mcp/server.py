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


def collect_info(host):
    cmds = {
        "hostname": "hostname -f 2>/dev/null || hostname",
        "os": "cat /etc/os-release 2>/dev/null | head -10",
        "kernel": "uname -a",
        "uptime": "uptime",
        "cpu": "lscpu 2>/dev/null | grep -E 'Model name|CPU\(s\)|Thread|Core|Socket' | head -5",
        "memory": "free -h",
        "disk": "df -h --output=source,fstype,size,used,avail,pcent,target 2>/dev/null || df -h",
        "load": "cat /proc/loadavg",
        "users": "who",
        "processes": "ps aux --sort=-%mem | head -10",
        "network": "ip -4 addr show 2>/dev/null | grep inet | head -10",
        "packages_deb": "dpkg -l 2>/dev/null | wc -l",
        "packages_rpm": "rpm -qa 2>/dev/null | wc -l",
    }
    info = {}
    for key, cmd in cmds.items():
        result = run_ssh(host, cmd)
        if result["returncode"] == 0:
            info[key] = result["stdout"].strip()
        else:
            info[key] = f"Error: {result['stderr'].strip()}"
    return info


def run_ssh_long(host, command, timeout=300):
    cmd = ["ssh", "-o", "ConnectTimeout=10", "-o", "BatchMode=yes", host] + shlex.split(command)
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    return {
        "stdout": result.stdout,
        "stderr": result.stderr,
        "returncode": result.returncode,
    }


def wait_for_ssh(host, timeout=180):
    import time
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            cmd = ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=no", host, "uptime"]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                return True
        except Exception:
            pass
        time.sleep(5)
    return False


def update_host(host, reboot=True, wait_for_reboot=True):
    os_info = run_ssh(host, "cat /etc/os-release 2>/dev/null | head -5")
    pkgs_before = run_ssh(host, "dpkg --get-selections 2>/dev/null | wc -l || echo 0")

    apt_out = run_ssh_long(host, "DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y")

    pkgs_after = run_ssh(host, "dpkg --get-selections 2>/dev/null | wc -l || echo 0")
    reboot_req = run_ssh(host, "test -f /var/run/reboot-required && cat /var/run/reboot-required || echo 'no'")

    result = {
        "os": os_info.get("stdout", "").strip(),
        "packages_before": pkgs_before.get("stdout", "").strip(),
        "packages_after": pkgs_after.get("stdout", "").strip(),
        "update_exit_code": apt_out["returncode"],
        "update_stdout": apt_out.get("stdout", "").strip(),
        "update_stderr": apt_out.get("stderr", "").strip(),
        "reboot_required": reboot_req.get("stdout", "").strip(),
    }

    if apt_out["returncode"] != 0:
        result["status"] = "update_failed"
        result["reboot_performed"] = False
        return result

    if not reboot:
        result["status"] = "updated"
        result["reboot_performed"] = False
        return result

    if reboot_req["returncode"] == 0 or "reboot-required" in reboot_req.get("stdout", ""):
        reboot_out = run_ssh(host, "nohup sh -c 'sleep 10 && shutdown -r +1' >/dev/null 2>&1 &")
        result["reboot_scheduled"] = True
        result["reboot_command"] = reboot_out.get("stdout", "").strip()

        if wait_for_reboot:
            before_up = run_ssh(host, "uptime -s 2>/dev/null || date +%s")
            up = wait_for_ssh(host)
            if up:
                after_up = run_ssh(host, "uptime -s 2>/dev/null || date +%s")
                result["reboot_performed"] = True
                result["reboot_detected"] = True
                result["uptime_before"] = before_up.get("stdout", "").strip()
                result["uptime_after"] = after_up.get("stdout", "").strip()
            else:
                result["reboot_performed"] = True
                result["reboot_detected"] = False
        else:
            result["status"] = "reboot_scheduled"
            result["reboot_performed"] = False
    else:
        result["status"] = "updated_no_reboot_needed"
        result["reboot_performed"] = False

    return result


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
    {
        "name": "ssh_info",
        "description": "Gather OS info, uptime, disk, memory, CPU, processes from remote host",
        "inputSchema": {
            "type": "object",
            "properties": {
                "host": {"type": "string", "description": "SSH host (from ~/.ssh/config or user@hostname)"},
            },
            "required": ["host"],
        },
    },
    {
        "name": "ssh_update",
        "description": "Safely update Debian/Ubuntu host: apt update+upgrade, optional reboot. Only apt upgrade (not dist-upgrade). Waits for SSH to come back after reboot.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "host": {"type": "string", "description": "SSH host"},
                "reboot": {"type": "boolean", "description": "Reboot after update if needed (default: true)"},
                "wait_for_reboot": {"type": "boolean", "description": "Wait for SSH to come back after reboot (default: true)"},
            },
            "required": ["host"],
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
            elif name == "ssh_info":
                result = collect_info(args["host"])
            elif name == "ssh_update":
                result = update_host(args["host"], args.get("reboot", True), args.get("wait_for_reboot", True))
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
