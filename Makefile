.PHONY: *

APP_DIR := packages/totem_app
CORE_DIR := packages/totem_core
WEB_DIR := packages/totem_web

clean:
	@echo "Cleaning build artifacts..."
	cd $(APP_DIR) && flutter clean
	rm -rf $(APP_DIR)/build/
	rm -rf $(APP_DIR)/.dart_tool/build/
	rm -rf ~/.gradle/caches/*
	rm -rf $(APP_DIR)/ios/Pods
	rm -rf $(APP_DIR)/ios/Podfile.lock
	rm -rf $(APP_DIR)/ios/.symlinks
	rm -rf $(APP_DIR)/ios/Flutter/Flutter.podspec
	rm -rf $(APP_DIR)/ios/Flutter/Flutter.framework
	rm -rf $(APP_DIR)/ios/Flutter/App.framework
# 	rm -rf ~/Library/Developer/Xcode/DerivedData/*

run:
	@echo "Running app..."
	cd $(APP_DIR) && flutter run

run-chrome:
	@echo "Running app in Chrome..."
	cd $(WEB_DIR) && flutter run -d chrome --web-browser-flag "--disable-web-security"

run-web:
	@echo "Running app in Chrome..."
	cd $(WEB_DIR) && flutter run -d web-server

build-runner:
	@echo "Running build_runner for code generation..."
	cd $(CORE_DIR) && dart run build_runner build --delete-conflicting-outputs
	cd $(APP_DIR) && dart run build_runner build --delete-conflicting-outputs
	cd $(WEB_DIR) && dart run build_runner build --delete-conflicting-outputs

build-runner-watch:
	@echo "Running build_runner in watch mode..."
	cd $(APP_DIR) && dart run build_runner watch --delete-conflicting-outputs

install:
	@echo "Getting dependencies..."
	flutter pub get

test:
	@echo "Running tests..."
	cd $(APP_DIR) && flutter test
	cd $(CORE_DIR) && flutter test
# 	cd $(WEB_DIR) && flutter test # Web doesn't have tests now

lint:
	@echo "Running linter..."
	cd $(APP_DIR) && flutter analyze
	cd $(CORE_DIR) && flutter analyze
	cd $(WEB_DIR) && flutter analyze

format:
	@echo "Formatting code..."
	dart format .

generate_api_models:
	cd $(CORE_DIR) && curl -L https://totem.org/api/mobile/openapi.json | dart run degenerate -i - -o lib/core/api --verbose --clean; dart format .

githooks:
	@echo "Setting up git hooks..."
	git config core.hooksPath .githooks
	@echo "Git hooks installed successfully!"

release:
	@echo "Creating release..."
	dart scripts/release.dart

