#!/bin/bash
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Usage: gencert.sh <certname> <primary host>"
    echo ""
    echo "For example:"
    echo "  gencert.sh prometheus monitoring.local"
    exit 1
fi

mkdir certs/$1

cacsr=$(cat <<EOF
{
    "CN": "Prometheus PKI",
    "names": [
        {
            "C":  "GB",
            "L":  "Glasgow",
            "O":  "Prometheus PKI",
            "OU": "Prometheus PKI",
            "ST": "Scotland"
        }
    ]
}
EOF
)

cfssl genkey -initca <(echo $cacsr) | cfssljson -bare certs/$1/$1-ca

csr=$(cat <<EOF
{
    "CN": "$2",
    "hosts": [
        "$2",
        "localhost",
        "127.0.0.1"
    ],
    "names": [
        {
            "C":  "GB",
            "L":  "Glasgow",
            "O":  "Prometheus PKI",
            "OU": "Prometheus PKI",
            "ST": "Scotland"
        }
    ]
}
EOF
)
cfssl gencert -ca certs/$1/$1-ca.pem -ca-key certs/$1/$1-ca-key.pem <(echo $csr) | cfssljson -bare certs/$1/$1
