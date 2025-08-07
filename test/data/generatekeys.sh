#!/bin/sh
cd test/data
if [ ! -f rsa_priv1.pem ] || [ ! -f rsa_priv2.pem ] || [ ! -f rsa_priv3.pem ]; then
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -pkeyopt rsa_keygen_pubexp:3 -out rsa_priv1.pem 2>/dev/null
    openssl pkey -in rsa_priv1.pem -out rsa_pub1.pem -pubout
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -pkeyopt rsa_keygen_pubexp:3 -out rsa_priv2.pem 2>/dev/null
    openssl pkey -in rsa_priv2.pem -out rsa_pub2.pem -pubout
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -pkeyopt rsa_keygen_pubexp:3 -out rsa_priv3.pem 2>/dev/null
    openssl pkey -in rsa_priv3.pem -out rsa_pub3.pem -pubout
fi
