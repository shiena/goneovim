TAG := $(shell git describe --tags --abbrev=0)
VERSION := $(shell git describe --tags)
VERSION_HASH := $(shell git rev-parse HEAD)

# deployment directory
DEPLOYMENT_WINDOWS:=cmd/goneovim/deploy/windows
DEPLOYMENT_DARWIN:=cmd/goneovim/deploy/darwin
DEPLOYMENT_LINUX:=cmd/goneovim/deploy/linux
DEPLOYMENT_FREEBSD:=cmd/goneovim/deploy/freebsd

# runtime directory
ifeq ($(OS),Windows_NT)
RUNTIME_DIR=$(DEPLOYMENT_WINDOWS)/
OSNAME=Windows
else ifeq ($(shell uname), Darwin)
RUNTIME_DIR=$(DEPLOYMENT_DARWIN)/goneovim.app/Contents/Resources/
OSNAME=Darwin
else ifeq ($(shell uname), Linux)
RUNTIME_DIR=$(DEPLOYMENT_LINUX)/
OSNAME=Linux
else ifeq ($(shell uname), FreeBSD)
RUNTIME_DIR=$(DEPLOYMENT_FREEBSD)/
OSNAME=FreeBSD
endif

# qt bindings cmd
GOQTSETUP:=$(shell go env GOPATH)/bin/qtsetup
GOQTMOC:=$(shell go env GOPATH)/bin/qtmoc
GOQTDEPLOY:=$(shell go env GOPATH)/bin/qtdeploy

.PHONY: app qt_bindings clean linux windows darwin debug test help

# If the first argument is "run"...
ifeq (debug,$(firstword $(MAKECMDGOALS)))
  # use the rest as arguments for "run"
  DEBUG_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  # ...and turn them into do-nothing targets
  $(eval $(DEBUG_ARGS):;@:)
endif


app: ## Build goneovim
	@go mod vendor  ; \
	test -f ./editor/moc.go & $(GOQTMOC) desktop ./cmd/goneovim && \
	go generate && \
	$(GOQTDEPLOY) build desktop ./cmd/goneovim && \
	cp -pR runtime $(RUNTIME_DIR)
ifeq ($(OSNAME),Darwin)
	@/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $(VERSION_HASH)" "./cmd/goneovim/deploy/darwin/goneovim.app/Contents/Info.plist" && \
	/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $(VERSION)"  "./cmd/goneovim/deploy/darwin/goneovim.app/Contents/Info.plist" && \
	cd cmd/goneovim/deploy/darwin/goneovim.app/Contents/Frameworks/ && \
	rm -fr QtQuick.framework && \
	rm -fr QtVirtualKeyboard.framework
endif


qt_bindings: ## Setup Qt bindings for Go.
ifeq ($(OSNAME),Darwin)
	@go get -v github.com/akiyosi/qt && \
	go get github.com/akiyosi/qt/internal/cmd@v0.0.0-20230719061055-7747cdc680f3 && \
	go get github.com/akiyosi/qt/internal/binding/files/docs/5.12.0 && \
	go get github.com/akiyosi/qt/internal/binding/files/docs/5.13.0 && \
	go get github.com/akiyosi/qt/internal/cmd/moc@v0.0.0-20230719061055-7747cdc680f3 && \
	go install -v -tags=no_env github.com/akiyosi/qt/cmd/...  && \
	go mod vendor  && \
	git clone https://github.com/akiyosi/env_darwin_amd64_513.git vendor/github.com/akiyosi/env_darwin_amd64_513
	$(GOQTSETUP) -test=false
else ifeq ($(OSNAME),Linux)
	@go get github.com/akiyosi/qt/internal/cmd@v0.0.0-20230719061055-7747cdc680f3 && \
	go get github.com/akiyosi/qt/internal/binding/files/docs/5.12.0 && \
	go get github.com/akiyosi/qt/internal/binding/files/docs/5.13.0 && \
	go get github.com/akiyosi/qt/internal/cmd/moc@v0.0.0-20230719061055-7747cdc680f3 && \
	go get -v github.com/akiyosi/qt && \
	go install -v -tags=no_env github.com/akiyosi/qt/cmd/...  && \
	go mod vendor  && \
	git clone https://github.com/akiyosi/env_linux_amd64_513.git vendor/github.com/akiyosi/env_linux_amd64_513
	$(GOQTSETUP) -test=false
else ifeq ($(OSNAME),FreeBSD)
	@go get github.com/akiyosi/qt/internal/cmd@v0.0.0-20230719061055-7747cdc680f3 && \
	go get github.com/akiyosi/qt/internal/binding/files/docs/5.12.0 && \
	go get github.com/akiyosi/qt/internal/binding/files/docs/5.13.0 && \
	go get github.com/akiyosi/qt/internal/cmd/moc@v0.0.0-20230719061055-7747cdc680f3 && \
	go get -v github.com/akiyosi/qt && \
	go install -v -tags=no_env github.com/akiyosi/qt/cmd/...  && \
	go mod vendor  && \
	git clone https://github.com/akiyosi/env_linux_amd64_513.git vendor/github.com/akiyosi/env_linux_amd64_513
	$(GOQTSETUP) -test=false
else ifeq ($(OSNAME),Windows)
	@go.exe get -v github.com/akiyosi/qt && \
	go.exe get github.com/akiyosi/qt/internal/cmd@v0.0.0-20230719061055-7747cdc680f3 && \
	go.exe get github.com/akiyosi/qt/internal/binding/files/docs/5.12.0 && \
	go.exe get github.com/akiyosi/qt/internal/binding/files/docs/5.13.0 && \
	go.exe get github.com/akiyosi/qt/internal/cmd/moc@v0.0.0-20230719061055-7747cdc680f3 && \
	go.exe install -v -tags=no_env github.com/akiyosi/qt/cmd/...  && \
	go.exe mod vendor  && \
	git.exe clone https://github.com/akiyosi/env_windows_amd64_513.git vendor/github.com/akiyosi/env_windows_amd64_513 
	$(GOQTSETUP) -test=false
endif

deps: ## Get dependent libraries.
	@go get github.com/akiyosi/goneovim
	@$(GOQTMOC) desktop ./cmd/goneovim

test: ## Test goneovim
	@go generate && go test ./editor

clean: ## Delete pre-built application binaries and Moc files.
	@rm -fr cmd/goneovim/deploy/*
	@rm -fr editor/*moc*

linux: ## Build binaries for Linux using Docker.
	@go generate && \
	cd cmd/goneovim && \
	$(GOQTDEPLOY) -docker build linux_static && \
	cp -pR ../../runtime $(DEPLOYMENT_LINUX)

windows: ## Build binaries for Windows using Docker.
	@go generate && \
	cd cmd/goneovim && \
	$(GOQTDEPLOY) -docker build windows_64_static && \
	cp -pR ../../runtime $(DEPLOYMENT_WINDOWS)

darwin: ## Build binaries for MacOS using Vagrant.
	@go generate && \
	cd cmd/goneovim && \
	$(GOQTDEPLOY) -vagrant build darwin/darwin && \
	cp -pR ../../runtime $(DEPLOYMENT_WINDOWS)

debug: ## Debug runs of the application using delve.
	@test -f ./editor/moc.go & $(GOQTMOC) desktop ./cmd/goneovim && \
	cd cmd/goneovim && \
	dlv debug --output goneovim --build-flags -race -- $(DEBUG_ARGS)

help: ## Display this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-20s %s\n", $$1, $$2}'
