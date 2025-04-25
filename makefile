.PHONY: all clean build run watch

# Configuration
PRODUCT_NAME := $(shell grep -A 1 "name:" Package.swift | grep -v "name:" | tr -d '",[:space:]')
SOURCES := $(shell find Sources -type f -name "*.swift")
BUILD_DIR := .build
RELEASE_DIR := $(BUILD_DIR)/release

# Default target
all: build

# Clean build artifacts
clean:
	swift package clean
	rm -rf $(BUILD_DIR)

# Build the project
build: $(SOURCES)
	swift build

# Run the application
run: build
	swift run

# Build release version
release:
	swift build -c release

# Watch for changes and rebuild
watch:
	@echo "Watching for changes in Sources directory..."
	@fswatch -o Sources | xargs -n1 -I{} make build

# Install fswatch if not available (macOS)
install-deps:
	@which fswatch > /dev/null || brew install fswatch

# Help
help:
	@echo "Available targets:"
	@echo "  all        - Build the project (default)"
	@echo "  clean      - Clean build artifacts"
	@echo "  build      - Build the project"
	@echo "  run        - Build and run the project"
	@echo "  release    - Build release version"
	@echo "  watch      - Watch for changes and rebuild automatically"
	@echo "  install-deps - Install dependencies (fswatch)"
	@echo "  help       - Show this help message"
