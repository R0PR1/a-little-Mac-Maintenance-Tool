SHELL := /bin/bash

.PHONY: lint test syntax install uninstall

syntax:
	bash -n bin/mm lib/mm/*.sh scripts/*.sh

lint:
	shellcheck bin/mm lib/mm/*.sh scripts/*.sh

test:
	bats tests

install:
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh
