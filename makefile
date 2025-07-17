.PHONY: all clean build run

# Configuration
BUILD_DIR := .build
RELEASE_DIR := $(BUILD_DIR)/release

# Default target
all: build

# Clean build artifacts
clean:
	swift package clean
	rm -rf $(BUILD_DIR)

# Build the project
build:
	swift build

# Run the application
run: build
	swift run

# Build release version
release:
	swift build -c release

# Help
help:
	@echo "Available targets:"
	@echo "  all        - Build the project (default)"
	@echo "  clean      - Clean build artifacts"
	@echo "  build      - Build the project"
	@echo "  run        - Build and run the project"
	@echo "  release    - Build release version"
	@echo "  help       - Show this help message"
