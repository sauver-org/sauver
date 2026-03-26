.PHONY: sync check-sync version test test-skills test-skills-gemini

sync:
	@echo "Regenerating extension shims (.claude/ & .agent/) from skills/..."
	python3 scripts/sync_commands.py

check-sync:
	@echo "Checking extension shims are up to date..."
	python3 scripts/sync_commands.py --check

test:
	bash tests/test-install.sh

# Skill integration tests — run the /sauver skill against real EML fixtures
# via the mock MCP server. Requires claude (or gemini) CLI to be installed.
test-skills:
	cd tests/mock-mcp-server && npm install --silent
	bash tests/run-skill-tests.sh

test-skills-gemini:
	cd tests/mock-mcp-server && npm install --silent
	bash tests/run-skill-tests.sh --cli gemini

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
