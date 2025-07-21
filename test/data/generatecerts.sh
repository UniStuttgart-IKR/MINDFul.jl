#!/bin/sh
if ! command -v openssl >/dev/null 2>&1; then   # Checking that openssl is installed
    echo "Error: openssl is not installed or not present on your PATH." >&2
    exit 1
else
    if [ ! -f selfsigned.cert ] || [ ! -f selfsigned.key ]; then    #checking if the cert and key already exist
        openssl req -x509 -nodes -newkey rsa:2048 -keyout selfsigned.key -out selfsigned.cert -subj "/CN=localhost" 2>/dev/null
    fi
fi
