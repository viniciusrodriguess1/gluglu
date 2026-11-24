#include "codegen.h"
#include <stdbool.h>
#include <string.h>

static void emit_indent(FILE *out, int indent) {
    for (int i = 0; i < indent; i++) {
        fprintf(out, "    ");
    }
}

static void emit_identifier(FILE *out, const char *name) {
    fprintf(out, "gluglu_user_%s", name);
}

static void emit_real_literal(FILE *out, double val) {
    char buf[64];
    format_real_literal(val, buf, sizeof(buf));
    fputs(buf, out);
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

static bool expr_references_id(ASTNode *node, const char *name) {
    while (node) {
        if (node->type == NODE_ID && node->name && strcmp(node->name, name) == 0) {
            return true;
        }
        if (expr_references_id(node->left, name) ||
            expr_references_id(node->right, name) ||
            expr_references_id(node->extra, name) ||
            expr_references_id(node->init, name)) {
            return true;
        }
        node = node->next;
    }
    return false;
}

static void emit_expr(ASTNode *node, FILE *out) {
    if (!node) return;
    switch (node->type) {
        case NODE_NUM_INT:  fprintf(out, "%d", node->int_val); break;
        case NODE_NUM_REAL: emit_real_literal(out, node->real_val); break;
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

static void emit_stmt_list(ASTNode *curr, FILE *out, int indent,
                           ASTNode *hoist_until, int *temp_counter) {
    bool hoisting = (hoist_until != NULL);
    while (curr) {
        if (hoisting && curr == hoist_until) {
            hoisting = false;
        }

        switch (curr->type) {
            case NODE_VAR_DECL:
                if (hoisting) {
                    emit_indent(out, indent);
                    emit_identifier(out, curr->left->name);
                    fprintf(out, " = ");
                    emit_expr(curr->right, out);
                    fprintf(out, ";\n");
                } else if (expr_references_id(curr->right, curr->left->name)) {
                    int tmp = (*temp_counter)++;
                    emit_indent(out, indent);
                    fprintf(out, "%s gluglu_init_%d = ", curr->name, tmp);
                    emit_expr(curr->right, out);
                    fprintf(out, ";\n");
                    emit_indent(out, indent);
                    fprintf(out, "%s ", curr->name);
                    emit_identifier(out, curr->left->name);
                    fprintf(out, " = gluglu_init_%d;\n", tmp);
                } else {
                    emit_indent(out, indent);
                    fprintf(out, "%s ", curr->name);
                    emit_identifier(out, curr->left->name);
                    fprintf(out, " = ");
                    emit_expr(curr->right, out);
                    fprintf(out, ";\n");
                }
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
                emit_stmt_list(curr->right, out, indent + 1, NULL, temp_counter);
                emit_indent(out, indent);
                if (curr->extra) {
                    fprintf(out, "} else {\n");
                    emit_stmt_list(curr->extra, out, indent + 1, NULL, temp_counter);
                    emit_indent(out, indent);
                }
                fprintf(out, "}\n");
                break;

            case NODE_WHILE:
                emit_indent(out, indent);
                fprintf(out, "while (");
                emit_expr(curr->left, out);
                fprintf(out, ") {\n");
                emit_stmt_list(curr->right, out, indent + 1, NULL, temp_counter);
                emit_indent(out, indent);
                fprintf(out, "}\n");
                break;

            case NODE_FOR: {
                bool self_ref_init = (curr->init &&
                                      curr->init->type == NODE_VAR_DECL &&
                                      expr_references_id(curr->init->right, curr->init->left->name));
                int body_indent = indent;
                int tmp = -1;
                if (self_ref_init) {
                    tmp = (*temp_counter)++;
                    emit_indent(out, indent);
                    fprintf(out, "{\n");
                    body_indent = indent + 1;
                    emit_indent(out, body_indent);
                    fprintf(out, "%s gluglu_init_%d = ", curr->init->name, tmp);
                    emit_expr(curr->init->right, out);
                    fprintf(out, ";\n");
                }
                emit_indent(out, body_indent);
                fprintf(out, "for (");
                if (self_ref_init) {
                    fprintf(out, "%s ", curr->init->name);
                    emit_identifier(out, curr->init->left->name);
                    fprintf(out, " = gluglu_init_%d", tmp);
                } else {
                    emit_stmt_inline(curr->init, out);
                }
                fprintf(out, "; ");
                emit_expr(curr->left, out);
                fprintf(out, "; ");
                emit_stmt_inline(curr->extra, out);
                fprintf(out, ") {\n");
                emit_stmt_list(curr->right, out, body_indent + 1, NULL, temp_counter);
                emit_indent(out, body_indent);
                fprintf(out, "}\n");
                if (self_ref_init) {
                    emit_indent(out, indent);
                    fprintf(out, "}\n");
                }
                break;
            }

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
                emit_stmt_list(curr->left, out, indent + 1, NULL, temp_counter);
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

    int temp_counter = 0;

    fprintf(out,
            "#include <ctype.h>\n"
            "#include <errno.h>\n"
            "#include <limits.h>\n"
            "#include <stdbool.h>\n"
            "#include <stdint.h>\n"
            "#include <stdio.h>\n"
            "#include <stdlib.h>\n"
            "#include <string.h>\n\n"
            "typedef struct GlugluTextNode {\n"
            "    char *data;\n"
            "    struct GlugluTextNode *next;\n"
            "} GlugluTextNode;\n\n"
            "static GlugluTextNode *gluglu_text_allocs = NULL;\n"
            "static bool gluglu_cleanup_registered = false;\n\n"
            "static inline void gluglu_free_texts(void) {\n"
            "    GlugluTextNode *curr = gluglu_text_allocs;\n"
            "    while (curr) {\n"
            "        GlugluTextNode *next = curr->next;\n"
            "        free(curr->data);\n"
            "        free(curr);\n"
            "        curr = next;\n"
            "    }\n"
            "    gluglu_text_allocs = NULL;\n"
            "}\n\n"
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
            "    GlugluTextNode *node = (GlugluTextNode *)malloc(sizeof(GlugluTextNode));\n"
            "    if (!node) {\n"
            "        free(line);\n"
            "        gluglu_memory_error();\n"
            "    }\n"
            "    node->data = line;\n"
            "    node->next = gluglu_text_allocs;\n"
            "    gluglu_text_allocs = node;\n"
            "    if (!gluglu_cleanup_registered) {\n"
            "        atexit(gluglu_free_texts);\n"
            "        gluglu_cleanup_registered = true;\n"
            "    }\n"
            "    return line;\n"
            "}\n\n");

    // Identifica a última sub-rotina no nível raiz para promover variáveis globais anteriores
    ASTNode *last_func = NULL;
    for (ASTNode *curr = root; curr; curr = curr->next) {
        if (curr->type == NODE_FUNC_DECL) {
            last_func = curr;
        }
    }

    // 1. Declara variáveis globais visíveis a sub-rotinas
    bool emitted_globals = false;
    if (last_func) {
        for (ASTNode *curr = root; curr && curr != last_func; curr = curr->next) {
            if (curr->type == NODE_VAR_DECL) {
                fprintf(out, "static %s ", curr->name);
                emit_identifier(out, curr->left->name);
                fprintf(out, ";\n");
                emitted_globals = true;
            }
        }
        if (emitted_globals) {
            fprintf(out, "\n");
        }
    }

    // 2. Emite definições de funções e procedimentos (CHOCA / NINHO) no escopo global
    ASTNode *curr = root;
    while (curr) {
        if (curr->type == NODE_FUNC_DECL) {
            fprintf(out, "%s ", datatype_to_str(curr->data_type));
            emit_identifier(out, curr->name);
            fprintf(out, "(");
            ASTNode *param = curr->extra;
            if (!param) {
                fprintf(out, "void");
            }
            while (param) {
                fprintf(out, "%s ", datatype_to_str(param->data_type));
                emit_identifier(out, param->name);
                if (param->next) fprintf(out, ", ");
                param = param->next;
            }
            fprintf(out, ") {\n");
            emit_stmt_list(curr->right, out, 1, NULL, &temp_counter);
            fprintf(out, "}\n\n");
        }
        curr = curr->next;
    }

    // 3. Emite a função principal main() com os demais comandos
    fprintf(out, "int main(void) {\n");
    emit_stmt_list(root, out, 1, last_func, &temp_counter);
    fprintf(out, "    return 0;\n}\n");
}
