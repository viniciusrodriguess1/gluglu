#include "ast.h"
#include <string.h>

ASTNode *create_node(NodeType type) {
    ASTNode *node = (ASTNode *)calloc(1, sizeof(ASTNode));
    node->type = type;
    return node;
}

ASTNode *create_num_int(int val) {
    ASTNode *n = create_node(NODE_NUM_INT);
    n->int_val = val;
    return n;
}

ASTNode *create_num_real(double val) {
    ASTNode *n = create_node(NODE_NUM_REAL);
    n->real_val = val;
    return n;
}

ASTNode *create_str(const char *val) {
    ASTNode *n = create_node(NODE_STRING);
    n->name = strdup(val);
    return n;
}

ASTNode *create_id(const char *name) {
    ASTNode *n = create_node(NODE_ID);
    n->name = strdup(name);
    return n;
}

ASTNode *create_bin_op(char op, ASTNode *left, ASTNode *right) {
    ASTNode *n = create_node(NODE_BIN_OP);
    n->op = op;
    n->left = left;
    n->right = right;
    return n;
}

static void emit_expr(ASTNode *node, FILE *out) {
    if (!node) return;
    switch (node->type) {
        case NODE_NUM_INT:  fprintf(out, "%d", node->int_val); break;
        case NODE_NUM_REAL: fprintf(out, "%f", node->real_val); break;
        case NODE_STRING:   fprintf(out, "\"%s\"", node->name); break;
        case NODE_ID:       fprintf(out, "%s", node->name); break;
        case NODE_BIN_OP:
            fprintf(out, "(");
            emit_expr(node->left, out);
            fprintf(out, " %c ", node->op);
            emit_expr(node->right, out);
            fprintf(out, ")");
            break;
        default: break;
    }
}

void generate_code(ASTNode *root, FILE *out) {
    if (!root) return;

    fprintf(out, "#include <stdio.h>\n#include <stdbool.h>\n\nint main() {\n");
    
    ASTNode *curr = root;
    while (curr) {
        switch (curr->type) {
            case NODE_VAR_DECL:
                fprintf(out, "    %s %s = ", curr->name, curr->left->name);
                emit_expr(curr->right, out);
                fprintf(out, ";\n");
                break;
            case NODE_PRINT:
                if (curr->left->type == NODE_STRING) {
                    fprintf(out, "    printf(\"%%s\\n\", \"%s\");\n", curr->left->name);
                } else if (curr->left->type == NODE_NUM_INT) {
                    fprintf(out, "    printf(\"%%d\\n\", %d);\n", curr->left->int_val);
                } else {
                    fprintf(out, "    printf(\"%%f\\n\", (double)(");
                    emit_expr(curr->left, out);
                    fprintf(out, "));\n");
                }
                break;
            default: break;
        }
        curr = curr->next;
    }

    fprintf(out, "    return 0;\n}\n");
}