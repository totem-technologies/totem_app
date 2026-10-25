.PHONY: *

APP_DIR := packages/totem_app
CORE_DIR := packages/totem_core
WEB_DIR := packages/totem_web
BENCHMARK_DIR := packages/totem_benchmark
WIDGETBOOK_DIR := packages/totem_widgetbook
WEB_VIDEO_FLAGS := --dart-define=WEBRTC_USE_HTML_ELEMENT_VIEW=true
NATIVE_FLUTTER ?= fvm flutter
NATIVE_DART ?= fvm dart
WEB_FLUTTER ?= fvm spawn 3.47.7
WEB_BUILD_DART ?= FVM_FLUTTER_VERSION=3.47.7 fvm dart

# Each Flutter suite also runs test files concurrently. Bound package-level
# parallelism to avoid starting four compilers and their workers at once.
TEST_JOBS ?= 2
TEST_ARGS ?=

clean:
	@echo "Cleaning build artifacts..."
	cd $(CORE_DIR) && $(NATIVE_FLUTTER) clean
	cd $(APP_DIR) && $(NATIVE_FLUTTER) clean
	rm -rf $(APP_DIR)/build/
	rm -rf $(APP_DIR)/.dart_tool/build/
	rm -rf ~/.gradle/caches/*
	rm -rf $(APP_DIR)/ios/.symlinks
	rm -rf $(APP_DIR)/ios/Flutter/Flutter.framework
	rm -rf $(APP_DIR)/ios/Flutter/App.framework
# 	rm -rf ~/Library/Developer/Xcode/DerivedData/*
	cd $(WEB_DIR) && $(WEB_FLUTTER) clean

# Compose packages/*/.env from the layered sources in config/ for a flavor.
# This is the single source of truth for runtime config; see config/README.md.
# A deploy overwrites .env with the deployed flavor, so run `make env-dev` to
# get back to your local development config.
env-dev:
	$(NATIVE_DART) scripts/setup_env.dart development

env-staging:
	$(NATIVE_DART) scripts/setup_env.dart staging

env-prod:
	$(NATIVE_DART) scripts/setup_env.dart production

# The workspace has one active pubspec.lock. These targets select the matching
# resolution, clear incompatible .dart_tool metadata, and enforce the lockfile.
prepare-native:
	./scripts/select_flutter_lockfile.sh native
	$(NATIVE_FLUTTER) pub get --enforce-lockfile

prepare-web:
	./scripts/select_flutter_lockfile.sh web
	$(WEB_FLUTTER) pub get --enforce-lockfile

run: prepare-native env-dev
	@echo "Running app..."
	cd $(APP_DIR) && $(NATIVE_FLUTTER) run

# ASSET_BASE is empty in dev: the splash assets in web/index.html use the
# {{ASSET_BASE}} placeholder, so define it (to "") here or the token leaks into
# the splash <img>/background URLs. Empty means relative, which resolves fine
# against the dev server's "/" base href.
run-chrome: prepare-web env-dev
	@echo "Running app in Chrome..."
	cd $(WEB_DIR) && $(WEB_FLUTTER) run -d chrome $(WEB_VIDEO_FLAGS) --web-port=5173 --web-hostname=0.0.0.0 --web-define=ASSET_BASE="http://localhost:5173/"

run-web: prepare-web env-dev
	@echo "Running app in Web Server..."
	cd $(WEB_DIR) && $(WEB_FLUTTER) run -d web-server $(WEB_VIDEO_FLAGS) --web-port=5173 --web-hostname=0.0.0.0 --web-define=ASSET_BASE="http://localhost:5173/" --release

# Build the web app the way it deploys: mounted at /room/, assets fetched from
# a separate origin (here the local serve-web "CDN" on :5173). The `development`
# flavor maps to that local CDN and composes the development .env.
build-web-release: prepare-web env-dev
	@echo "Building web app..."
	$(WEB_BUILD_DART) scripts/web_build.dart
	@echo "Built $(WEB_DIR)/build/web — serve it with: make serve-web"

# Serve the built bundle with CORS headers so an HTML document on another origin
# (e.g. Django at :8000) can fetch these assets via ASSET_BASE. Plain
# `python3 -m http.server` can't set headers, so use the helper script.
serve-web:
	$(NATIVE_DART) scripts/serve_web.dart 5173 $(WEB_DIR)/build/web

# Build with the staging worker as ASSET_BASE and deploy it to Cloudflare.
# Requires wrangler auth (bunx wrangler login, or CLOUDFLARE_API_TOKEN +
# CLOUDFLARE_ACCOUNT_ID).
deploy-web-staging: prepare-web env-staging
	@echo "Building web app (staging)"
	$(WEB_BUILD_DART) scripts/web_build.dart
	cd $(WEB_DIR) && bunx wrangler deploy --env staging

deploy-web-production: prepare-web env-prod
	@echo "Building web app (production)"
	$(WEB_BUILD_DART) scripts/web_build.dart
	cd $(WEB_DIR) && bunx wrangler deploy --env production

build-runner:
	@echo "Running build_runner for code generation..."
	cd $(CORE_DIR) && $(NATIVE_DART) run build_runner build --delete-conflicting-outputs
	cd $(APP_DIR) && $(NATIVE_DART) run build_runner build --delete-conflicting-outputs
# 	cd $(WEB_DIR) && dart run build_runner build --delete-conflicting-outputs

build-runner-watch:
	@echo "Running build_runner in watch mode..."
	cd $(APP_DIR) && $(NATIVE_DART) run build_runner watch --delete-conflicting-outputs

install: prepare-native

test:
	$(MAKE) test-native
	$(MAKE) test-web

test-native: prepare-native
	@echo "Running native/shared tests..."
	$(MAKE) --jobs=$(TEST_JOBS) test-core test-app test-benchmark test-widgetbook test-scripts TEST_PUB=--no-pub

test-web: prepare-web
	@echo "Running web tests..."
	cd $(WEB_DIR) && $(WEB_FLUTTER) test --no-pub --platform=chrome

test-benchmark:
	cd $(BENCHMARK_DIR) && $(NATIVE_FLUTTER) test $(TEST_PUB) $(TEST_ARGS)
	node --test scripts/benchmark/metrics.test.mjs

benchmark-build:
	node scripts/benchmark/run.mjs build $(BENCHMARK_ARGS)

benchmark-serve:
	node scripts/benchmark/run.mjs serve $(BENCHMARK_ARGS)

benchmark:
	node scripts/benchmark/run.mjs run $(BENCHMARK_ARGS)

# Widgetbook catalog of totem_core widgets. Run `make widgetbook-gen` after
# adding or changing a *.stories.dart file to regenerate the story code.
widgetbook:
	cd $(WIDGETBOOK_DIR) && $(NATIVE_FLUTTER) run -d chrome --web-port=5174

widgetbook-gen:
	cd $(WIDGETBOOK_DIR) && $(NATIVE_DART) run build_runner build

widgetbook-build:
	cd $(WIDGETBOOK_DIR) && $(NATIVE_FLUTTER) build web --release

test-widgetbook:
	cd $(WIDGETBOOK_DIR) && $(NATIVE_FLUTTER) test $(TEST_PUB) $(TEST_ARGS)

test-app:
	@echo "Running app tests..."
	cd $(APP_DIR) && $(NATIVE_FLUTTER) test $(TEST_PUB) $(TEST_ARGS)

test-core:
	@echo "Running core tests..."
	cd $(CORE_DIR) && $(NATIVE_FLUTTER) test $(TEST_PUB) $(TEST_ARGS)

test-scripts:
	$(NATIVE_FLUTTER) test scripts/test $(TEST_PUB) $(TEST_ARGS)

lint:
	$(MAKE) lint-native
	$(MAKE) lint-web

lint-native: prepare-native
	@echo "Running native/shared linter..."
	$(NATIVE_DART) run scripts/check_media_boundary.dart
	$(NATIVE_DART) run scripts/check_omittable_interpolation.dart
	cd $(APP_DIR) && $(NATIVE_FLUTTER) analyze --no-pub
	cd $(CORE_DIR) && $(NATIVE_FLUTTER) analyze --no-pub
	cd $(BENCHMARK_DIR) && $(NATIVE_FLUTTER) analyze --no-pub
	cd $(WIDGETBOOK_DIR) && $(NATIVE_FLUTTER) analyze --no-pub

lint-web: prepare-web
	@echo "Running Web linter..."
	cd $(WEB_DIR) && $(WEB_FLUTTER) analyze --no-pub

format:
	@echo "Formatting code..."
	# Only files git tracks or would track, so build output and scratch are skipped.
	git ls-files -z --cached --others --exclude-standard '*.dart' | xargs -0 $(NATIVE_DART) format

generate_api_models:
	cd $(CORE_DIR) && curl -L https://totem.local/api/mobile/openapi.json | $(NATIVE_DART) run degenerate -i - -o lib/core/api --verbose --clean; $(NATIVE_DART) format .
	# cd $(CORE_DIR) && curl -L https://totem.org/api/mobile/openapi.json | dart run degenerate -i - -o lib/core/api --verbose --clean; dart format .

githooks:
	@echo "Setting up git hooks..."
	git config core.hooksPath .githooks
	@echo "Git hooks installed successfully!"

flutterfire:
	$(NATIVE_DART) pub global activate flutterfire_cli
	@command -v flutterfire >/dev/null 2>&1 || { echo "Error: flutterfire CLI not found. Install with: dart pub global activate flutterfire_cli"; exit 1; }
	@test -d $(APP_DIR) || { echo "Error: $(APP_DIR) not found."; exit 1; }
	@test -d $(WEB_DIR) || { echo "Error: $(WEB_DIR) not found."; exit 1; }
	@echo "Configuring Firebase for app package (android + ios)..."
	cd $(APP_DIR) && flutterfire configure --platforms=android,ios,windows,macos
	# @echo "Configuring Firebase for web package..."
	# cd $(WEB_DIR) && flutterfire configure --platforms=web

release:
	@echo "Creating release..."
	$(NATIVE_DART) scripts/release.dart
