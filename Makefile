.PHONY: *

APP_DIR := packages/totem_app
CORE_DIR := packages/totem_core
WEB_DIR := packages/totem_web

clean:
	@echo "Cleaning build artifacts..."
	cd $(CORE_DIR) && flutter clean
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
	cd $(WEB_DIR) && flutter clean

run:
	@echo "Running app..."
	cd $(APP_DIR) && flutter run

run-chrome:
	@echo "Running app in Chrome..."
	cd $(WEB_DIR) && flutter run -d chrome --web-port=5173 --web-hostname=0.0.0.0 --web-define=ASSET_BASE="http://localhost:5173/"

run-web:
	@echo "Running app in Web Server..."
	cd $(WEB_DIR) && flutter run -d web-server --web-port=5173 --web-hostname=0.0.0.0 --web-define=ASSET_BASE="http://localhost:5173/" --release

# Build the web app the way it deploys: mounted at /room/, assets fetched from
# a separate origin (here the local serve-web "CDN" on :5173) via ASSET_BASE.
build-web-release:
	@echo "Building web app..."
	cd $(WEB_DIR) && flutter build web --wasm --base-href "/room/" --web-define=ASSET_BASE="http://localhost:5173/"
	@echo "Built $(WEB_DIR)/build/web — serve it with: make serve-web"

# Serve the built bundle with CORS headers so an HTML document on another origin
# (e.g. Django at :8000) can fetch these assets via ASSET_BASE. Plain
# `python3 -m http.server` can't set headers, so use the helper script.
serve-web:
	dart scripts/serve_web.dart 5173 $(WEB_DIR)/build/web

# Build with the staging worker as ASSET_BASE and deploy it to Cloudflare.
# Requires wrangler auth (bunx wrangler login, or CLOUDFLARE_API_TOKEN +
# CLOUDFLARE_ACCOUNT_ID).
deploy-web-staging:
	@echo "Building web app (staging)"
	cd $(WEB_DIR) && flutter build web --wasm --base-href "/room/" --web-define=ASSET_BASE="https://totem-web-staging.lopkerk.workers.dev/"
	cd $(WEB_DIR) && bunx wrangler deploy --env staging

deploy-web-production:
	@echo "Building web app (production)"
	cd $(WEB_DIR) && flutter build web --wasm --base-href "/room/" --web-define=ASSET_BASE="https://totem-web-production.lopkerk.workers.dev/"
	cd $(WEB_DIR) && bunx wrangler deploy --env production

build-runner:
	@echo "Running build_runner for code generation..."
	cd $(CORE_DIR) && dart run build_runner build --delete-conflicting-outputs
	cd $(APP_DIR) && dart run build_runner build --delete-conflicting-outputs
# 	cd $(WEB_DIR) && dart run build_runner build --delete-conflicting-outputs

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
	cd $(WEB_DIR) && flutter test

test-app:
	@echo "Running app tests..."
	cd $(APP_DIR) && flutter test
	cd $(CORE_DIR) && flutter test

test-web:
	@echo "Running web tests..."
	cd $(WEB_DIR) && flutter test
	cd $(CORE_DIR) && flutter test

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

flutterfire:
	dart pub global activate flutterfire_cli
	@command -v flutterfire >/dev/null 2>&1 || { echo "Error: flutterfire CLI not found. Install with: dart pub global activate flutterfire_cli"; exit 1; }
	@test -d $(APP_DIR) || { echo "Error: $(APP_DIR) not found."; exit 1; }
	@test -d $(WEB_DIR) || { echo "Error: $(WEB_DIR) not found."; exit 1; }
	@echo "Configuring Firebase for app package (android + ios)..."
	cd $(APP_DIR) && flutterfire configure --platforms=android,ios,windows,macos
	# @echo "Configuring Firebase for web package..."
	# cd $(WEB_DIR) && flutterfire configure --platforms=web

release:
	@echo "Creating release..."
	dart scripts/release.dart
