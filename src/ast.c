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

static void emit_expr(ASTNode *node, FILE *out) {
    if (!node) return;
    switch (node->type) {
        case NODE_NUM_INT:  fprintf(out, "%d", node->int_val); break;
        case NODE_NUM_REAL: fprintf(out, "%f", node->real_val); break;
        case NODE_BOOL:     fprintf(out, "%s", node->int_val ? "true" : "false"); break;
        case NODE_STRING:   fprintf(out, "\"%s\"", node->name); break;
        case NODE_ID:       fprintf(out, "%s", node->name); break;
        case NODE_BIN_OP:
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
            fprintf(out, "%s(", node->name);
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
        fprintf(out, "%s %s = ", node->name, node->left->name);
        emit_expr(node->right, out);
    } else if (node->type == NODE_ASSIGN) {
        fprintf(out, "%s = ", node->left->name);
        emit_expr(node->right, out);
    }
}

static void emit_stmt_list(ASTNode *curr, FILE *out, int indent) {
    while (curr) {
        switch (curr->type) {
            case NODE_VAR_DECL:
                emit_indent(out, indent);
                fprintf(out, "%s %s = ", curr->name, curr->left->name);
                emit_expr(curr->right, out);
                fprintf(out, ";\n");
                break;

            case NODE_ASSIGN:
                emit_indent(out, indent);
                fprintf(out, "%s = ", curr->left->name);
                emit_expr(curr->right, out);
                fprintf(out, ";\n");
                break;

            case NODE_PRINT:
                emit_indent(out, indent);
                if (curr->left->type == NODE_STRING) {
                    fprintf(out, "printf(\"%%s\\n\", \"%s\");\n", curr->left->name);
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
                    fprintf(out, "scanf(\"%%lf\", &%s);\n", curr->left->name);
                } else if (curr->left->data_type == TYPE_TEXTO) {
                    fprintf(out, "scanf(\"%%s\", %s);\n", curr->left->name);
                } else {
                    fprintf(out, "scanf(\"%%d\", &%s);\n", curr->left->name);
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

    fprintf(out, "#include <stdio.h>\n#include <stdbool.h>\n\n");

    // 1. Emite definições de funções e procedimentos (CHOCA / NINHO) no escopo global
    ASTNode *curr = root;
    while (curr) {
        if (curr->type == NODE_FUNC_DECL) {
            fprintf(out, "%s %s(", datatype_to_str(curr->data_type), curr->name);
            ASTNode *param = curr->extra;
            while (param) {
                fprintf(out, "%s %s", datatype_to_str(param->data_type), param->name);
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
