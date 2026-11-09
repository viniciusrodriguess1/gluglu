#ifndef AST_H
#define AST_H

#include <stdio.h>
#include <stdlib.h>
#include "symtab.h"

typedef enum {
    NODE_PROGRAM,
    NODE_VAR_DECL,
    NODE_ASSIGN,
    NODE_PRINT,
    NODE_READ,
    NODE_IF,
    NODE_WHILE,
    NODE_FOR,
    NODE_BREAK,
    NODE_CONTINUE,
    NODE_FUNC_DECL,
    NODE_PARAM,
    NODE_FUNC_CALL,
    NODE_RETURN,
    NODE_BLOCK,
    NODE_BIN_OP,
    NODE_UNARY_OP,
    NODE_NUM_INT,
    NODE_NUM_REAL,
    NODE_STRING,
    NODE_BOOL,
    NODE_ID
} NodeType;

typedef struct ASTNode {
    NodeType type;
    DataType data_type;     // Tipo semântico associado ao nó
    char *name;             // Identificadores, tipos C ou literais texto
    int int_val;            // Literais inteiros ou booleanos
    double real_val;        // Literais reais
    char op[4];             // '+', '-', '*', '/', "<=", ">=", "==", "!=", "&&", "||", "!"
    struct ASTNode *left;   // Filho esquerdo / condição / alvo / argumentos
    struct ASTNode *right;  // Filho direito / corpo principal
    struct ASTNode *extra;  // Bloco else (IF), passo (FOR), parâmetros (FUNC_DECL)
    struct ASTNode *init;   // Inicialização (FOR)
    struct ASTNode *next;   // Lista encadeada para declarações, instruções, parâmetros e argumentos
} ASTNode;

ASTNode *create_node(NodeType type);
ASTNode *create_num_int(int val);
ASTNode *create_num_real(double val);
ASTNode *create_bool(int val);
ASTNode *create_str(const char *val);
ASTNode *create_id(const char *name, DataType type);
ASTNode *create_bin_op(const char *op, DataType type, ASTNode *left, ASTNode *right);
ASTNode *create_unary_op(const char *op, DataType type, ASTNode *operand);
void generate_code(ASTNode *root, FILE *out);
void print_ast(ASTNode *root, FILE *out);
void free_ast(ASTNode *node);

#endif
