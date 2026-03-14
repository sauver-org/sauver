#!/bin/bash
set -e

echo "🛡️  Sauver Initialization 🛡️"
echo "Setting up your digital bouncer..."

# Ensure we are in the project root
cd "$(dirname "$0")/.."

echo "📦 Installing Google Workspace CLI for MCP support..."
npm install -g @googleworkspace/cli@latest

echo "🔍 Checking for gcloud CLI..."
if ! command -v gcloud &> /dev/null; then
  echo "⚠️  gcloud CLI not found. It is required for Google Workspace authentication."
  if command -v brew &> /dev/null; then
    echo "📦 Installing Google Cloud SDK via Homebrew..."
    brew install --cask google-cloud-sdk
  else
    echo "❌ Homebrew is not installed. Please install gcloud CLI manually from:"
    echo "   https://cloud.google.com/sdk/docs/install"
    exit 1
  fi
else
  echo "✅ gcloud CLI is installed."
fi

echo ""
echo "✅ Sauver ready!"
echo ""
echo "🔥 CRITICAL NEXT STEPS 🔥"
echo "1. Authenticate with Google Workspace:"
echo "   gws auth setup     # walks you through Google Cloud project config"
echo "   gws auth login     # subsequent OAuth login"
echo "2. If you haven't already, install the Gemini CLI: npm install -g @google/gemini-cli"
echo "3. Run 'gemini' in your terminal."
echo "4. Select 'Login with Google' (No API Key required!)."
echo "5. You're done! Your digital bouncer is live."
echo ""
echo "💡 To customize behavior (yolo_mode, slop settings, label name), edit GEMINI.md directly."
