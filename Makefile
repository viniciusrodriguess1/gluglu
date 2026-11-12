CC = gcc
CFLAGS = -Wall -Wextra -Isrc
SRC_DIR = src
BUILD_DIR = build

all: glugluc

.PHONY: all clean test

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/parser.tab.c $(BUILD_DIR)/parser.tab.h: $(SRC_DIR)/parser.y | $(BUILD_DIR)
	bison -d $(SRC_DIR)/parser.y -o $(BUILD_DIR)/parser.tab.c

$(BUILD_DIR)/lex.yy.c: $(SRC_DIR)/lexer.l $(BUILD_DIR)/parser.tab.h | $(BUILD_DIR)
	flex -o $(BUILD_DIR)/lex.yy.c $(SRC_DIR)/lexer.l

glugluc: $(BUILD_DIR)/parser.tab.c $(BUILD_DIR)/lex.yy.c $(SRC_DIR)/ast.c $(SRC_DIR)/symtab.c
	$(CC) $(CFLAGS) -I$(BUILD_DIR) $^ -o $@

test: glugluc
	@set -eu; \
	for file in exemplos/media.glu exemplos/idade.glu exemplos/contador.glu exemplos/alimentacao.glu; do \
		./glugluc < "$$file" > /dev/null; \
		printf 'OK (valido): %s\n' "$$file"; \
	done; \
	if output=$$(./glugluc < tests/invalid/erro_nao_declarada.glu 2>&1); then \
		echo "ERRO: tests/invalid/erro_nao_declarada.glu deveria falhar"; exit 1; \
	fi; \
	case "$$output" in \
		*"identificador 'resultado' nao declarado."*) printf 'OK (invalido): tests/invalid/erro_nao_declarada.glu\n' ;; \
		*) printf '%s\n' "$$output"; echo "ERRO: diagnostico esperado nao encontrado"; exit 1 ;; \
	esac; \
	if output=$$(./glugluc < tests/invalid/erro_tipo_incompativel.glu 2>&1); then \
		echo "ERRO: tests/invalid/erro_tipo_incompativel.glu deveria falhar"; exit 1; \
	fi; \
	case "$$output" in \
		*"tipo incompativel na atribuicao para 'idade'."*) printf 'OK (invalido): tests/invalid/erro_tipo_incompativel.glu\n' ;; \
		*) printf '%s\n' "$$output"; echo "ERRO: diagnostico esperado nao encontrado"; exit 1 ;; \
	esac

clean:
	rm -rf $(BUILD_DIR) glugluc