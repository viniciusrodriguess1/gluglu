CC = gcc
CFLAGS = -Wall -Wextra -Isrc
SRC_DIR = src
BUILD_DIR = build

all: glugluc

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/parser.tab.c $(BUILD_DIR)/parser.tab.h: $(SRC_DIR)/parser.y | $(BUILD_DIR)
	bison -d $(SRC_DIR)/parser.y -o $(BUILD_DIR)/parser.tab.c

$(BUILD_DIR)/lex.yy.c: $(SRC_DIR)/lexer.l $(BUILD_DIR)/parser.tab.h | $(BUILD_DIR)
	flex -o $(BUILD_DIR)/lex.yy.c $(SRC_DIR)/lexer.l

glugluc: $(BUILD_DIR)/parser.tab.c $(BUILD_DIR)/lex.yy.c $(SRC_DIR)/ast.c
	$(CC) $(CFLAGS) -I$(BUILD_DIR) $^ -o $@

clean:
	rm -rf $(BUILD_DIR) glugluc