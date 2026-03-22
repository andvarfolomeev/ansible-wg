#!/bin/sh

# Script to generate Xray Reality keypair, short IDs, and client UUIDs
# Usage: ./xray-keygen.sh [number_of_clients]
# Requires: xray binary in PATH

ADD_CLIENT_MODE=1
CLIENT_NAME=""

if [ "$1" = "--new" ]; then
    ADD_CLIENT_MODE=0
    CLIENT_NAME="${2:-}"
    shift; shift 2>/dev/null; true
fi

# Function to detect clipboard command
check_clipboard_cmd() {
    if command -v wl-copy > /dev/null 2>&1; then
        echo "wl-copy"
    elif command -v pbcopy > /dev/null 2>&1; then
        echo "pbcopy"
    elif command -v xclip > /dev/null 2>&1; then
        echo "xclip -selection clipboard"
    elif command -v xsel > /dev/null 2>&1; then
        echo "xsel --clipboard --input"
    else
        echo "none"
    fi
}

if [ "$ADD_CLIENT_MODE" = "1" ]; then
    SCRIPT_DIR=$(dirname "$0")
    XRAY_CLIENTS_FILE="${SCRIPT_DIR}/../xray_clients.yml"
    if [ ! -f "$XRAY_CLIENTS_FILE" ]; then
        XRAY_CLIENTS_FILE="xray_clients.yml"
    fi
    if [ ! -f "$XRAY_CLIENTS_FILE" ]; then
        echo "Error: xray_clients.yml not found. Run without --add-client first to generate a full server setup."
        exit 1
    fi

    # Parse args: optional name (non-numeric), optional count (numeric)
    ARG1="${1:-}"
    ARG2="${2:-}"
    ADD_NAME=""
    ADD_COUNT=1

    if echo "$ARG1" | grep -qE '^[0-9]+$'; then
        ADD_COUNT="$ARG1"
    elif [ -n "$ARG1" ]; then
        ADD_NAME="$ARG1"
        if echo "$ARG2" | grep -qE '^[0-9]+$'; then
            ADD_COUNT="$ARG2"
        fi
    fi

    CLIENT_COUNT=$(grep -c '^ *- name:' "$XRAY_CLIENTS_FILE")

    OUTPUT=""
    for i in $(seq 1 "$ADD_COUNT"); do
        NEXT_NUM=$((CLIENT_COUNT + i))
        if [ -n "$ADD_NAME" ] && [ "$ADD_COUNT" -gt 1 ]; then
            NAME="${ADD_NAME}_${i}"
        elif [ -n "$ADD_NAME" ]; then
            NAME="$ADD_NAME"
        else
            NAME="client${NEXT_NUM}"
        fi
        UUID=$(cat /proc/sys/kernel/random/uuid)
        SHORT_ID=$(openssl rand -hex 8)
        if [ -n "$OUTPUT" ]; then
            OUTPUT="${OUTPUT}\n"
        fi
        OUTPUT="${OUTPUT}  - name: ${NAME}\n"
        OUTPUT="${OUTPUT}    uuid: \"${UUID}\"\n"
        OUTPUT="${OUTPUT}    short_id: \"${SHORT_ID}\""
    done

    printf "%b\n" "$OUTPUT"

    CLIPBOARD_CMD=$(check_clipboard_cmd)
    if [ "$CLIPBOARD_CMD" != "none" ]; then
        printf "%b\n" "$OUTPUT" | eval "$CLIPBOARD_CMD"
        echo "# Output copied to clipboard."
    else
        echo "# No clipboard command found (install wl-copy, xclip, xsel, or pbcopy)."
    fi
    exit 0
fi

NUM_CLIENTS=${1:-1}

if ! echo "$NUM_CLIENTS" | grep -qE '^[0-9]+$'; then
    echo "Error: Please provide a valid number of clients to generate"
    echo "Usage: $0 [number_of_clients]"
    echo "       $0 --add-client [name]"
    exit 1
fi

if ! command -v xray > /dev/null 2>&1; then
    echo "Error: xray binary not found in PATH."
    echo "Install it from https://github.com/XTLS/Xray-core/releases"
    echo "or run on the server after deploying."
    exit 1
fi

# Generate Reality x25519 keypair
# xray x25519 output format:
#   PrivateKey: <base64>
#   Password:   <base64>   <- this is the public key for Reality
#   Hash32:     <base64>
KEYPAIR=$(xray x25519)
PRIVATE_KEY=$(echo "$KEYPAIR" | grep "^PrivateKey:" | awk '{print $2}')
PUBLIC_KEY=$(echo "$KEYPAIR" | grep "^Password:" | awk '{print $2}')

OUTPUT=""
OUTPUT="${OUTPUT}xray_server:\n"
OUTPUT="${OUTPUT}  endpoint: \"PASTE_SERVER_IP_HERE\"\n"
OUTPUT="${OUTPUT}  port: 443\n"
OUTPUT="${OUTPUT}  sni: \"www.microsoft.com\"\n"
OUTPUT="${OUTPUT}  private_key: \"${PRIVATE_KEY}\"\n"
OUTPUT="${OUTPUT}  public_key: \"${PUBLIC_KEY}\"\n"
OUTPUT="${OUTPUT}\n"
OUTPUT="${OUTPUT}xray_clients:\n"

for i in $(seq 1 "$NUM_CLIENTS"); do
    UUID=$(cat /proc/sys/kernel/random/uuid)
    SHORT_ID=$(openssl rand -hex 8)
    OUTPUT="${OUTPUT}  - name: client${i}\n"
    OUTPUT="${OUTPUT}    uuid: \"${UUID}\"\n"
    OUTPUT="${OUTPUT}    short_id: \"${SHORT_ID}\"\n"
    if [ "$i" -lt "$NUM_CLIENTS" ]; then
        OUTPUT="${OUTPUT}\n"
    fi
done

printf "%b\n" "$OUTPUT"

CLIPBOARD_CMD=$(check_clipboard_cmd)
if [ "$CLIPBOARD_CMD" != "none" ]; then
    printf "%b\n" "$OUTPUT" | eval "$CLIPBOARD_CMD"
    echo "# Output copied to clipboard."
else
    echo "# No clipboard command found (install wl-copy, xclip, xsel, or pbcopy)."
fi
