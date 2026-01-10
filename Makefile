.PHONY: help setup build test lint format fix clean hooks-install hooks-run

help:
	@echo "Usage: make [command]"
	@echo ""
	@echo "Setup:"
	@echo "  setup        - Setup development environment"
	@echo ""
	@echo "Build:"
	@echo "  build        - Build the project"
	@echo "  test         - Run tests"
	@echo "  clean        - Remove build artifacts"
	@echo ""
	@echo "Code Quality:"
	@echo "  lint         - Run SwiftLint"
	@echo "  format       - Run SwiftFormat"
	@echo "  fix          - Run format + lint"
	@echo ""
	@echo "Git Hooks:"
	@echo "  hooks-install - Install pre-commit hooks"
	@echo "  hooks-run     - Run hooks on all files"

setup: hooks-install
	@echo "Setup complete."
	@echo "Next: Configure Xcode Build Phase (see README.md)"

build:
	xcodebuild -scheme Flowease -destination 'platform=macOS' build

test:
	xcodebuild -scheme Flowease -destination 'platform=macOS' test

lint:
	@swiftlint lint --strict

format:
	@swiftformat .

fix: format lint

hooks-install:
	@pre-commit install
	@echo "Pre-commit hooks installed."

hooks-run:
	@pre-commit run --all-files

clean:
	@rm -rf build/
	@rm -rf .build/
	@echo "Build artifacts removed."
