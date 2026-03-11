#!/bin/bash
set -e

echo "🛡️  Sauver Initialization 🛡️"
echo "Setting up your digital bouncer..."

# Ensure we are in the project root
cd "$(dirname "$0")/.."

# 1. Install Python dependencies using uv
echo "Installing Python dependencies..."
make setup

echo "✅ Sauver dependencies installed successfully!"
echo ""
echo "🔥 CRITICAL NEXT STEPS 🔥"
echo "1. Run the command: gemini"
echo "2. Select 'Login with Google' to authenticate (no API Key required!)."
echo "3. Type '/exit' when the prompt appears."
echo "4. Finally, run: gemini extensions install ."