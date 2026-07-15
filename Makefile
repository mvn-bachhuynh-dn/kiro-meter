DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR

.PHONY: build test run bundle clean

build:
	swift build

test:
	swift test --enable-swift-testing --disable-xctest

# Create .app bundle and open it
run: bundle
	open .build/debug/KiroMeter.app

bundle: build
	@./scripts/bundle.sh

clean:
	swift package clean
	rm -rf .build/debug/KiroMeter.app
