#!/bin/bash
set -e

echo "🛡️  Sauver Initialization 🛡️"
echo "Setting up your digital bouncer..."

# Ensure we are in the project root
cd "$(dirname "$0")/.."

# 1. Install Python dependencies using uv
echo "Installing Python dependencies..."
make setup

echo "✅ Sauver is ready to protect your inbox!"
echo "Next step: Install the Gemini CLI extension by running 'gemini extensions install .'"