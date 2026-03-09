.PHONY: all clean build

BUILD_DIR := .build

all: build

clean:
	swift package clean
	rm -rf $(BUILD_DIR)

build:
	swift build -c release
