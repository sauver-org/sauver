#!/bin/bash
set -e

echo "🛡️  Sauver Initialization 🛡️"
echo "Setting up your digital bouncer..."

# Ensure we are in the project root
cd "$(dirname "$0")/.."

# 1. Install Python dependencies using uv
echo "Installing Python dependencies..."
make setup

# 2. Check for credentials.json
if [ ! -f "credentials.json" ]; then
    echo "⚠️  credentials.json not found."
    echo "Please download your Google Workspace OAuth2 credentials to the project root as 'credentials.json'."
    echo "Then run this script again."
    exit 1
fi

# 3. Trigger initial OAuth Flow
echo "Triggering initial OAuth flow to generate token.json..."
python3 -c "from src.main import get_gmail_service; get_gmail_service()"

echo "✅ Sauver is ready to protect your inbox!"
echo "Next step: Install the Gemini CLI extension by running 'gemini extensions install .'"