SHELL := /bin/bash

PREFIX  ?= $(HOME)/.local
BINDIR  ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share/mm

.PHONY: help syntax lint test install uninstall reinstall link

help:
	@printf '%s\n' \
		'make syntax        Validate Bash syntax' \
		'make lint          Run ShellCheck' \
		'make test          Run Bats tests' \
		'make install       Copy mm into $(DATADIR) and put a launcher in $(BINDIR)' \
		'make uninstall     Remove the launcher and copied payload' \
		'make reinstall     uninstall then install' \
		'make link          Launcher in $(BINDIR) pointing at this checkout' \
		'' \
		'PREFIX=$(PREFIX)' \
		'Override with: make install PREFIX=$$HOME/.local'

syntax:
	bash -n bin/mm lib/mm/*.sh scripts/*.sh

lint:
	shellcheck bin/mm lib/mm/*.sh scripts/*.sh

test:
	bats tests

install:
	PREFIX="$(PREFIX)" MM_INSTALL_DIR="$(DATADIR)" MM_BIN_DIR="$(BINDIR)" ./scripts/install.sh

uninstall:
	PREFIX="$(PREFIX)" MM_INSTALL_DIR="$(DATADIR)" MM_BIN_DIR="$(BINDIR)" ./scripts/uninstall.sh

reinstall: uninstall install

link:
	PREFIX="$(PREFIX)" MM_BIN_DIR="$(BINDIR)" MM_LINK_CHECKOUT=1 ./scripts/install.sh
