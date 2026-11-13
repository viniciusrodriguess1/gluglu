#include "ast.h"
#include <string.h>

ASTNode *create_node(NodeType type) {
    ASTNode *node = (ASTNode *)calloc(1, sizeof(ASTNode));
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
    n->name = strdup(val);
    n->data_type = TYPE_TEXTO;
    return n;
}

ASTNode *create_id(const char *name, DataType type) {
    ASTNode *n = create_node(NODE_ID);
    n->name = strdup(name);
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

static void emit_indent(FILE *out, int indent) {
    for (int i = 0; i < indent; i++) {
        fprintf(out, "    ");
    }
}

static void emit_identifier(FILE *out, const char *name) {
    fprintf(out, "gluglu_user_%s", name);
}

static void emit_c_string(FILE *out, const char *value) {
    fputc('"', out);
    for (const unsigned char *ch = (const unsigned char *)value; *ch; ch++) {
        switch (*ch) {
            case '"':  fputs("\\\"", out); break;
            case '\\': fputs("\\\\", out); break;
            case '\n': fputs("\\n", out); break;
            case '\r': fputs("\\r", out); break;
            case '\t': fputs("\\t", out); break;
            default:   fputc(*ch, out); break;
        }
    }
    fputc('"', out);
}

static void emit_expr(ASTNode *node, FILE *out) {
    if (!node) return;
    switch (node->type) {
        case NODE_NUM_INT:  fprintf(out, "%d", node->int_val); break;
        case NODE_NUM_REAL: fprintf(out, "%f", node->real_val); break;
        case NODE_BOOL:     fprintf(out, "%s", node->int_val ? "true" : "false"); break;
        case NODE_STRING:   emit_c_string(out, node->name); break;
        case NODE_ID:       emit_identifier(out, node->name); break;
        case NODE_BIN_OP:
            if ((strcmp(node->op, "==") == 0 || strcmp(node->op, "!=") == 0) &&
                node->left->data_type == TYPE_TEXTO &&
                node->right->data_type == TYPE_TEXTO) {
                fprintf(out, "(strcmp(");
                emit_expr(node->left, out);
                fprintf(out, ", ");
                emit_expr(node->right, out);
                fprintf(out, ") %s 0)", strcmp(node->op, "==") == 0 ? "==" : "!=");
                break;
            }
            fprintf(out, "(");
            emit_expr(node->left, out);
            fprintf(out, " %s ", node->op);
            emit_expr(node->right, out);
            fprintf(out, ")");
            break;
        case NODE_UNARY_OP:
            fprintf(out, "(%s", node->op);
            emit_expr(node->left, out);
            fprintf(out, ")");
            break;
        case NODE_FUNC_CALL: {
            emit_identifier(out, node->name);
            fprintf(out, "(");
            ASTNode *arg = node->left;
            while (arg) {
                emit_expr(arg, out);
                if (arg->next) fprintf(out, ", ");
                arg = arg->next;
            }
            fprintf(out, ")");
            break;
        }
        default: break;
    }
}

static void emit_stmt_inline(ASTNode *node, FILE *out) {
    if (!node) return;
    if (node->type == NODE_VAR_DECL) {
        fprintf(out, "%s ", node->name);
        emit_identifier(out, node->left->name);
        fprintf(out, " = ");
        emit_expr(node->right, out);
    } else if (node->type == NODE_ASSIGN) {
        emit_identifier(out, node->left->name);
        fprintf(out, " = ");
        emit_expr(node->right, out);
    }
}

static void emit_stmt_list(ASTNode *curr, FILE *out, int indent) {
    while (curr) {
        switch (curr->type) {
            case NODE_VAR_DECL:
                emit_indent(out, indent);
                fprintf(out, "%s ", curr->name);
                emit_identifier(out, curr->left->name);
                fprintf(out, " = ");
                emit_expr(curr->right, out);
                fprintf(out, ";\n");
                break;

            case NODE_ASSIGN:
                emit_indent(out, indent);
                emit_identifier(out, curr->left->name);
                fprintf(out, " = ");
                emit_expr(curr->right, out);
                fprintf(out, ";\n");
                break;

            case NODE_PRINT:
                emit_indent(out, indent);
                if (curr->left->type == NODE_STRING) {
                    fprintf(out, "printf(\"%%s\\n\", ");
                    emit_c_string(out, curr->left->name);
                    fprintf(out, ");\n");
                } else if (curr->left->data_type == TYPE_TEXTO) {
                    fprintf(out, "printf(\"%%s\\n\", ");
                    emit_expr(curr->left, out);
                    fprintf(out, ");\n");
                } else if (curr->left->data_type == TYPE_INTEIRO) {
                    fprintf(out, "printf(\"%%d\\n\", ");
                    emit_expr(curr->left, out);
                    fprintf(out, ");\n");
                } else if (curr->left->data_type == TYPE_BOOLEANO) {
                    fprintf(out, "printf(\"%%s\\n\", (");
                    emit_expr(curr->left, out);
                    fprintf(out, ") ? \"true\" : \"false\");\n");
                } else {
                    fprintf(out, "printf(\"%%f\\n\", (double)(");
                    emit_expr(curr->left, out);
                    fprintf(out, "));\n");
                }
                break;

            case NODE_READ:
                emit_indent(out, indent);
                if (curr->left->data_type == TYPE_REAL) {
                    emit_identifier(out, curr->left->name);
                    fprintf(out, " = gluglu_read_real();\n");
                } else if (curr->left->data_type == TYPE_TEXTO) {
                    emit_identifier(out, curr->left->name);
                    fprintf(out, " = gluglu_read_text();\n");
                } else if (curr->left->data_type == TYPE_BOOLEANO) {
                    emit_identifier(out, curr->left->name);
                    fprintf(out, " = gluglu_read_bool();\n");
                } else {
                    emit_identifier(out, curr->left->name);
                    fprintf(out, " = gluglu_read_int();\n");
                }
                break;

            case NODE_IF:
                emit_indent(out, indent);
                fprintf(out, "if (");
                emit_expr(curr->left, out);
                fprintf(out, ") {\n");
                emit_stmt_list(curr->right, out, indent + 1);
                emit_indent(out, indent);
                if (curr->extra) {
                    fprintf(out, "} else {\n");
                    emit_stmt_list(curr->extra, out, indent + 1);
                    emit_indent(out, indent);
                }
                fprintf(out, "}\n");
                break;

            case NODE_WHILE:
                emit_indent(out, indent);
                fprintf(out, "while (");
                emit_expr(curr->left, out);
                fprintf(out, ") {\n");
                emit_stmt_list(curr->right, out, indent + 1);
                emit_indent(out, indent);
                fprintf(out, "}\n");
                break;

            case NODE_FOR:
                emit_indent(out, indent);
                fprintf(out, "for (");
                emit_stmt_inline(curr->init, out);
                fprintf(out, "; ");
                emit_expr(curr->left, out);
                fprintf(out, "; ");
                emit_stmt_inline(curr->extra, out);
                fprintf(out, ") {\n");
                emit_stmt_list(curr->right, out, indent + 1);
                emit_indent(out, indent);
                fprintf(out, "}\n");
                break;

            case NODE_BREAK:
                emit_indent(out, indent);
                fprintf(out, "break;\n");
                break;

            case NODE_CONTINUE:
                emit_indent(out, indent);
                fprintf(out, "continue;\n");
                break;

            case NODE_FUNC_CALL:
                emit_indent(out, indent);
                emit_expr(curr, out);
                fprintf(out, ";\n");
                break;

            case NODE_RETURN:
                emit_indent(out, indent);
                if (curr->left) {
                    fprintf(out, "return ");
                    emit_expr(curr->left, out);
                    fprintf(out, ";\n");
                } else {
                    fprintf(out, "return;\n");
                }
                break;

            case NODE_BLOCK:
                emit_indent(out, indent);
                fprintf(out, "{\n");
                emit_stmt_list(curr->left, out, indent + 1);
                emit_indent(out, indent);
                fprintf(out, "}\n");
                break;

            case NODE_FUNC_DECL:
                // Emitido no escopo global antes da main()
                break;

            default:
                break;
        }
        curr = curr->next;
    }
}

void generate_code(ASTNode *root, FILE *out) {
    if (!root) return;

    fprintf(out,
            "#include <ctype.h>\n"
            "#include <errno.h>\n"
            "#include <limits.h>\n"
            "#include <stdbool.h>\n"
            "#include <stdint.h>\n"
            "#include <stdio.h>\n"
            "#include <stdlib.h>\n"
            "#include <string.h>\n\n"
            "static inline void gluglu_input_error(const char *type) {\n"
            "    fprintf(stderr, \"Erro: entrada invalida para %%s.\\n\", type);\n"
            "    exit(EXIT_FAILURE);\n"
            "}\n\n"
            "static inline void gluglu_memory_error(void) {\n"
            "    fputs(\"Erro: memoria insuficiente ao ler entrada.\\n\", stderr);\n"
            "    exit(EXIT_FAILURE);\n"
            "}\n\n"
            "static inline char *gluglu_read_line(void) {\n"
            "    size_t capacity = 64;\n"
            "    size_t length = 0;\n"
            "    char *line = (char *)malloc(capacity);\n"
            "    if (!line) gluglu_memory_error();\n"
            "    int ch;\n"
            "    while ((ch = getchar()) != '\\n' && ch != EOF) {\n"
            "        if (length + 1 >= capacity) {\n"
            "            if (capacity > SIZE_MAX / 2) {\n"
            "                free(line);\n"
            "                gluglu_memory_error();\n"
            "            }\n"
            "            capacity *= 2;\n"
            "            char *grown = (char *)realloc(line, capacity);\n"
            "            if (!grown) {\n"
            "                free(line);\n"
            "                gluglu_memory_error();\n"
            "            }\n"
            "            line = grown;\n"
            "        }\n"
            "        line[length++] = (char)ch;\n"
            "    }\n"
            "    if (ch == EOF && length == 0) {\n"
            "        free(line);\n"
            "        return NULL;\n"
            "    }\n"
            "    if (length > 0 && line[length - 1] == '\\r') length--;\n"
            "    line[length] = '\\0';\n"
            "    return line;\n"
            "}\n\n"
            "static inline int gluglu_read_int(void) {\n"
            "    char *line = gluglu_read_line();\n"
            "    if (!line) gluglu_input_error(\"inteiro\");\n"
            "    char *end;\n"
            "    errno = 0;\n"
            "    long value = strtol(line, &end, 10);\n"
            "    while (isspace((unsigned char)*end)) end++;\n"
            "    if (errno == ERANGE || end == line || *end != '\\0' || value < INT_MIN || value > INT_MAX) {\n"
            "        free(line);\n"
            "        gluglu_input_error(\"inteiro\");\n"
            "    }\n"
            "    free(line);\n"
            "    return (int)value;\n"
            "}\n\n"
            "static inline double gluglu_read_real(void) {\n"
            "    char *line = gluglu_read_line();\n"
            "    if (!line) gluglu_input_error(\"real\");\n"
            "    char *end;\n"
            "    errno = 0;\n"
            "    double value = strtod(line, &end);\n"
            "    while (isspace((unsigned char)*end)) end++;\n"
            "    if (errno == ERANGE || end == line || *end != '\\0') {\n"
            "        free(line);\n"
            "        gluglu_input_error(\"real\");\n"
            "    }\n"
            "    free(line);\n"
            "    return value;\n"
            "}\n\n"
            "static inline bool gluglu_read_bool(void) {\n"
            "    char *line = gluglu_read_line();\n"
            "    if (!line) gluglu_input_error(\"booleano\");\n"
            "    char *start = line;\n"
            "    while (isspace((unsigned char)*start)) start++;\n"
            "    char *end = start + strlen(start);\n"
            "    while (end > start && isspace((unsigned char)end[-1])) *--end = '\\0';\n"
            "    bool value;\n"
            "    if (strcmp(start, \"true\") == 0 || strcmp(start, \"1\") == 0) value = true;\n"
            "    else if (strcmp(start, \"false\") == 0 || strcmp(start, \"0\") == 0) value = false;\n"
            "    else {\n"
            "        free(line);\n"
            "        gluglu_input_error(\"booleano\");\n"
            "    }\n"
            "    free(line);\n"
            "    return value;\n"
            "}\n\n"
            "static inline char *gluglu_read_text(void) {\n"
            "    char *line = gluglu_read_line();\n"
            "    if (!line) gluglu_input_error(\"texto\");\n"
            "    return line;\n"
            "}\n\n");

    // 1. Emite definições de funções e procedimentos (CHOCA / NINHO) no escopo global
    ASTNode *curr = root;
    while (curr) {
        if (curr->type == NODE_FUNC_DECL) {
            fprintf(out, "%s ", datatype_to_str(curr->data_type));
            emit_identifier(out, curr->name);
            fprintf(out, "(");
            ASTNode *param = curr->extra;
            while (param) {
                fprintf(out, "%s ", datatype_to_str(param->data_type));
                emit_identifier(out, param->name);
                if (param->next) fprintf(out, ", ");
                param = param->next;
            }
            fprintf(out, ") {\n");
            emit_stmt_list(curr->right, out, 1);
            fprintf(out, "}\n\n");
        }
        curr = curr->next;
    }

    // 2. Emite a função principal main() com os demais comandos
    fprintf(out, "int main() {\n");
    emit_stmt_list(root, out, 1);
    fprintf(out, "    return 0;\n}\n");
}

static void print_ast_node(ASTNode *node, FILE *out, int indent) {
    while (node) {
        emit_indent(out, indent);
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
                emit_indent(out, indent + 1);
                fprintf(out, "(condicao):\n");
                print_ast_node(node->left, out, indent + 2);
                emit_indent(out, indent + 1);
                fprintf(out, "(entao):\n");
                print_ast_node(node->right, out, indent + 2);
                if (node->extra) {
                    emit_indent(out, indent + 1);
                    fprintf(out, "(senao):\n");
                    print_ast_node(node->extra, out, indent + 2);
                }
                break;
            case NODE_WHILE:
                fprintf(out, "[WHILEGLU]\n");
                emit_indent(out, indent + 1);
                fprintf(out, "(condicao):\n");
                print_ast_node(node->left, out, indent + 2);
                emit_indent(out, indent + 1);
                fprintf(out, "(corpo):\n");
                print_ast_node(node->right, out, indent + 2);
                break;
            case NODE_FOR:
                fprintf(out, "[FORGLU]\n");
                emit_indent(out, indent + 1);
                fprintf(out, "(init):\n");
                print_ast_node(node->init, out, indent + 2);
                emit_indent(out, indent + 1);
                fprintf(out, "(condicao):\n");
                print_ast_node(node->left, out, indent + 2);
                emit_indent(out, indent + 1);
                fprintf(out, "(passo):\n");
                print_ast_node(node->extra, out, indent + 2);
                emit_indent(out, indent + 1);
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
                    emit_indent(out, indent + 1);
                    fprintf(out, "(parametros):\n");
                    print_ast_node(node->extra, out, indent + 2);
                }
                emit_indent(out, indent + 1);
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
            case NODE_NUM_REAL:
                fprintf(out, "[LIT_REAL] %f (double)\n", node->real_val);
                break;
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
