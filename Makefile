BUILD   := build
RINHA_INTERPRETER_DIR ?= $(HOME)/Documents/rinha-compiladores-haskell
RINHA_AST_BIN ?= $(RINHA_INTERPRETER_DIR)/lib/bin/rinha
RINHA_STACK ?= stack
RINHA_RUNTIME_BIN ?= $(BUILD)/rinha-interp

.PHONY: all rinha-check up down build smoke test official-smoke official-test clean

# checagem rapida: os programas Rinha parseiam para AST JSON oficial
all: rinha-check

rinha-check:
	mkdir -p $(BUILD)
	chmod +x $(RINHA_AST_BIN)
	$(RINHA_AST_BIN) rinha/server.rinha > $(BUILD)/server.json
	$(RINHA_AST_BIN) rinha/lb.rinha > $(BUILD)/lb.json
	rm -rf $(BUILD)/compiler-src
	cd $(RINHA_INTERPRETER_DIR) && $(RINHA_STACK) --allow-different-user --no-system-ghc --install-ghc build --copy-bins --local-bin-path $(abspath $(BUILD))
	rm -f $(RINHA_RUNTIME_BIN).tmp
	cp $(BUILD)/rinha-compiladores $(RINHA_RUNTIME_BIN).tmp
	chmod +x $(RINHA_RUNTIME_BIN).tmp
	mv -f $(RINHA_RUNTIME_BIN).tmp $(RINHA_RUNTIME_BIN)
	@echo "ok: server.rinha e lb.rinha parseiam"

build: rinha-check
	docker compose build --no-cache

up: rinha-check
	docker compose rm -sf api1 api2 lb >/dev/null 2>&1 || true
	docker compose up --build -d

down:
	docker compose down --remove-orphans

stats: 
	docker compose stats

logs:
	docker compose logs -f

smoke:
	sh scripts/smoke.sh

test: smoke

official-smoke:
	sh scripts/official-test.sh smoke

official-test:
	sh scripts/official-test.sh full

clean:
	rm -rf $(BUILD)
	docker compose down --remove-orphans 2>/dev/null || true
