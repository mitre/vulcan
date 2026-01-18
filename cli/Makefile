# Vulcan CLI Makefile

.PHONY: all build test lint fmt vet sec clean install help

# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOVET=$(GOCMD) vet
GOFMT=gofmt
BINARY_NAME=vulcan
BINARY_UNIX=$(BINARY_NAME)_unix
BINARY_WINDOWS=$(BINARY_NAME).exe
BINARY_DARWIN=$(BINARY_NAME)_darwin

# Install directory
INSTALL_DIR=../bin

all: lint test build

## Build commands
build: ## Build the CLI binary
	$(GOBUILD) -o $(INSTALL_DIR)/$(BINARY_NAME) -v .

build-all: ## Build for all platforms
	GOOS=linux GOARCH=amd64 $(GOBUILD) -o $(INSTALL_DIR)/$(BINARY_NAME)-linux-amd64 -v .
	GOOS=linux GOARCH=arm64 $(GOBUILD) -o $(INSTALL_DIR)/$(BINARY_NAME)-linux-arm64 -v .
	GOOS=darwin GOARCH=amd64 $(GOBUILD) -o $(INSTALL_DIR)/$(BINARY_NAME)-darwin-amd64 -v .
	GOOS=darwin GOARCH=arm64 $(GOBUILD) -o $(INSTALL_DIR)/$(BINARY_NAME)-darwin-arm64 -v .
	GOOS=windows GOARCH=amd64 $(GOBUILD) -o $(INSTALL_DIR)/$(BINARY_NAME)-windows-amd64.exe -v .

## Test commands
test: ## Run tests
	$(GOTEST) -v ./...

test-coverage: ## Run tests with coverage
	$(GOTEST) -v -coverprofile=coverage.out ./...
	$(GOCMD) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

test-race: ## Run tests with race detector
	$(GOTEST) -race -v ./...

## Lint and format commands
lint: ## Run linter
	@which golangci-lint > /dev/null || (echo "Installing golangci-lint..." && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest)
	golangci-lint run

lint-fix: ## Run linter with auto-fix
	golangci-lint run --fix

fmt: ## Format code
	$(GOFMT) -s -w .

fmt-check: ## Check if code is formatted
	@test -z "$$($(GOFMT) -l .)" || (echo "Files need formatting:" && $(GOFMT) -l . && exit 1)

vet: ## Run go vet
	$(GOVET) ./...

## Security commands
sec: ## Run security scanner
	@which gosec > /dev/null || (echo "Installing gosec..." && go install github.com/securego/gosec/v2/cmd/gosec@latest)
	gosec -quiet ./...

sec-full: ## Run full security scan with details
	gosec -fmt=json -out=security-report.json ./...
	@echo "Security report: security-report.json"
	gosec ./...

secrets: ## Scan for hardcoded secrets
	@which gitleaks > /dev/null || (echo "Installing gitleaks..." && brew install gitleaks 2>/dev/null || go install github.com/gitleaks/gitleaks/v8@latest)
	gitleaks detect --source . --no-git -v

secrets-baseline: ## Generate secrets baseline (for known false positives)
	gitleaks detect --source . --no-git --report-format json --report-path .gitleaks-baseline.json || true
	@echo "Baseline created: .gitleaks-baseline.json"

vuln: ## Check for known vulnerabilities
	@which govulncheck > /dev/null || (echo "Installing govulncheck..." && go install golang.org/x/vuln/cmd/govulncheck@latest)
	govulncheck ./...

## Dependency commands
deps: ## Download dependencies
	$(GOCMD) mod download

deps-update: ## Update dependencies
	$(GOCMD) get -u ./...
	$(GOCMD) mod tidy

deps-audit: ## Audit dependencies for issues
	$(GOCMD) mod verify

## Clean commands
clean: ## Clean build artifacts
	$(GOCLEAN)
	rm -f $(INSTALL_DIR)/$(BINARY_NAME)*
	rm -f coverage.out coverage.html security-report.json

## Install commands
install: build ## Install CLI to bin directory
	@echo "Installed to $(INSTALL_DIR)/$(BINARY_NAME)"

install-tools: ## Install development tools
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install github.com/securego/gosec/v2/cmd/gosec@latest
	go install golang.org/x/vuln/cmd/govulncheck@latest
	go install github.com/goreleaser/goreleaser@latest

## CI commands
ci: fmt-check vet lint sec secrets test build ## Run all CI checks
	@echo "All CI checks passed!"

ci-quick: fmt-check vet test build ## Quick CI checks (no security scans)
	@echo "Quick CI checks passed!"

## Release commands
release-dry: ## Dry run release
	@which goreleaser > /dev/null || (echo "Installing goreleaser..." && go install github.com/goreleaser/goreleaser@latest)
	goreleaser release --snapshot --clean

## Help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
