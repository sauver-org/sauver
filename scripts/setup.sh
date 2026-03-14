#!/bin/bash
set -e

echo "🛡️  Sauver Initialization 🛡️"
echo "Setting up your digital bouncer..."

# Ensure we are in the project root
cd "$(dirname "$0")/.."

# 1. Install Python dependencies using uv
echo "Installing Python dependencies..."
make setup

# 2. Configure Sauver settings
echo "⚙️  Configuring Sauver settings..."
# Run the Python-based configuration wizard
uv run src/main.py configure

echo "📦 Installing Google Workspace CLI for MCP support..."
npm install -g @googleworkspace/cli

# 3. Register Sauver globally in Gemini CLI settings
echo "Registering Sauver MCP server globally..."
python3 -c "
import json
import os

settings_dir = os.path.expanduser('~/.gemini')
settings_file = os.path.join(settings_dir, 'settings.json')
pwd = os.path.abspath('.')

if not os.path.exists(settings_dir):
    os.makedirs(settings_dir)

data = {}
if os.path.exists(settings_file):
    with open(settings_file, 'r') as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError:
            pass

data.setdefault('mcpServers', {})
data['mcpServers']['sauver'] = {
    'command': 'uv',
    'args': ['--directory', pwd, 'run', 'src/main.py']
}

with open(settings_file, 'w') as f:
    json.dump(data, f, indent=2)
"

echo "✅ Sauver successfully registered!"
echo ""
echo "🔥 CRITICAL NEXT STEPS 🔥"
echo "1. If you haven't already, install the Gemini CLI: npm install -g @google/gemini-cli"
echo "2. Authenticate with Google Workspace:"
echo "   gws auth setup     # walks you through Google Cloud project config"
echo "   gws auth login     # subsequent OAuth login"
echo "3. Run 'gemini' in your terminal."
echo "4. Select 'Login with Google' (No API Key required!)."
echo "5. You're done! Your digital bouncer is live."