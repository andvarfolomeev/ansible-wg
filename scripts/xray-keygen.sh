#!/bin/sh

# Script to generate Xray Reality keys and clients in xray_clients.yml format
# Usage: ./xray-keygen.sh [name] [count]   client entries to append to xray_clients.yml
#        ./xray-keygen.sh --new [count]    complete xray_clients.yml with a fresh Reality keypair
# Requires: openssl, and the xray binary in PATH for --new

usage() {
    echo "Usage: $0 [name] [count]   client entries to append to xray_clients.yml"
    echo "       $0 --new [count]    complete xray_clients.yml with a fresh Reality keypair"
}

is_count() {
    echo "$1" | grep -qE '^[1-9][0-9]*$'
}

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

# Print one xray_clients entry with a fresh UUID and short ID
client_entry() {
    printf '  - name: %s\n' "$1"
    printf '    uuid: "%s"\n' "$(cat /proc/sys/kernel/random/uuid)"
    printf '    short_id: "%s"\n' "$(openssl rand -hex 8)"
}

# Parse args: --new or an optional name (non-numeric), then an optional count
MODE=add
case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    --new)
        MODE=new
        shift
        ;;
    -*)
        echo "Error: unknown option: $1"
        usage
        exit 1
        ;;
esac

NAME=""
COUNT=1
if [ "$MODE" = "add" ] && [ -n "${1:-}" ] && ! echo "$1" | grep -qE '^[0-9]+$'; then
    NAME="$1"
    shift
fi
if [ -n "${1:-}" ]; then
    if ! is_count "$1"; then
        echo "Error: count must be a positive number, got: $1"
        usage
        exit 1
    fi
    COUNT="$1"
    shift
fi
if [ $# -gt 0 ]; then
    echo "Error: unexpected argument: $1"
    usage
    exit 1
fi

if [ "$MODE" = "add" ]; then
    SCRIPT_DIR=$(dirname "$0")
    XRAY_CLIENTS_FILE="${SCRIPT_DIR}/../xray_clients.yml"
    if [ ! -f "$XRAY_CLIENTS_FILE" ]; then
        XRAY_CLIENTS_FILE="xray_clients.yml"
    fi
    if [ ! -f "$XRAY_CLIENTS_FILE" ]; then
        echo "Error: xray_clients.yml not found. Run with --new first to generate a full server setup."
        exit 1
    fi

    # Unnamed clients continue the clientN numbering of the existing file
    CLIENT_COUNT=$(grep -c '^ *- name:' "$XRAY_CLIENTS_FILE")

    OUTPUT=$(
        for i in $(seq 1 "$COUNT"); do
            [ "$i" -gt 1 ] && echo
            if [ -n "$NAME" ] && [ "$COUNT" -gt 1 ]; then
                client_entry "${NAME}_${i}"
            elif [ -n "$NAME" ]; then
                client_entry "$NAME"
            else
                client_entry "client$((CLIENT_COUNT + i))"
            fi
        done
    )
else
    if ! command -v xray > /dev/null 2>&1; then
        echo "Error: xray binary not found in PATH."
        echo "Install it from https://github.com/XTLS/Xray-core/releases"
        echo "or run on the server after deploying."
        exit 1
    fi

    # Generate Reality x25519 keypair
    # xray x25519 output format:
    #   PrivateKey: <base64>
    #   Password (PublicKey): <base64>   <- this is the public key for Reality
    #   Hash32:     <base64>
    KEYPAIR=$(xray x25519)
    PRIVATE_KEY=$(echo "$KEYPAIR" | grep "^PrivateKey:" | awk '{print $2}')
    PUBLIC_KEY=$(echo "$KEYPAIR" | grep "^Password" | awk '{print $NF}')

    OUTPUT=$(
        echo "xray_server:"
        echo "  endpoint: \"PASTE_SERVER_IP_HERE\""
        echo "  port: 443"
        echo "  domain: \"CHANGE_ME.example\""
        echo "  xhttp_path: \"/$(openssl rand -hex 8)\""
        echo "  private_key: \"${PRIVATE_KEY}\""
        echo "  public_key: \"${PUBLIC_KEY}\""
        echo
        echo "xray_clients:"
        for i in $(seq 1 "$COUNT"); do
            [ "$i" -gt 1 ] && echo
            client_entry "client${i}"
        done
    )
fi

printf '%s\n' "$OUTPUT"

CLIPBOARD_CMD=$(check_clipboard_cmd)
if [ "$CLIPBOARD_CMD" != "none" ]; then
    printf '%s\n' "$OUTPUT" | eval "$CLIPBOARD_CMD"
    echo "# Output copied to clipboard."
else
    echo "# No clipboard command found (install wl-copy, xclip, xsel, or pbcopy)."
fi
