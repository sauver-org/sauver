.PHONY: sync check-sync

sync:
	@echo "Regenerating .claude/commands/ from skills/..."
	python3 scripts/sync_commands.py

check-sync:
	@echo "Checking .claude/commands/ are up to date..."
	python3 scripts/sync_commands.py --check
