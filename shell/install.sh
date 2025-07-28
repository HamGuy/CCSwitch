#!/bin/bash

# CC Switch installation script
# GitHub repository URL for downloading
CC_SWITCH_URL="https://raw.githubusercontent.com/hamguy/cc-switch/main/cc_switch.py"

# Auto-adapt install location: use ~/bin if no permission for /usr/local/bin
TARGET="/usr/local/bin/ccswitch"
TEMP_SCRIPT="/tmp/cc_switch.py"

# check if ccswitch is already installed
# If it exists, prompt for reinstallation
# If not, check if cc_switch.py exists in the current directory or download it
if [ -f "$TARGET" ]; then
    echo "[cc-switch] ccswitch already installed at $TARGET"
    read -p "Do you want to reinstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "[cc-switch] Installation cancelled."
        exit 0
    fi
fi

# Check if cc_switch.py exists in the current directory
# If it exists, use it; otherwise, download it
if [ -f "./cc_switch.py" ]; then
    echo "[cc-switch] Found cc_switch.py in current directory."
    SCRIPT_SOURCE="./cc_switch.py"
else
    echo "[cc-switch] cc_switch.py not found in current directory, checking if already downloaded..."
    
    # check if already downloaded to a temporary location
    # If it exists, check if it's up to date; otherwise, download it
    if [ -f "$TEMP_SCRIPT" ]; then
        echo "[cc-switch] Found previously downloaded cc_switch.py, checking if it's up to date..."
        # get the last modified time of the remote file
        REMOTE_MODIFIED=$(curl -fsSL -I "$CC_SWITCH_URL" | grep -i last-modified | cut -d' ' -f2-)
        LOCAL_MODIFIED=$(stat -f "%Sm" -t "%a, %d %b %Y %H:%M:%S %Z" "$TEMP_SCRIPT" 2>/dev/null || echo "")
        
        if [ "$REMOTE_MODIFIED" != "$LOCAL_MODIFIED" ] || [ -z "$LOCAL_MODIFIED" ]; then
            echo "[cc-switch] Local file is outdated, downloading latest version..."
            curl -fsSL "$CC_SWITCH_URL" -o "$TEMP_SCRIPT"
        else
            echo "[cc-switch] Local file is up to date."
        fi
    else
        echo "[cc-switch] Downloading cc_switch.py..."
        curl -fsSL "$CC_SWITCH_URL" -o "$TEMP_SCRIPT"
    fi
    
    # Check if the download was successful
    # If it exists, check if it's up to date; otherwise, download it
    if [ ! -f "$TEMP_SCRIPT" ] || [ ! -s "$TEMP_SCRIPT" ]; then
        echo "[cc-switch] Error: Failed to download cc_switch.py"
        exit 1
    fi
    
    SCRIPT_SOURCE="$TEMP_SCRIPT"
fi

if ! touch "$TARGET" 2>/dev/null; then
  mkdir -p "$HOME/bin"
  TARGET="$HOME/bin/ccswitch"
  echo "No permission for /usr/local/bin, installing to $TARGET"
fi

# Always overwrite the target file (no duplicate installs)
echo "Installing ccswitch to $TARGET ..."
{
  echo "#!/usr/bin/env python3"
  cat "$SCRIPT_SOURCE"
} > "$TARGET"
chmod +x "$TARGET"

# clean up temporary file if it was downloaded
if [ "$SCRIPT_SOURCE" = "$TEMP_SCRIPT" ]; then
    rm -f "$TEMP_SCRIPT"
fi

# Add ~/bin to PATH if not already (only if installing to ~/bin)
PATH_UPDATED=false
if [[ "$TARGET" == "$HOME/bin/ccswitch" ]]; then
  if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.zshrc" 2>/dev/null; then
      echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
      PATH_UPDATED=true
    fi
    if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
      echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
      PATH_UPDATED=true
    fi
    if [ "$PATH_UPDATED" = true ]; then
      echo "Added ~/bin to PATH in .zshrc and .bashrc"
    fi
  fi
fi

# Source the shell config to make ccswitch available immediately
CURRENT_SHELL=$(basename "$SHELL")
if [ "$PATH_UPDATED" = true ]; then
  if [ "$CURRENT_SHELL" = "zsh" ]; then
    source "$HOME/.zshrc"
  elif [ "$CURRENT_SHELL" = "bash" ]; then
    source "$HOME/.bashrc"
  fi
  echo "Sourced your shell config to update PATH. You can now use 'ccswitch' immediately."
fi

echo "ccswitch command installed at $TARGET."
echo "Usage examples:"
echo "  ccswitch --type kimi --token sk-xxx # Kimi API token"
echo "  ccswitch --type custom --token sk-xxx --base_url https://your-url.com # Custom API token and URL"
echo "  ccswitch --reset # reset to default settings"
echo "  ccswitch   # interactive mode"
