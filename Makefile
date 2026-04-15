.PHONY: sync check-sync lint format version test test-skills test-skills-gemini

# Core generation script for AI CLI shims
sync:
	@echo "Regenerating extension shims (.claude/ & .gemini/) from skills/..."
	python3 scripts/sync_commands.py

# Verify if shims are up-to-date (useful for CI/CD checks)
check-sync:
	@echo "Checking extension shims are up to date..."
	python3 scripts/sync_commands.py --check

# Ensures all codebase files stick to standard formatting and no trailing whitespaces exist
lint:
	@echo "Checking code formatting and trailing whitespaces..."
	@npx -y prettier --check "**/*.{js,md,json,html,gs}" --ignore-path .gitignore

# Non-destructively automatically fixes formatting errors caught by 'lint'
format:
	@echo "Formatting code and fixing whitespaces..."
	@npx -y prettier --write "**/*.{js,md,json,html,gs}" --ignore-path .gitignore

# Runs end-to-end testing on the install script structure
test:
	bash tests/test-install.sh

# Skill integration tests — run the /sauver skill against real EML fixtures
# via the mock MCP server. Requires claude (or gemini) CLI to be installed.
test-skills:
	cd tests/mock-mcp-server && npm install --silent
	bash tests/run-skill-tests.sh

# Runs the same skill integration testing suite targeting Gemini
test-skills-gemini:
	cd tests/mock-mcp-server && npm install --silent
	bash tests/run-skill-tests.sh --cli gemini

# Utility script to set the application version centrally
version:
	@test -n "$(V)" || (echo "Usage: make version V=x.y.z" && exit 1)
	@node -e " \
	  const fs = require('fs'); \
	  const p = JSON.parse(fs.readFileSync('mcp-server/package.json')); \
	  p.version = '$(V)'; \
	  fs.writeFileSync('mcp-server/package.json', JSON.stringify(p, null, 2) + '\n'); \
	"
	@python3 scripts/sync_commands.py
	@echo "Version set to $(V)"
