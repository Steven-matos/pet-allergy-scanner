#!/bin/bash
# Security vulnerability fix script
# Addresses: CVE-2024-23342 (ecdsa) and GHSA-4xh5-x5gv-qwph (pip)

set -e

echo "🔒 Security Vulnerability Fix Script"
echo "===================================="
echo ""

# Navigate to server directory
cd "$(dirname "$0")/.."

echo "1️⃣ Upgrading pip to latest secure version..."
python3 -m pip install --upgrade pip

echo ""
echo "2️⃣ Uninstalling vulnerable packages..."
python3 -m pip uninstall -y python-jose ecdsa || true

echo ""
echo "3️⃣ Installing updated requirements..."
python3 -m pip install -r requirements.txt --upgrade

echo ""
echo "4️⃣ Regenerating lock file..."
python3 -m pip freeze > requirements-lock.txt

echo ""
echo "5️⃣ Running security audit..."
python3 -m pip_audit

echo ""
echo "✅ Security fixes applied successfully!"
echo ""
echo "⚠️  Please review the audit results above."
echo "⚠️  Commit the updated requirements-lock.txt file."

