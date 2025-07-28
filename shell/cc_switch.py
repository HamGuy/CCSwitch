import argparse
import os
import platform
import sys
import re
from pathlib import Path

# Get the BASE_URL according to the type or custom input

def get_base_url(type_name, custom_url=None):
    mapping = {
        "gaccode": "https://api.tu-zi.com",
        "anyrouter": "https://anyrouter.top",
        "kimi": "https://api.moonshot.cn/anthropic/"
    }
    if type_name in mapping:
        return mapping[type_name]
    elif type_name == "custom" and custom_url:
        return custom_url
    else:
        print("Invalid type or missing custom URL.")
        sys.exit(1)

# Replace or append environment variables in config file

def update_env_file(file_path, token, base_url, shell_type):
    if not os.path.exists(file_path):
        content = ""
    else:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
    if shell_type == "windows":
        content = re.sub(r"\$env:ANTHROPIC_AUTH_TOKEN='.*?'", f"$env:ANTHROPIC_AUTH_TOKEN='{token}'", content)
        content = re.sub(r"\$env:ANTHROPIC_BASE_URL='.*?'", f"$env:ANTHROPIC_BASE_URL='{base_url}'", content)
        if "$env:ANTHROPIC_AUTH_TOKEN" not in content:
            content += f"\n$env:ANTHROPIC_AUTH_TOKEN='{token}'\n"
        if "$env:ANTHROPIC_BASE_URL" not in content:
            content += f"$env:ANTHROPIC_BASE_URL='{base_url}'\n"
    else:
        content = re.sub(r"export ANTHROPIC_AUTH_TOKEN=\".*?\"", f"export ANTHROPIC_AUTH_TOKEN=\"{token}\"", content)
        content = re.sub(r"export ANTHROPIC_BASE_URL=\".*?\"", f"export ANTHROPIC_BASE_URL=\"{base_url}\"", content)
        if "export ANTHROPIC_AUTH_TOKEN" not in content:
            content += f"\nexport ANTHROPIC_AUTH_TOKEN=\"{token}\"\n"
        if "export ANTHROPIC_BASE_URL" not in content:
            content += f"export ANTHROPIC_BASE_URL=\"{base_url}\"\n"
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

# Write environment variables to the corresponding shell or PowerShell config file

def write_env(token, base_url):
    system = platform.system().lower()
    if system == "windows":
        profile = os.environ.get("USERPROFILE", "") + "\\Documents\\WindowsPowerShell\\Microsoft.PowerShell_profile.ps1"
        Path(profile).parent.mkdir(parents=True, exist_ok=True)
        update_env_file(profile, token, base_url, "windows")
        print(f"Written to {profile}")
        print("Please restart PowerShell or run `. $PROFILE` to apply environment variables.")
    else:
        shell = os.path.basename(os.environ.get("SHELL", "bash"))
        home = str(Path.home())
        if shell == "zsh":
            rcfile = f"{home}/.zshrc"
        elif shell == "bash":
            rcfile = f"{home}/.bashrc"
        else:
            rcfile = f"{home}/.profile"
        update_env_file(rcfile, token, base_url, shell)
        print(f"Written to {rcfile}")
        print(f"Please reopen your terminal or run 'source {rcfile}' to apply environment variables.")

# Interactive mode for environment variable switching

def interactive_mode():
    print("cc-switch interactive mode")
    print("1) Switch environment")
    print("2) Reset to default Claude Code (gaccode) and clear token")
    choice = input("Select an option (1/2): ").strip()
    if choice == "2":
        # Reset to Claude Code official default: https://api.anthropic.com
        base_url = "https://api.anthropic.com"
        token = ""
        write_env(token, base_url)
        print("Reset to official Claude Code (https://api.anthropic.com) and cleared token.")
        return
    print("Select Claude Code type:")
    print("1) gaccode")
    print("2) anyrouter")
    print("3) kimi")
    print("4) custom BASE_URL")
    type_choice = input("Type (1/2/3/4): ").strip()
    if type_choice == "1":
        type_name = "gaccode"
        base_url = get_base_url(type_name)
    elif type_choice == "2":
        type_name = "anyrouter"
        base_url = get_base_url(type_name)
    elif type_choice == "3":
        type_name = "kimi"
        base_url = get_base_url(type_name)
    elif type_choice == "4":
        type_name = "custom"
        base_url = input("Enter custom BASE_URL: ").strip()
    else:
        print("Invalid selection.")
        return
    token = input("Enter ANTHROPIC_AUTH_TOKEN: ").strip()
    write_env(token, base_url)

# Main entry for command line usage

def main():
    parser = argparse.ArgumentParser(description="cc-switch: Claude Code environment variable command line switch tool")
    parser.add_argument("--type", choices=["gaccode", "anyrouter", "kimi", "custom"], help="Type: gaccode, anyrouter, kimi, custom")
    parser.add_argument("--token", help="ANTHROPIC_AUTH_TOKEN")
    parser.add_argument("--base_url", help="Custom BASE_URL, required if --type custom")
    parser.add_argument("--reset", action="store_true", help="Reset to default Claude Code and clear token")
    args = parser.parse_args()

    # If no arguments are provided, enter interactive mode
    if len(sys.argv) == 1:
        interactive_mode()
        return

    if args.reset:
        # Reset to Claude Code official default: https://api.anthropic.com
        base_url = "https://api.anthropic.com"
        token = ""
        write_env(token, base_url)
        print("Reset to official Claude Code (https://api.anthropic.com) and cleared token.")
        return

    if not args.type or not args.token or (args.type == "custom" and not args.base_url):
        parser.print_help()
        sys.exit(1)

    base_url = get_base_url(args.type, args.base_url)
    write_env(args.token, base_url)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nExited by user (Ctrl+C). Goodbye!")
        sys.exit(0)
