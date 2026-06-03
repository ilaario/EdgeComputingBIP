CC ?= gcc
BUILD_DIR := build

PUBLISHER_SRC := publisher.c
SUBSCRIBER_SRC := subscriber.c
PUBLISHER_BIN := $(BUILD_DIR)/publisher
SUBSCRIBER_BIN := $(BUILD_DIR)/subscriber

UNAME_S := $(shell uname -s)
BREW_PREFIX := $(shell command -v brew >/dev/null 2>&1 && brew --prefix || true)

CPPFLAGS ?=
CFLAGS ?= -Wall -Wextra -O2 -pthread
LDFLAGS ?=
LDLIBS ?= -lpaho-mqtt3c -lm

ifeq ($(UNAME_S),Darwin)
ifneq ($(BREW_PREFIX),)
CPPFLAGS += -I$(BREW_PREFIX)/include
LDFLAGS += -L$(BREW_PREFIX)/lib
endif
endif

.PHONY: all help install-deps deps check-deps clean run-publisher run-subscriber publisher subscriber

all: check-deps $(PUBLISHER_BIN) $(SUBSCRIBER_BIN)

help:
	@echo "Available targets:"
	@echo "  make install-deps    Install the C toolchain and Eclipse Paho MQTT C library"
	@echo "  make check-deps      Check that MQTTClient headers and library are available"
	@echo "  make                 Build publisher and subscriber in $(BUILD_DIR)/"
	@echo "  make run-publisher   Build and run the publisher"
	@echo "  make run-subscriber  Build and run the subscriber"
	@echo "  make clean           Remove compiled binaries"

deps: install-deps

install-deps:
	@set -eu; \
	os="$$(uname -s)"; \
	case "$$os" in \
		Darwin) \
			if ! command -v xcode-select >/dev/null 2>&1 || ! xcode-select -p >/dev/null 2>&1; then \
				echo "Xcode Command Line Tools not found. Starting installation..."; \
				xcode-select --install; \
				echo "Run 'make install-deps' again after the installation finishes."; \
				exit 1; \
			fi; \
			if ! command -v brew >/dev/null 2>&1; then \
				echo "Homebrew not found. Install it from https://brew.sh, then run 'make install-deps' again."; \
				exit 1; \
			fi; \
			echo "Installing libpaho-mqtt, the Homebrew formula for Eclipse Paho MQTT C..."; \
			brew install libpaho-mqtt; \
			;; \
		Linux) \
			if command -v apt-get >/dev/null 2>&1; then \
				echo "Installing libpaho-mqtt-dev, the Debian/Ubuntu package for paho-mqtt-c..."; \
				sudo apt-get update; \
				sudo apt-get install -y build-essential libpaho-mqtt-dev; \
			elif command -v dnf >/dev/null 2>&1; then \
				echo "Installing paho-c-devel, the Fedora package for paho-mqtt-c..."; \
				sudo dnf install -y gcc make paho-c-devel; \
			elif command -v yum >/dev/null 2>&1; then \
				echo "Installing paho-c-devel, the RHEL/CentOS package for paho-mqtt-c..."; \
				sudo yum install -y gcc make paho-c-devel; \
			elif command -v zypper >/dev/null 2>&1; then \
				echo "Installing libpaho-mqtt-devel, the SUSE package for paho-mqtt-c..."; \
				sudo zypper install -y gcc make libpaho-mqtt-devel; \
			elif command -v pacman >/dev/null 2>&1; then \
				sudo pacman -S --needed base-devel; \
				if command -v yay >/dev/null 2>&1; then \
					echo "Installing paho-mqtt-c from AUR with yay..."; \
					yay -S --needed paho-mqtt-c; \
				elif command -v paru >/dev/null 2>&1; then \
					echo "Installing paho-mqtt-c from AUR with paru..."; \
					paru -S --needed paho-mqtt-c; \
				else \
					echo "Toolchain installed. On Arch, also install 'paho-mqtt-c' from AUR (yay/paru recommended)."; \
					exit 1; \
				fi; \
			else \
				echo "This Linux distribution is not supported automatically."; \
				echo "Install a C compiler, make, and the Eclipse Paho MQTT C development library."; \
				exit 1; \
			fi; \
			;; \
		*) \
			echo "Operating system not supported automatically: $$os"; \
			echo "Install a C compiler, make, and the Eclipse Paho MQTT C development library."; \
			exit 1; \
			;; \
	esac

check-deps: | $(BUILD_DIR)
	@command -v $(CC) >/dev/null 2>&1 || { echo "Compiler '$(CC)' not found. Run 'make install-deps'."; exit 1; }
	@printf '#include <MQTTClient.h>\nint main(void) { return 0; }\n' | \
		$(CC) $(CPPFLAGS) $(CFLAGS) -x c - -o $(BUILD_DIR)/.check-mqtt $(LDFLAGS) $(LDLIBS) >/dev/null 2>&1 || \
		{ echo "Eclipse Paho MQTT C was not found or cannot be linked. Run 'make install-deps'."; exit 1; }
	@rm -f $(BUILD_DIR)/.check-mqtt
	@echo "Dependencies OK."

$(BUILD_DIR):
	@mkdir -p $@

$(PUBLISHER_BIN): $(PUBLISHER_SRC) headers/publisher.h | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ $(LDFLAGS) $(LDLIBS)

$(SUBSCRIBER_BIN): $(SUBSCRIBER_SRC) headers/subscriber.h | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ $(LDFLAGS) $(LDLIBS)

publisher: check-deps $(PUBLISHER_BIN)

subscriber: check-deps $(SUBSCRIBER_BIN)

run-publisher: publisher
	./$(PUBLISHER_BIN)

run-subscriber: subscriber
	./$(SUBSCRIBER_BIN)

clean:
	@rm -f $(PUBLISHER_BIN) $(SUBSCRIBER_BIN) $(BUILD_DIR)/.check-mqtt
