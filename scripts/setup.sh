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
CONFIG_FILE=".sauver-config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Let's set up your preferences:"
    
    # Auto Draft
    read -p "Should Sauver automatically create draft replies to slop? (y/n) [y]: " auto_draft
    auto_draft=${auto_draft:-y}
    [ "$auto_draft" == "y" ] && auto_draft="true" || auto_draft="false"

    # YOLO Mode
    read -p "YOLO Mode: Should Sauver automatically SEND replies (dangerous)? (y/n) [n]: " yolo_mode
    yolo_mode=${yolo_mode:-n}
    [ "$yolo_mode" == "y" ] && yolo_mode="true" || yolo_mode="false"

    # Job Slop
    read -p "Should Sauver treat job offers as slop? (y/n) [y]: " job_slop
    job_slop=${job_slop:-y}
    [ "$job_slop" == "y" ] && job_slop="true" || job_slop="false"

    # Investor Slop
    read -p "Should Sauver treat unsolicited investor outreach as slop? (y/n) [y]: " investor_slop
    investor_slop=${investor_slop:-y}
    [ "$investor_slop" == "y" ] && investor_slop="true" || investor_slop="false"

    cat <<EOF > "$CONFIG_FILE"
{
  "auto_draft": $auto_draft,
  "yolo_mode": $yolo_mode,
  "treat_job_offers_as_slop": $job_slop,
  "treat_unsolicited_investors_as_slop": $investor_slop,
  "quarantine_folder": "Quarantine"
}
EOF
    echo "✅ Configuration saved to $CONFIG_FILE"
else
    echo "✅ Configuration file already exists."
fi

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
echo "2. Run 'gemini' in your terminal."
echo "3. Select 'Login with Google' (No API Key required!)."
echo "4. You're done! Your digital bouncer is live."