# Makefile for inference-observatory
#
# Targets are intentionally portable and rely only on a working Go
# toolchain plus standard coreutils. Version metadata is injected at
# link time from git where available; missing git falls back to
# "unknown" values so the build never fails on a tarball checkout.

BINARY    := bin/observatory
PKG       := github.com/pillaiharish/inference-observatory
BUILD_PKG := $(PKG)/internal/buildinfo

VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
COMMIT  ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
DATE    ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

LDFLAGS := -X $(BUILD_PKG).Version=$(VERSION) -X $(BUILD_PKG).Commit=$(COMMIT) -X $(BUILD_PKG).Date=$(DATE)

.PHONY: all build test fmt fmt-check vet check clean
.PHONY: telemetry-config telemetry-preflight telemetry-up telemetry-down telemetry-logs telemetry-validate

COMPOSE      := docker compose -f deploy/compose.yaml
ENV_FILE     := deploy/.env
ENV_FALLBACK := deploy/.env.example

# Use deploy/.env if it exists, otherwise fall back to the example so
# commands like `make telemetry-config` work without a manual copy.
ifeq ($(wildcard $(ENV_FILE)),$(ENV_FILE))
  COMPOSE_ENV := --env-file $(ENV_FILE)
  ENV_FILE_OR_FALLBACK := $(ENV_FILE)
else
  COMPOSE_ENV := --env-file $(ENV_FALLBACK)
  ENV_FILE_OR_FALLBACK := $(ENV_FALLBACK)
endif

all: build

build:
	@mkdir -p bin
	go build -ldflags "$(LDFLAGS)" -o $(BINARY) ./cmd/observatory

test:
	go test ./...

fmt:
	gofmt -w .

fmt-check:
	@out=$$(gofmt -l . 2>&1); if [ -n "$$out" ]; then \
		echo "gofmt would reformat:"; echo "$$out"; exit 1; fi

vet:
	go vet ./...

check: fmt-check vet test
	@echo "all local checks passed"

clean:
	rm -rf bin coverage.out

# --------------------------------------------------------------------------- #
# Telemetry stack (v0.2) — requires a Linux NVIDIA GPU host for live runs.
# Static targets (telemetry-config) work without a GPU or Docker daemon.
# --------------------------------------------------------------------------- #

telemetry-config:
	$(COMPOSE) $(COMPOSE_ENV) config

telemetry-preflight:
	./scripts/preflight-gpu.sh

telemetry-up:
	$(COMPOSE) $(COMPOSE_ENV) up -d

telemetry-down:
	$(COMPOSE) $(COMPOSE_ENV) down

telemetry-logs:
	$(COMPOSE) $(COMPOSE_ENV) logs -f

telemetry-validate:
	OBSERVATORY_ENV_FILE=$(ENV_FILE_OR_FALLBACK) ./scripts/validate-telemetry.sh