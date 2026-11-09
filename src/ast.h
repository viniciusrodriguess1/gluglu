#ifndef AST_H
#define AST_H

#include <stdio.h>
#include <stdlib.h>

typedef enum {
    NODE_PROGRAM,
    NODE_VAR_DECL,
    NODE_ASSIGN,
    NODE_PRINT,
    NODE_READ,
    NODE_IF,
    NODE_WHILE,
    NODE_BLOCK,
    NODE_BIN_OP,
    NODE_NUM_INT,
    NODE_NUM_REAL,
    NODE_STRING,
    NODE_BOOL,
    NODE_ID
} NodeType;

typedef struct ASTNode {
    NodeType type;
    char *name;             // Identificadores ou literais texto
    int int_val;            // Literais inteiros
    double real_val;        // Literais reais
    char op;                // '+', '-', '*', '/', etc.
    struct ASTNode *left;
    struct ASTNode *right;
    struct ASTNode *next;   // Lista encadeada para declarações e instruções
} ASTNode;

ASTNode *create_node(NodeType type);
ASTNode *create_num_int(int val);
ASTNode *create_num_real(double val);
ASTNode *create_str(const char *val);
ASTNode *create_id(const char *name);
ASTNode *create_bin_op(char op, ASTNode *left, ASTNode *right);
void generate_code(ASTNode *root, FILE *out);

#endif