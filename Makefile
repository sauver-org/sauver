.PHONY: setup format lint test sync check-sync all

setup:
	@echo "Installing dependencies using uv..."
	uv venv
	uv pip install -e ".[dev]"

format:
	uv run ruff check --fix src tests
	uv run ruff format src tests

lint:
	uv run ruff check src tests
	uv run mypy src tests

test:
	uv run pytest tests -v

sync:
	@echo "Regenerating .claude/commands/ from skills/..."
	python3 scripts/sync_commands.py

check-sync:
	@echo "Checking .claude/commands/ are up to date..."
	python3 scripts/sync_commands.py --check

all: format lint test check-sync
