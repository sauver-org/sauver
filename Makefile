.PHONY: setup format lint test all

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

all: format lint test
