# Default target
default: all

# Output directory
DIST_DIR := dist
BUILD_DIR := $(DIST_DIR)/build
PACKAGE_DIR := $(DIST_DIR)/package
TEMP_DIR := $(DIST_DIR)/temp

# Version information
VERSION := v2.2.2
BUILD := `git rev-parse --short HEAD`
LDFLAGS=-ldflags "-X=github.com/peak/s5cmd/v2/version.Version=$(VERSION) -X=github.com/peak/s5cmd/v2/version.GitCommit=$(BUILD)"

# Documentation files
DOC_FILES := CHANGELOG.md LICENSE README.md

# Test type selection based on OS
TEST_TYPE:=test_with_race
ifeq ($(OS),Windows_NT)
	TEST_TYPE=test_without_race
endif

# Semgrep configuration
semgrep ?= -
ifeq (,$(shell which semgrep))
	semgrep=echo "-- Running inside Docker --"; docker run --rm -v $$(pwd):/src returntocorp/semgrep:1.65.0 semgrep
else
	semgrep=semgrep
endif

# Original targets
.PHONY: all
all: clean build check test

.PHONY: build
build:
	@go build ${GCFLAGS} ${LDFLAGS} -mod=vendor .

.PHONY: test
test: $(TEST_TYPE)

.PHONY: test_with_race
test_with_race:
	@S5CMD_BUILD_BINARY_WITHOUT_RACE_FLAG=0 go test -mod=vendor -count=1 -race ./...

.PHONY: test_without_race
test_without_race:
	@S5CMD_BUILD_BINARY_WITHOUT_RACE_FLAG=1 go test -mod=vendor -count=1 ./...

##@ Bootstrap
# See following issues for why errors are ignored with `-e` flag:
# 	* https://github.com/golang/go/issues/61857
# 	* https://github.com/golang/go/issues/59186
.PHONY: bootstrap
bootstrap: ## Install tooling
	@go install $$(go list -e -f '{{join .Imports " "}}' ./internal/tools/tools.go)

.PHONY: check
check: vet staticcheck unparam semgrep check-fmt check-codegen check-gomod

.PHONY: staticcheck
staticcheck:
	@staticcheck -checks 'all,-ST1000' ./...

.PHONY: unparam
unparam:
	@unparam ./...

.PHONY: semgrep
semgrep: ## Run semgrep
	@$(semgrep) --quiet --metrics=off --error --config="r/dgryski.semgrep-go" --config .github/semgrep-rules.yaml .

.PHONY: vet
vet:
	@go vet -mod=vendor ./...

.PHONY: check-fmt
check-fmt:
	@if [ $$(go fmt -mod=vendor ./...) ]; then\
		echo "Go code is not formatted";\
		exit 1;\
	fi

.PHONY: check-codegen
check-codegen: gogenerate ## Check generated code is up-to-date
	@git diff --exit-code --

.PHONY: check-gomod
check-gomod: ## Check go.mod file
	@go mod tidy
	@git diff --exit-code -- go.sum go.mod

.PHONY: gogenerate
gogenerate:
	@go generate -mod vendor ./...

.PHONY: clean
clean:
	@rm -f ./s5cmd
	@rm -f ./s5cmd.exe

# Multi-architecture build targets
.PHONY: build-all
build-all: build-linux-amd64 build-linux-arm64 build-darwin-amd64 build-darwin-arm64 build-windows-amd64

.PHONY: build-linux-amd64
build-linux-amd64:
	@mkdir -p $(BUILD_DIR)/linux-amd64
	@echo "Building Linux AMD64..."
	@GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -mod=vendor -o $(BUILD_DIR)/linux-amd64/s5cmd
	@chmod +x $(BUILD_DIR)/linux-amd64/s5cmd

.PHONY: build-linux-arm64
build-linux-arm64:
	@mkdir -p $(BUILD_DIR)/linux-arm64
	@echo "Building Linux ARM64..."
	@GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -mod=vendor -o $(BUILD_DIR)/linux-arm64/s5cmd
	@chmod +x $(BUILD_DIR)/linux-arm64/s5cmd

.PHONY: build-darwin-amd64
build-darwin-amd64:
	@mkdir -p $(BUILD_DIR)/darwin-amd64
	@echo "Building macOS AMD64..."
	@GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -mod=vendor -o $(BUILD_DIR)/darwin-amd64/s5cmd
	@chmod +x $(BUILD_DIR)/darwin-amd64/s5cmd

.PHONY: build-darwin-arm64
build-darwin-arm64:
	@mkdir -p $(BUILD_DIR)/darwin-arm64
	@echo "Building macOS ARM64..."
	@GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -mod=vendor -o $(BUILD_DIR)/darwin-arm64/s5cmd
	@chmod +x $(BUILD_DIR)/darwin-arm64/s5cmd

.PHONY: build-windows-amd64
build-windows-amd64:
	@mkdir -p $(BUILD_DIR)/windows-amd64
	@echo "Building Windows AMD64..."
	@GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -mod=vendor -o $(BUILD_DIR)/windows-amd64/s5cmd.exe

# Copy documentation files
.PHONY: copy-docs
copy-docs:
	@for arch in linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 windows-amd64; do \
		mkdir -p $(TEMP_DIR)/$$arch; \
		for doc in $(DOC_FILES); do \
			cp $$doc $(TEMP_DIR)/$$arch/; \
		done; \
	done

# Package targets
.PHONY: package-all
package-all: build-all copy-docs
	@mkdir -p $(PACKAGE_DIR)
	@echo "Creating packages..."
	
	@# Linux AMD64
	@mkdir -p $(TEMP_DIR)/linux-amd64
	@cp $(BUILD_DIR)/linux-amd64/s5cmd $(TEMP_DIR)/linux-amd64/
	@cd $(TEMP_DIR)/linux-amd64 && tar czf ../../package/s5cmd_$(VERSION)_Linux-64bit.tar.gz *
	
	@# Linux ARM64
	@mkdir -p $(TEMP_DIR)/linux-arm64
	@cp $(BUILD_DIR)/linux-arm64/s5cmd $(TEMP_DIR)/linux-arm64/
	@cd $(TEMP_DIR)/linux-arm64 && tar czf ../../package/s5cmd_$(VERSION)_Linux-arm64.tar.gz *
	
	@# macOS AMD64
	@mkdir -p $(TEMP_DIR)/darwin-amd64
	@cp $(BUILD_DIR)/darwin-amd64/s5cmd $(TEMP_DIR)/darwin-amd64/
	@cd $(TEMP_DIR)/darwin-amd64 && tar czf ../../package/s5cmd_$(VERSION)_macOS-64bit.tar.gz *
	
	@# macOS ARM64
	@mkdir -p $(TEMP_DIR)/darwin-arm64
	@cp $(BUILD_DIR)/darwin-arm64/s5cmd $(TEMP_DIR)/darwin-arm64/
	@cd $(TEMP_DIR)/darwin-arm64 && tar czf ../../package/s5cmd_$(VERSION)_macOS-arm64.tar.gz *
	
	@# Windows AMD64
	@mkdir -p $(TEMP_DIR)/windows-amd64
	@cp $(BUILD_DIR)/windows-amd64/s5cmd.exe $(TEMP_DIR)/windows-amd64/
	@cd $(TEMP_DIR)/windows-amd64 && zip -r ../../package/s5cmd_$(VERSION)_Windows-64bit.zip *
	
	@echo "Cleaning up..."
	@rm -rf $(TEMP_DIR)

# Clean targets
.PHONY: clean-dist
clean-dist:
	@rm -rf $(DIST_DIR)

# Release target
.PHONY: release
release: clean-dist build-all package-all

.NOTPARALLEL:
