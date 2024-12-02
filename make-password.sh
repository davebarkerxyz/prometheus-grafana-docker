#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: make-password.sh <username>"
    echo ""
    echo "For example:"
    echo "  make-password.sh prometheus"
    exit 1
fi

password=$(python3 -c "from random import choices; import string; print(''.join(choices(string.ascii_letters + string.digits, k=32)))")
hashed=$(htpasswd -n -b -B $1 $password)

echo "Password: $password"
echo "$hashed"
