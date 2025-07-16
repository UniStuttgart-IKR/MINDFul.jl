#!/bin/sh
if [ ! -f selfsigned.cert ] || [ ! -f selfsigned.key ]; then
    #echo "Generating self-signed certificate and key"
    openssl req -x509 -nodes -newkey rsa:2048 -keyout selfsigned.key -out selfsigned.cert -subj "/CN=localhost"
else
    #echo "Certificate and key already exist"
fi
