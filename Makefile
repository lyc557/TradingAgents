.PHONY: help install sync dev test test-unit test-integration test-smoke run cli clean setup-rust

PYTHON ?= python3
PACKAGE := tradingagents
CLI_MODULE := cli.main
SMOKE_SCRIPT := scripts/smoke_structured_output.py

# Auto-detect macOS SDK (fixes clang sysroot mismatches on Homebrew LLVM).
# uv build isolation inherits CFLAGS but strips SDKROOT, so we pass -isysroot via CFLAGS.
SYSROOT := $(shell xcrun --show-sdk-path 2>/dev/null)
ifneq ($(SYSROOT),)
CFLAGS := -isysroot $(SYSROOT)
endif

# Ensure rustup/cargo are on PATH (needed by uv build sandbox on Python 3.14)
export PATH := $(PATH):$(HOME)/.cargo/bin

ifeq ($(shell command -v uv >/dev/null 2>&1; echo $$?),0)
RUN := uv run
SYNC := CFLAGS="$(CFLAGS)" PATH="$(PATH)" PYO3_USE_ABI3_FORWARD_COMPATIBILITY=1 uv sync --extra dev
PYTEST := uv run pytest
else
RUN :=
SYNC := CFLAGS="$(CFLAGS)" PATH="$(PATH)" PYO3_USE_ABI3_FORWARD_COMPATIBILITY=1 $(PYTHON) -m pip install -e ".[dev]"
endif

help:
	@printf "%s\n" \
		"Available targets:" \
		"  make install           Install project dependencies" \
		"  make sync              Alias of install" \
		"  make dev               Install in editable mode (pip fallback)" \
		"  make test              Run all tests" \
		"  make test-unit         Run unit tests only" \
		"  make test-integration  Run integration tests only" \
		"  make test-smoke        Run smoke tests only" \
		"  make run               Launch the CLI from source" \
		"  make cli               Alias of run" \
		"  make smoke PROVIDER=x  Run real-provider smoke script" \
		"  make setup-rust        Install Rust compiler (rustup)" \
		"  make clean             Remove caches and test artifacts"

install:
	$(SYNC)

sync: install

dev:
	CFLAGS="$(CFLAGS)" PYO3_USE_ABI3_FORWARD_COMPATIBILITY=1 $(PYTHON) -m pip install -e .

setup-rust:
	@if command -v rustc >/dev/null 2>&1; then \
		echo "Rust already installed: $$(rustc --version)"; \
	else \
		echo "Installing Rust via rustup ..."; \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; \
		echo "Run 'source $$HOME/.cargo/env' or restart your shell to use Rust."; \
	fi

test:
	$(PYTEST)

test-unit:
	$(PYTEST) -m unit

test-integration:
	$(PYTEST) -m integration

test-smoke:
	$(PYTEST) -m smoke

run:
	$(if $(RUN),$(RUN) ,)$(PYTHON) -m $(CLI_MODULE)

cli: run

smoke:
ifndef PROVIDER
	$(error PROVIDER is required, e.g. make smoke PROVIDER=openai)
endif
	$(if $(RUN),$(RUN) ,)$(PYTHON) $(SMOKE_SCRIPT) $(PROVIDER)

clean:
	find . -type d \( -name "__pycache__" -o -name ".pytest_cache" -o -name ".mypy_cache" -o -name ".ruff_cache" \) -prune -exec rm -rf {} +
	find . -type f \( -name "*.pyc" -o -name "*.pyo" \) -delete
	rm -rf build dist *.egg-info .coverage htmlcov
