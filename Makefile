SHELL := /bin/bash

FLUTTER ?= flutter
IOS_DEVICE ?= iphone
ANDROID_DEVICE ?= android

.PHONY: help pub-get analyze test check clean run-ios run-android \
	build-apk-debug build-ios-sim build-appbundle-release

help: ## Show available targets
	@awk 'BEGIN {FS = ": ## "}; /^[a-zA-Z0-9_.-]+: ## / {printf "\033[36m%-24s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

pub-get: ## Install Flutter dependencies
	$(FLUTTER) pub get

analyze: ## Run static analysis
	$(FLUTTER) analyze

test: ## Run unit and widget tests
	$(FLUTTER) test

check: pub-get analyze test ## Run the standard local quality gate

clean: ## Clean Flutter build artifacts
	$(FLUTTER) clean

run-ios: ## Run the app on the default iOS device target
	$(FLUTTER) run -d $(IOS_DEVICE)

run-android: ## Run the app on the default Android device target
	$(FLUTTER) run -d $(ANDROID_DEVICE)

build-apk-debug: ## Build a debug Android APK
	$(FLUTTER) build apk --debug

build-ios-sim: ## Build an iOS simulator app without codesigning
	$(FLUTTER) build ios --simulator --no-codesign

build-appbundle-release: ## Build a signed Android release app bundle
	$(FLUTTER) build appbundle --release
