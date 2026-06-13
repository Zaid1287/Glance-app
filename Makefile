# Glance — build & verify
.DEFAULT_GOAL := build

build:        ## Debug build of all targets
	swift build

release:      ## Optimized release build
	swift build -c release

test:         ## Run the CLT-friendly self-test suite
	swift run glance-selftest

xctest:       ## Run the XCTest suite (requires full Xcode)
	swift test

bar:          ## Run the menu-bar app
	swift run glance-bar

run:          ## Run the agent CLI, e.g. `make run ARGS="watch-downloads"`
	swift run glance $(ARGS)

clean:
	swift package clean
	rm -rf .build

help:         ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

.PHONY: build release test xctest bar run clean help
