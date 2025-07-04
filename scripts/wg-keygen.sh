#!/bin/bash

# Script to generate WireGuard public/private key pairs and output in specified format
# Usage: ./wg-keygen.sh [number_of_keys]

# Default to 1 key if not specified
NUM_KEYS=${1:-1}

# Check if the input is a number
if ! [[ "$NUM_KEYS" =~ ^[0-9]+$ ]]; then
    echo "Error: Please provide a valid number of keys to generate"
    echo "Usage: $0 [number_of_keys]"
    exit 1
fi

# Check if WireGuard tools are installed
if ! command -v wg &> /dev/null; then
    echo "Error: WireGuard tools not found. Please install WireGuard."
    echo "  For macOS: brew install wireguard-tools"
    echo "  For Ubuntu/Debian: apt install wireguard-tools"
    echo "  For CentOS/RHEL: yum install wireguard-tools"
    exit 1
fi

# Function to check if clipboard command exists
check_clipboard_cmd() {
    if command -v pbcopy &> /dev/null; then
        # macOS
        echo "pbcopy"
    elif command -v xclip &> /dev/null; then
        # Linux with xclip
        echo "xclip -selection clipboard"
    elif command -v xsel &> /dev/null; then
        # Linux with xsel
        echo "xsel --clipboard --input"
    elif command -v wl-copy &> /dev/null; then
        # Wayland
        echo "wl-copy"
    else
        echo "none"
    fi
}

# Initialize empty output
OUTPUT=""

# Generate key pairs
for (( i=1; i<=$NUM_KEYS; i++ ))
do
    # Generate private key
    PRIVATE_KEY=$(wg genkey)

    # Generate public key from private key
    PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)

    # Format the output for this key pair
    if [ $i -gt 1 ]; then
        # Add a newline before each peer except the first one
        OUTPUT="${OUTPUT}\n"
    fi

    KEY_OUTPUT=$(cat <<EOF
  - name: peer$i
    private_key: $PRIVATE_KEY
    public_key: $PUBLIC_KEY
    allowed_ips: 10.0.0.$(($i+1))/32
EOF
)

    # Add to total output
    OUTPUT="${OUTPUT}${KEY_OUTPUT}"
done

# Format as proper YAML
OUTPUT=$(cat <<EOF
peers:
${OUTPUT}
EOF
)

# Display the output
echo -e "$OUTPUT"

# Copy to clipboard if possible
CLIPBOARD_CMD=$(check_clipboard_cmd)
if [ "$CLIPBOARD_CMD" != "none" ]; then
    echo -e "$OUTPUT" | eval "$CLIPBOARD_CMD"
    echo "$NUM_KEYS key pair(s) copied to clipboard."
else
    echo "No clipboard command found. Keys not copied to clipboard."
    echo "To copy to clipboard, install one of the following:"
    echo "  macOS: pbcopy (built-in)"
    echo "  Linux: xclip, xsel, or wl-copy"
fi
