run:
	@echo "Running app..."
	flutter run

clean:
	@echo "Cleaning build artifacts..."
	flutter clean
	rm -rf build/
	rm -rf .dart_tool/build/

run-chrome:
	@echo "Running app in Chrome..."
	flutter run -d chrome

build-runner:
	@echo "Running build_runner for code generation..."
	dart run build_runner build --delete-conflicting-outputs

build-runner-watch:
	@echo "Running build_runner in watch mode..."
	dart run build_runner watch --delete-conflicting-outputs

install:
	@echo "Getting dependencies..."
	flutter pub get

test:
	@echo "Running tests..."
	flutter test

lint:
	@echo "Running linter..."
	flutter analyze

format:
	@echo "Formatting code..."
	dart format lib/ test/

generate_api_models:
	dart run swagger_parser

githooks:
	@echo "Setting up git hooks..."
	chmod +x .githooks/pre-commit
	chmod +x scripts/check-format.sh
	git config core.hooksPath .githooks
	@echo "Git hooks installed successfully!"
