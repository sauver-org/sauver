.PHONY: sync check-sync version test

sync:
	@echo "Regenerating extension shims (.claude/ & .agent/) from skills/..."
	python3 scripts/sync_commands.py

check-sync:
	@echo "Checking extension shims are up to date..."
	python3 scripts/sync_commands.py --check

test:
	bash tests/test-install.sh

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
