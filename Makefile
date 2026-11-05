SHELL := /usr/bin/env bash

PREFIX ?= $(HOME)/.local
BASHRC ?= $(HOME)/.bashrc

.PHONY: all install uninstall test lint help

all: lint test

install:
	PREFIX="$(PREFIX)" BASHRC="$(BASHRC)" ./install.sh

uninstall:
	PREFIX="$(PREFIX)" BASHRC="$(BASHRC)" ./uninstall.sh

test:
	./tests/run-tests.sh

lint:
	@bash -n bin/tmux-login
	@bash -n install.sh
	@bash -n uninstall.sh
	@bash -n tests/run-tests.sh
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -S error -x bin/tmux-login install.sh uninstall.sh tests/run-tests.sh; \
	else \
		echo "shellcheck не установлен — пропуск"; \
	fi

help:
	@printf '%s\n' \
		'tmux-login' \
		'' \
		'  make install     установить в ~/.local/bin и добавить хук в ~/.bashrc' \
		'  make uninstall   удалить хук и скрипт' \
		'  make test        запустить автотесты (изолированный tmux-сервер)' \
		'  make lint        bash -n + shellcheck (если установлен)' \
		'  make all         lint + test' \
		'' \
		'Переменные: PREFIX (по умолчанию ~/.local), BASHRC (по умолчанию ~/.bashrc)'
