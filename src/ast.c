#include "ast.h"
#include <string.h>

static void oom_abort(void) {
    fputs("Erro interno: memoria insuficiente.\n", stderr);
    exit(EXIT_FAILURE);
}

static char *dup_or_abort(const char *val) {
    char *copy = gluglu_strdup(val);
    if (!copy) oom_abort();
    return copy;
}

ASTNode *create_node(NodeType type) {
    ASTNode *node = (ASTNode *)calloc(1, sizeof(ASTNode));
    if (!node) oom_abort();
    node->type = type;
    node->data_type = TYPE_UNKNOWN;
    return node;
}

ASTNode *create_num_int(int val) {
    ASTNode *n = create_node(NODE_NUM_INT);
    n->int_val = val;
    n->data_type = TYPE_INTEIRO;
    return n;
}

ASTNode *create_num_real(double val) {
    ASTNode *n = create_node(NODE_NUM_REAL);
    n->real_val = val;
    n->data_type = TYPE_REAL;
    return n;
}

ASTNode *create_bool(int val) {
    ASTNode *n = create_node(NODE_BOOL);
    n->int_val = val;
    n->data_type = TYPE_BOOLEANO;
    return n;
}

ASTNode *create_str(const char *val) {
    ASTNode *n = create_node(NODE_STRING);
    n->name = dup_or_abort(val);
    n->data_type = TYPE_TEXTO;
    return n;
}

ASTNode *create_id(const char *name, DataType type) {
    ASTNode *n = create_node(NODE_ID);
    n->name = dup_or_abort(name);
    n->data_type = type;
    return n;
}

ASTNode *create_bin_op(const char *op, DataType type, ASTNode *left, ASTNode *right) {
    ASTNode *n = create_node(NODE_BIN_OP);
    strncpy(n->op, op, sizeof(n->op) - 1);
    n->op[sizeof(n->op) - 1] = '\0';
    n->data_type = type;
    n->left = left;
    n->right = right;
    return n;
}

ASTNode *create_unary_op(const char *op, DataType type, ASTNode *operand) {
    ASTNode *n = create_node(NODE_UNARY_OP);
    strncpy(n->op, op, sizeof(n->op) - 1);
    n->op[sizeof(n->op) - 1] = '\0';
    n->data_type = type;
    n->left = operand;
    return n;
}

void format_real_literal(double val, char *buf, size_t buf_size) {
    int written = snprintf(buf, buf_size, "%.17g", val);
    if (written < 0 || (size_t)written >= buf_size) return;
    if (!strchr(buf, '.') && !strchr(buf, 'e') && !strchr(buf, 'E')) {
        if ((size_t)written + 2 < buf_size) {
            buf[written] = '.';
            buf[written + 1] = '0';
            buf[written + 2] = '\0';
        }
    }
}

static void print_indent(FILE *out, int indent) {
    for (int i = 0; i < indent; i++) {
        fprintf(out, "    ");
    }
}

static void print_ast_node(ASTNode *node, FILE *out, int indent) {
    while (node) {
        print_indent(out, indent);
        switch (node->type) {
            case NODE_VAR_DECL:
                fprintf(out, "[VAR_DECL] %s : %s\n", node->left ? node->left->name : "?", node->name ? node->name : "?");
                print_ast_node(node->right, out, indent + 1);
                break;
            case NODE_ASSIGN:
                fprintf(out, "[ASSIGN] %s <-\n", node->left ? node->left->name : "?");
                print_ast_node(node->right, out, indent + 1);
                break;
            case NODE_PRINT:
                fprintf(out, "[GORGOREJA]\n");
                print_ast_node(node->left, out, indent + 1);
                break;
            case NODE_READ:
                fprintf(out, "[CISCA] %s (%s)\n", node->left ? node->left->name : "?",
                        datatype_to_str(node->left ? node->left->data_type : TYPE_UNKNOWN));
                break;
            case NODE_IF:
                fprintf(out, "[IFGLU]\n");
                print_indent(out, indent + 1);
                fprintf(out, "(condicao):\n");
                print_ast_node(node->left, out, indent + 2);
                print_indent(out, indent + 1);
                fprintf(out, "(entao):\n");
                print_ast_node(node->right, out, indent + 2);
                if (node->extra) {
                    print_indent(out, indent + 1);
                    fprintf(out, "(senao):\n");
                    print_ast_node(node->extra, out, indent + 2);
                }
                break;
            case NODE_WHILE:
                fprintf(out, "[WHILEGLU]\n");
                print_indent(out, indent + 1);
                fprintf(out, "(condicao):\n");
                print_ast_node(node->left, out, indent + 2);
                print_indent(out, indent + 1);
                fprintf(out, "(corpo):\n");
                print_ast_node(node->right, out, indent + 2);
                break;
            case NODE_FOR:
                fprintf(out, "[FORGLU]\n");
                print_indent(out, indent + 1);
                fprintf(out, "(init):\n");
                print_ast_node(node->init, out, indent + 2);
                print_indent(out, indent + 1);
                fprintf(out, "(condicao):\n");
                print_ast_node(node->left, out, indent + 2);
                print_indent(out, indent + 1);
                fprintf(out, "(passo):\n");
                print_ast_node(node->extra, out, indent + 2);
                print_indent(out, indent + 1);
                fprintf(out, "(corpo):\n");
                print_ast_node(node->right, out, indent + 2);
                break;
            case NODE_BREAK:
                fprintf(out, "[STOPGLU]\n");
                break;
            case NODE_CONTINUE:
                fprintf(out, "[PULAGLU]\n");
                break;
            case NODE_FUNC_DECL:
                fprintf(out, "[%s] %s -> %s\n",
                        node->data_type == TYPE_VOID ? "NINHO" : "CHOCA",
                        node->name ? node->name : "?",
                        datatype_to_str(node->data_type));
                if (node->extra) {
                    print_indent(out, indent + 1);
                    fprintf(out, "(parametros):\n");
                    print_ast_node(node->extra, out, indent + 2);
                }
                print_indent(out, indent + 1);
                fprintf(out, "(corpo):\n");
                print_ast_node(node->right, out, indent + 2);
                break;
            case NODE_PARAM:
                fprintf(out, "[PARAM] %s : %s\n", node->name ? node->name : "?", datatype_to_str(node->data_type));
                break;
            case NODE_FUNC_CALL:
                fprintf(out, "[CALL] %s (%s)\n", node->name ? node->name : "?", datatype_to_str(node->data_type));
                if (node->left) {
                    print_ast_node(node->left, out, indent + 1);
                }
                break;
            case NODE_RETURN:
                fprintf(out, "[RETORNAGLU] (%s)\n", datatype_to_str(node->data_type));
                print_ast_node(node->left, out, indent + 1);
                break;
            case NODE_BLOCK:
                fprintf(out, "[BLOCK]\n");
                print_ast_node(node->left, out, indent + 1);
                break;
            case NODE_BIN_OP:
                fprintf(out, "[BIN_OP '%s'] (%s)\n", node->op, datatype_to_str(node->data_type));
                print_ast_node(node->left, out, indent + 1);
                print_ast_node(node->right, out, indent + 1);
                break;
            case NODE_UNARY_OP:
                fprintf(out, "[UNARY_OP '%s'] (%s)\n", node->op, datatype_to_str(node->data_type));
                print_ast_node(node->left, out, indent + 1);
                break;
            case NODE_NUM_INT:
                fprintf(out, "[LIT_INT] %d (int)\n", node->int_val);
                break;
            case NODE_NUM_REAL: {
                char buf[64];
                format_real_literal(node->real_val, buf, sizeof(buf));
                fprintf(out, "[LIT_REAL] %s (double)\n", buf);
                break;
            }
            case NODE_BOOL:
                fprintf(out, "[LIT_BOOL] %s (bool)\n", node->int_val ? "true" : "false");
                break;
            case NODE_STRING:
                fprintf(out, "[LIT_TEXTO] <%s> (char*)\n", node->name ? node->name : "");
                break;
            case NODE_ID:
                fprintf(out, "[ID] %s (%s)\n", node->name ? node->name : "?", datatype_to_str(node->data_type));
                break;
            default:
                fprintf(out, "[NODE %d]\n", node->type);
                break;
        }
        node = node->next;
    }
}

void print_ast(ASTNode *root, FILE *out) {
    fprintf(out, "=== AST (Arvore Sintatica Abstrata) ===\n");
    print_ast_node(root, out, 0);
}

void free_ast(ASTNode *node) {
    while (node) {
        ASTNode *next = node->next;
        free_ast(node->left);
        free_ast(node->right);
        free_ast(node->extra);
        free_ast(node->init);
        free(node->name);
        free(node);
        node = next;
    }
}
