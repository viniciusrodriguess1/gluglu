#include "semantic.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct FunctionContext {
    Symbol *symbol;
    SymbolKind kind;
    int saved_loop_depth;
    struct FunctionContext *previous;
} FunctionContext;

static SymbolTable *symtab = NULL;
static FunctionContext *function_context = NULL;
static int loop_depth = 0;
static int semantic_errors = 0;

static void enter_function_context(Symbol *symbol, SymbolKind kind, int line) {
    FunctionContext *context = (FunctionContext *)malloc(sizeof(FunctionContext));
    if (!context) {
        fprintf(stderr, "Erro semantico na linha %d: memoria insuficiente ao analisar sub-rotina.\n", line);
        semantic_errors++;
        return;
    }

    context->symbol = symbol;
    context->kind = kind;
    context->saved_loop_depth = loop_depth;
    context->previous = function_context;
    function_context = context;
    loop_depth = 0;
}

static void leave_function_context(void) {
    if (!function_context) return;
    FunctionContext *previous = function_context->previous;
    loop_depth = function_context->saved_loop_depth;
    free(function_context);
    function_context = previous;
}

bool semantic_init(void) {
    semantic_cleanup();
    symtab = symtab_create();
    loop_depth = 0;
    semantic_errors = 0;
    return symtab != NULL;
}

void semantic_cleanup(void) {
    while (function_context) {
        leave_function_context();
    }
    symtab_destroy(symtab);
    symtab = NULL;
    loop_depth = 0;
}

int semantic_error_count(void) {
    return semantic_errors;
}

void semantic_enter_scope(void) {
    symtab_enter_scope(symtab);
}

void semantic_exit_scope(void) {
    symtab_exit_scope(symtab);
}

void semantic_enter_loop(void) {
    loop_depth++;
}

void semantic_exit_loop(void) {
    if (loop_depth > 0) loop_depth--;
}

void semantic_check_loop_control(const char *keyword, int line) {
    if (loop_depth == 0) {
        fprintf(stderr, "Erro semantico na linha %d: %s so pode ser usado dentro de um laco.\n", line, keyword);
        semantic_errors++;
    }
}

void semantic_begin_procedure(const char *name, int line) {
    Symbol *symbol = NULL;
    if (symtab->current_level > 0) {
        fprintf(stderr, "Erro semantico na linha %d: procedimento '%s' deve ser declarado no escopo global.\n",
                line, name);
        semantic_errors++;
    } else if (!symtab_insert(symtab, name, TYPE_VOID, SYM_PROCEDURE)) {
        fprintf(stderr, "Erro semantico na linha %d: procedimento '%s' ja declarado neste escopo.\n",
                line, name);
        semantic_errors++;
    } else {
        symbol = symtab_lookup_current_scope(symtab, name);
    }
    enter_function_context(symbol, SYM_PROCEDURE, line);
    symtab_enter_scope(symtab);
}

void semantic_begin_function(const char *name, int line) {
    Symbol *symbol = NULL;
    if (symtab->current_level > 0) {
        fprintf(stderr, "Erro semantico na linha %d: funcao '%s' deve ser declarada no escopo global.\n",
                line, name);
        semantic_errors++;
    } else if (!symtab_insert(symtab, name, TYPE_UNKNOWN, SYM_FUNCTION)) {
        fprintf(stderr, "Erro semantico na linha %d: funcao '%s' ja declarada neste escopo.\n",
                line, name);
        semantic_errors++;
    } else {
        symbol = symtab_lookup_current_scope(symtab, name);
    }
    enter_function_context(symbol, SYM_FUNCTION, line);
    symtab_enter_scope(symtab);
}

void semantic_register_params(ASTNode *params, int line) {
    if (!function_context || !function_context->symbol) return;

    size_t count = 0;
    for (ASTNode *param = params; param; param = param->next) count++;

    DataType *types = NULL;
    if (count > 0) {
        types = (DataType *)malloc(count * sizeof(DataType));
        if (!types) {
            fprintf(stderr, "Erro semantico na linha %d: memoria insuficiente ao registrar parametros.\n", line);
            semantic_errors++;
            return;
        }

        size_t index = 0;
        for (ASTNode *param = params; param; param = param->next) {
            types[index++] = param->data_type;
        }
    }

    if (!symtab_set_signature(function_context->symbol, types, count)) {
        fprintf(stderr, "Erro semantico na linha %d: nao foi possivel registrar a assinatura da sub-rotina.\n", line);
        semantic_errors++;
    }
    free(types);
}

void semantic_end_procedure(void) {
    symtab_exit_scope(symtab);
    leave_function_context();
}

static void collect_return_types(ASTNode *body, DataType *return_type, size_t *return_count, int line) {
    ASTNode *curr = body;
    while (curr) {
        if (curr->type == NODE_RETURN && curr->left) {
            DataType current = curr->left->data_type;
            (*return_count)++;
            if (current != TYPE_UNKNOWN) {
                if (*return_type == TYPE_UNKNOWN) {
                    *return_type = current;
                } else if (*return_type != current) {
                    bool both_numeric = (*return_type == TYPE_INTEIRO || *return_type == TYPE_REAL) &&
                                        (current == TYPE_INTEIRO || current == TYPE_REAL);
                    if (both_numeric) {
                        *return_type = TYPE_REAL;
                    } else {
                        fprintf(stderr, "Erro semantico na linha %d: tipos de retorno incompativeis em CHOCA.\n", line);
                        semantic_errors++;
                    }
                }
            }
        } else if (curr->type == NODE_IF) {
            collect_return_types(curr->right, return_type, return_count, line);
            collect_return_types(curr->extra, return_type, return_count, line);
        } else if (curr->type == NODE_WHILE || curr->type == NODE_FOR) {
            collect_return_types(curr->right, return_type, return_count, line);
        } else if (curr->type == NODE_BLOCK) {
            collect_return_types(curr->left, return_type, return_count, line);
        }
        curr = curr->next;
    }
}

static bool statement_list_returns(ASTNode *statements);

static bool statement_guarantees_return(ASTNode *statement) {
    if (!statement) return false;
    if (statement->type == NODE_RETURN) return statement->left != NULL;
    if (statement->type == NODE_BLOCK) return statement_list_returns(statement->left);
    if (statement->type == NODE_IF) {
        return statement->extra != NULL &&
               statement_list_returns(statement->right) &&
               statement_list_returns(statement->extra);
    }
    return false;
}

static bool statement_list_returns(ASTNode *statements) {
    for (ASTNode *statement = statements; statement; statement = statement->next) {
        if (statement_guarantees_return(statement)) return true;
    }
    return false;
}

static bool contains_return_statement(ASTNode *statements) {
    for (ASTNode *statement = statements; statement; statement = statement->next) {
        if (statement->type == NODE_RETURN) return true;
        if (statement->type == NODE_IF &&
            (contains_return_statement(statement->right) ||
             contains_return_statement(statement->extra))) return true;
        if ((statement->type == NODE_WHILE || statement->type == NODE_FOR) &&
            contains_return_statement(statement->right)) return true;
        if (statement->type == NODE_BLOCK &&
            contains_return_statement(statement->left)) return true;
    }
    return false;
}

static bool resolve_recursive_node(ASTNode *node, const char *name, DataType *return_type, int line);

static bool resolve_recursive_list(ASTNode *list, const char *name, DataType *return_type, int line) {
    bool changed = false;
    for (ASTNode *curr = list; curr; curr = curr->next) {
        if (resolve_recursive_node(curr, name, return_type, line)) {
            changed = true;
        }
    }
    return changed;
}

static bool resolve_recursive_node(ASTNode *curr, const char *name, DataType *return_type, int line) {
    if (!curr) return false;

    switch (curr->type) {
        case NODE_FUNC_CALL: {
            Symbol *sym = symtab_lookup(symtab, curr->name);
            size_t index = 0;
            for (ASTNode *arg = curr->left; arg; arg = arg->next, index++) {
                if (resolve_recursive_node(arg, name, return_type, line) &&
                    arg->data_type != TYPE_UNKNOWN &&
                    sym && sym->kind != SYM_VAR && index < sym->param_count) {
                    DataType expected = sym->param_types[index];
                    if (!is_type_compatible(expected, arg->data_type)) {
                        fprintf(stderr, "Erro semantico na linha %d: argumento %zu de '%s' tem tipo incompativel. Esperado '%s', recebido '%s'.\n",
                                line, index + 1, curr->name, datatype_to_str(expected), datatype_to_str(arg->data_type));
                        semantic_errors++;
                    }
                }
            }
            if (strcmp(curr->name, name) == 0 && curr->data_type != *return_type) {
                curr->data_type = *return_type;
                return true;
            }
            return false;
        }

        case NODE_BIN_OP: {
            DataType prev_type = curr->data_type;
            bool left_changed = resolve_recursive_node(curr->left, name, return_type, line);
            bool right_changed = resolve_recursive_node(curr->right, name, return_type, line);

            if ((left_changed || right_changed) && curr->left && curr->right) {
                DataType lt = curr->left->data_type;
                DataType rt = curr->right->data_type;
                if (strcmp(curr->op, "+") == 0 || strcmp(curr->op, "-") == 0 ||
                    strcmp(curr->op, "*") == 0 || strcmp(curr->op, "/") == 0) {
                    curr->data_type = semantic_infer_arith(curr->op, lt, rt, line);
                } else if (strcmp(curr->op, "<") == 0 || strcmp(curr->op, ">") == 0 ||
                           strcmp(curr->op, "<=") == 0 || strcmp(curr->op, ">=") == 0 ||
                           strcmp(curr->op, "==") == 0 || strcmp(curr->op, "!=") == 0) {
                    curr->data_type = semantic_check_rel(curr->op, lt, rt, line);
                } else if (strcmp(curr->op, "&&") == 0 || strcmp(curr->op, "||") == 0) {
                    const char *logic_op = strcmp(curr->op, "&&") == 0 ? "and" : "or";
                    curr->data_type = semantic_check_logic(logic_op, lt, rt, line);
                }
            }
            return curr->data_type != prev_type;
        }

        case NODE_UNARY_OP: {
            DataType prev_type = curr->data_type;
            if (resolve_recursive_node(curr->left, name, return_type, line) && curr->left) {
                if (strcmp(curr->op, "-") == 0) {
                    curr->data_type = semantic_infer_unary_minus(curr->left->data_type, line);
                } else if (strcmp(curr->op, "!") == 0) {
                    curr->data_type = semantic_check_logic("not", curr->left->data_type, TYPE_BOOLEANO, line);
                }
            }
            return curr->data_type != prev_type;
        }

        case NODE_VAR_DECL: {
            if (resolve_recursive_node(curr->right, name, return_type, line) &&
                curr->right && curr->right->data_type != TYPE_UNKNOWN &&
                !is_type_compatible(curr->data_type, curr->right->data_type)) {
                fprintf(stderr, "Erro semantico na linha %d: tipo incompativel ao inicializar '%s'. Esperado '%s', recebido '%s'.\n",
                        line, curr->left ? curr->left->name : "?",
                        datatype_to_str(curr->data_type), datatype_to_str(curr->right->data_type));
                semantic_errors++;
            }
            return false;
        }

        case NODE_ASSIGN: {
            if (resolve_recursive_node(curr->right, name, return_type, line) &&
                curr->right && curr->right->data_type != TYPE_UNKNOWN &&
                curr->data_type != TYPE_UNKNOWN &&
                !is_type_compatible(curr->data_type, curr->right->data_type)) {
                fprintf(stderr, "Erro semantico na linha %d: tipo incompativel na atribuicao para '%s'. Esperado '%s', recebido '%s'.\n",
                        line, curr->left ? curr->left->name : "?",
                        datatype_to_str(curr->data_type), datatype_to_str(curr->right->data_type));
                semantic_errors++;
            }
            return false;
        }

        case NODE_PRINT:
            resolve_recursive_node(curr->left, name, return_type, line);
            return false;

        case NODE_IF: {
            if (resolve_recursive_node(curr->left, name, return_type, line) && curr->left) {
                semantic_check_condition("IFGLU", curr->left->data_type, line);
            }
            resolve_recursive_list(curr->right, name, return_type, line);
            resolve_recursive_list(curr->extra, name, return_type, line);
            return false;
        }

        case NODE_WHILE: {
            if (resolve_recursive_node(curr->left, name, return_type, line) && curr->left) {
                semantic_check_condition("WHILEGLU", curr->left->data_type, line);
            }
            resolve_recursive_list(curr->right, name, return_type, line);
            return false;
        }

        case NODE_FOR: {
            resolve_recursive_node(curr->init, name, return_type, line);
            if (resolve_recursive_node(curr->left, name, return_type, line) && curr->left) {
                semantic_check_condition("FORGLU", curr->left->data_type, line);
            }
            resolve_recursive_node(curr->extra, name, return_type, line);
            resolve_recursive_list(curr->right, name, return_type, line);
            return false;
        }

        case NODE_BLOCK:
            resolve_recursive_list(curr->left, name, return_type, line);
            return false;

        case NODE_RETURN: {
            if (resolve_recursive_node(curr->left, name, return_type, line) && curr->left) {
                curr->data_type = curr->left->data_type;
                if (curr->left->data_type != TYPE_UNKNOWN &&
                    curr->left->data_type != *return_type) {
                    bool both_numeric = (*return_type == TYPE_INTEIRO || *return_type == TYPE_REAL) &&
                                        (curr->left->data_type == TYPE_INTEIRO || curr->left->data_type == TYPE_REAL);
                    if (both_numeric) {
                        *return_type = TYPE_REAL;
                    } else {
                        fprintf(stderr, "Erro semantico na linha %d: tipos de retorno incompativeis em CHOCA.\n", line);
                        semantic_errors++;
                    }
                }
            }
            return false;
        }

        default:
            return false;
    }
}

DataType semantic_end_function(ASTNode *body, const char *name, int line) {
    symtab_exit_scope(symtab);

    DataType return_type = TYPE_UNKNOWN;
    size_t return_count = 0;
    collect_return_types(body, &return_type, &return_count, line);

    if (return_count == 0) {
        if (!contains_return_statement(body)) {
            fprintf(stderr, "Erro semantico na linha %d: CHOCA '%s' nao possui RETORNAGLU com valor.\n", line, name);
            semantic_errors++;
        }
    } else if (!statement_list_returns(body)) {
        fprintf(stderr, "Erro semantico na linha %d: nem todos os caminhos de CHOCA '%s' retornam um valor.\n", line, name);
        semantic_errors++;
    } else if (return_type == TYPE_UNKNOWN && semantic_errors == 0) {
        fprintf(stderr, "Erro semantico na linha %d: nao foi possivel inferir o tipo de retorno de CHOCA '%s'.\n", line, name);
        semantic_errors++;
    }

    if (return_type == TYPE_UNKNOWN) return_type = TYPE_INTEIRO;
    DataType previous_type = return_type;
    resolve_recursive_list(body, name, &return_type, line);
    if (return_type != previous_type && semantic_errors == 0) {
        resolve_recursive_list(body, name, &return_type, line);
    }

    if (function_context && function_context->symbol) {
        function_context->symbol->type = return_type;
    }
    leave_function_context();
    return return_type;
}

void semantic_declare_var(const char *name, DataType type, DataType expr_type, int line) {
    if (expr_type != TYPE_UNKNOWN && !is_type_compatible(type, expr_type)) {
        fprintf(stderr, "Erro semantico na linha %d: tipo incompativel ao inicializar '%s'. Esperado '%s', recebido '%s'.\n",
                line, name, datatype_to_str(type), datatype_to_str(expr_type));
        semantic_errors++;
    }

    if (!symtab_insert(symtab, name, type, SYM_VAR)) {
        fprintf(stderr, "Erro semantico na linha %d: identificador '%s' ja declarado neste escopo.\n",
                line, name);
        semantic_errors++;
    }
}

void semantic_declare_param(const char *name, DataType type, int line) {
    if (!symtab_insert(symtab, name, type, SYM_VAR)) {
        fprintf(stderr, "Erro semantico na linha %d: parametro '%s' duplicado.\n", line, name);
        semantic_errors++;
    }
}

DataType semantic_check_assignment(const char *name, DataType expr_type, int line) {
    Symbol *sym = symtab_lookup(symtab, name);
    if (!sym) {
        fprintf(stderr, "Erro semantico na linha %d: identificador '%s' nao declarado.\n", line, name);
        semantic_errors++;
        return TYPE_UNKNOWN;
    }
    if (sym->kind != SYM_VAR) {
        fprintf(stderr, "Erro semantico na linha %d: identificador '%s' nao e uma variavel.\n", line, name);
        semantic_errors++;
        return TYPE_UNKNOWN;
    }
    if (expr_type != TYPE_UNKNOWN && !is_type_compatible(sym->type, expr_type)) {
        fprintf(stderr, "Erro semantico na linha %d: tipo incompativel na atribuicao para '%s'. Esperado '%s', recebido '%s'.\n",
                line, name, datatype_to_str(sym->type), datatype_to_str(expr_type));
        semantic_errors++;
    }
    return sym->type;
}

DataType semantic_check_read(const char *name, int line) {
    Symbol *sym = symtab_lookup(symtab, name);
    if (!sym) {
        fprintf(stderr, "Erro semantico na linha %d: identificador '%s' nao declarado.\n", line, name);
        semantic_errors++;
        return TYPE_INTEIRO;
    }
    if (sym->kind != SYM_VAR) {
        fprintf(stderr, "Erro semantico na linha %d: identificador '%s' nao e uma variavel.\n", line, name);
        semantic_errors++;
        return TYPE_INTEIRO;
    }
    return sym->type;
}

DataType semantic_check_var_use(const char *name, int line) {
    Symbol *sym = symtab_lookup(symtab, name);
    if (!sym) {
        fprintf(stderr, "Erro semantico na linha %d: identificador '%s' nao declarado.\n", line, name);
        semantic_errors++;
        return TYPE_UNKNOWN;
    }
    if (sym->kind != SYM_VAR) {
        fprintf(stderr, "Erro semantico na linha %d: identificador '%s' nao e uma variavel.\n", line, name);
        semantic_errors++;
        return TYPE_UNKNOWN;
    }
    return sym->type;
}

static void check_call_arguments(Symbol *sym, const char *name, ASTNode *args, int line) {
    size_t arg_count = 0;
    for (ASTNode *arg = args; arg; arg = arg->next) arg_count++;

    if (arg_count != sym->param_count) {
        fprintf(stderr, "Erro semantico na linha %d: chamada de '%s' recebeu %zu argumento(s); esperado(s) %zu.\n",
                line, name, arg_count, sym->param_count);
        semantic_errors++;
    }

    ASTNode *arg = args;
    size_t index = 0;
    while (arg && index < sym->param_count) {
        DataType expected = sym->param_types[index];
        if (arg->data_type != TYPE_UNKNOWN && !is_type_compatible(expected, arg->data_type)) {
            fprintf(stderr, "Erro semantico na linha %d: argumento %zu de '%s' tem tipo incompativel. Esperado '%s', recebido '%s'.\n",
                    line, index + 1, name, datatype_to_str(expected), datatype_to_str(arg->data_type));
            semantic_errors++;
        }
        arg = arg->next;
        index++;
    }
}

DataType semantic_check_call(const char *name, ASTNode *args, int line) {
    Symbol *sym = symtab_lookup(symtab, name);
    if (!sym) {
        fprintf(stderr, "Erro semantico na linha %d: funcao ou procedimento '%s' nao declarado.\n", line, name);
        semantic_errors++;
        return TYPE_UNKNOWN;
    }
    if (sym->kind == SYM_VAR) {
        fprintf(stderr, "Erro semantico na linha %d: identificador '%s' declarado como variavel e nao pode ser chamado.\n",
                line, name);
        semantic_errors++;
        return TYPE_UNKNOWN;
    }
    check_call_arguments(sym, name, args, line);
    return sym->type;
}

void semantic_check_call_as_expr(DataType ret_type, int line) {
    if (ret_type == TYPE_VOID) {
        fprintf(stderr, "Erro semantico na linha %d: procedimento nao pode ser usado como expressao.\n", line);
        semantic_errors++;
    }
}

void semantic_check_return(bool has_value, int line) {
    if (!function_context) {
        fprintf(stderr, "Erro semantico na linha %d: RETORNAGLU so pode ser usado dentro de CHOCA ou NINHO.\n", line);
        semantic_errors++;
    } else if (function_context->kind == SYM_PROCEDURE && has_value) {
        fprintf(stderr, "Erro semantico na linha %d: NINHO nao pode retornar um valor.\n", line);
        semantic_errors++;
    } else if (function_context->kind == SYM_FUNCTION && !has_value) {
        fprintf(stderr, "Erro semantico na linha %d: CHOCA deve retornar um valor.\n", line);
        semantic_errors++;
    }
}

void semantic_check_condition(const char *cmd, DataType cond_type, int line) {
    if (cond_type != TYPE_UNKNOWN && cond_type != TYPE_BOOLEANO) {
        fprintf(stderr, "Erro semantico na linha %d: a condicao de '%s' deve ser do tipo 'booleano' (recebido '%s').\n",
                line, cmd, datatype_to_str(cond_type));
        semantic_errors++;
    }
}

DataType semantic_infer_arith(const char *op, DataType left, DataType right, int line) {
    if (left == TYPE_UNKNOWN || right == TYPE_UNKNOWN) return TYPE_UNKNOWN;
    if ((left == TYPE_INTEIRO || left == TYPE_REAL) &&
        (right == TYPE_INTEIRO || right == TYPE_REAL)) {
        if (left == TYPE_REAL || right == TYPE_REAL) return TYPE_REAL;
        return TYPE_INTEIRO;
    }
    fprintf(stderr, "Erro semantico na linha %d: operandos incompativeis para o operador aritmetico '%s' ('%s' e '%s').\n",
            line, op, datatype_to_str(left), datatype_to_str(right));
    semantic_errors++;
    return TYPE_UNKNOWN;
}

DataType semantic_infer_unary_minus(DataType operand, int line) {
    if (operand == TYPE_UNKNOWN) return TYPE_UNKNOWN;
    if (operand == TYPE_INTEIRO || operand == TYPE_REAL) return operand;
    fprintf(stderr, "Erro semantico na linha %d: operador unario '-' requer operando numerico (recebido '%s').\n",
            line, datatype_to_str(operand));
    semantic_errors++;
    return TYPE_UNKNOWN;
}

DataType semantic_check_rel(const char *op, DataType left, DataType right, int line) {
    if (left == TYPE_UNKNOWN || right == TYPE_UNKNOWN) return TYPE_BOOLEANO;
    bool both_num = (left == TYPE_INTEIRO || left == TYPE_REAL) &&
                    (right == TYPE_INTEIRO || right == TYPE_REAL);
    bool same_eq = (strcmp(op, "==") == 0 || strcmp(op, "!=") == 0) && (left == right);
    if (!both_num && !same_eq) {
        fprintf(stderr, "Erro semantico na linha %d: operandos incompativeis para o operador relacional '%s' ('%s' e '%s').\n",
                line, op, datatype_to_str(left), datatype_to_str(right));
        semantic_errors++;
    }
    return TYPE_BOOLEANO;
}

DataType semantic_check_logic(const char *op, DataType left, DataType right, int line) {
    if (left != TYPE_UNKNOWN && left != TYPE_BOOLEANO) {
        fprintf(stderr, "Erro semantico na linha %d: operador logico '%s' requer operandos booleanos (recebido '%s').\n",
                line, op, datatype_to_str(left));
        semantic_errors++;
    } else if (right != TYPE_UNKNOWN && right != TYPE_BOOLEANO) {
        fprintf(stderr, "Erro semantico na linha %d: operador logico '%s' requer operandos booleanos (recebido '%s').\n",
                line, op, datatype_to_str(right));
        semantic_errors++;
    }
    return TYPE_BOOLEANO;
}
