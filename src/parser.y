%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symtab.h"
#include "ast.h"

extern int yylineno;
int yylex(void);
void yyerror(const char *s);

SymbolTable *st = NULL;
ASTNode *root = NULL;
int lexical_errors = 0;
int semantic_errors = 0;

typedef struct FunctionContext {
    Symbol *symbol;
    SymbolKind kind;
    int saved_loop_depth;
    struct FunctionContext *previous;
} FunctionContext;

static FunctionContext *function_context = NULL;
static int loop_depth = 0;

static void enter_function_context(Symbol *symbol, SymbolKind kind) {
    FunctionContext *context = (FunctionContext *)malloc(sizeof(FunctionContext));
    if (!context) {
        fprintf(stderr, "Erro semantico na linha %d: memoria insuficiente ao analisar sub-rotina.\n", yylineno);
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

static void set_current_signature(ASTNode *params) {
    if (!function_context || !function_context->symbol) return;

    size_t count = 0;
    for (ASTNode *param = params; param; param = param->next) count++;

    DataType *types = NULL;
    if (count > 0) {
        types = (DataType *)malloc(count * sizeof(DataType));
        if (!types) {
            fprintf(stderr, "Erro semantico na linha %d: memoria insuficiente ao registrar parametros.\n", yylineno);
            semantic_errors++;
            return;
        }

        size_t index = 0;
        for (ASTNode *param = params; param; param = param->next) {
            types[index++] = param->data_type;
        }
    }

    if (!symtab_set_signature(function_context->symbol, types, count)) {
        fprintf(stderr, "Erro semantico na linha %d: nao foi possivel registrar a assinatura da sub-rotina.\n", yylineno);
        semantic_errors++;
    }
    free(types);
}

static void check_call_arguments(Symbol *sym, const char *name, ASTNode *args) {
    size_t arg_count = 0;
    for (ASTNode *arg = args; arg; arg = arg->next) arg_count++;

    if (arg_count != sym->param_count) {
        fprintf(stderr, "Erro semantico na linha %d: chamada de '%s' recebeu %zu argumento(s); esperado(s) %zu.\n",
                yylineno, name, arg_count, sym->param_count);
        semantic_errors++;
    }

    ASTNode *arg = args;
    size_t index = 0;
    while (arg && index < sym->param_count) {
        DataType expected = sym->param_types[index];
        if (arg->data_type != TYPE_UNKNOWN && !is_type_compatible(expected, arg->data_type)) {
            fprintf(stderr, "Erro semantico na linha %d: argumento %zu de '%s' tem tipo incompativel. Esperado '%s', recebido '%s'.\n",
                    yylineno, index + 1, name, datatype_to_str(expected), datatype_to_str(arg->data_type));
            semantic_errors++;
        }
        arg = arg->next;
        index++;
    }
}

static void check_return_statement(bool has_value) {
    if (!function_context) {
        fprintf(stderr, "Erro semantico na linha %d: RETORNAGLU so pode ser usado dentro de CHOCA ou NINHO.\n", yylineno);
        semantic_errors++;
    } else if (function_context->kind == SYM_PROCEDURE && has_value) {
        fprintf(stderr, "Erro semantico na linha %d: NINHO nao pode retornar um valor.\n", yylineno);
        semantic_errors++;
    } else if (function_context->kind == SYM_FUNCTION && !has_value) {
        fprintf(stderr, "Erro semantico na linha %d: CHOCA deve retornar um valor.\n", yylineno);
        semantic_errors++;
    }
}

static DataType infer_arith_type(const char *op, DataType left, DataType right) {
    if (left == TYPE_UNKNOWN || right == TYPE_UNKNOWN) return TYPE_UNKNOWN;
    if ((left == TYPE_INTEIRO || left == TYPE_REAL) &&
        (right == TYPE_INTEIRO || right == TYPE_REAL)) {
        if (left == TYPE_REAL || right == TYPE_REAL) return TYPE_REAL;
        return TYPE_INTEIRO;
    }
    fprintf(stderr, "Erro semantico na linha %d: operandos incompativeis para o operador aritmetico '%s' ('%s' e '%s').\n",
            yylineno, op, datatype_to_str(left), datatype_to_str(right));
    semantic_errors++;
    return TYPE_UNKNOWN;
}

static DataType check_rel_type(const char *op, DataType left, DataType right) {
    if (left == TYPE_UNKNOWN || right == TYPE_UNKNOWN) return TYPE_BOOLEANO;
    bool both_num = (left == TYPE_INTEIRO || left == TYPE_REAL) &&
                    (right == TYPE_INTEIRO || right == TYPE_REAL);
    bool same_eq = (strcmp(op, "==") == 0 || strcmp(op, "!=") == 0) && (left == right);
    if (!both_num && !same_eq) {
        fprintf(stderr, "Erro semantico na linha %d: operandos incompativeis para o operador relacional '%s' ('%s' e '%s').\n",
                yylineno, op, datatype_to_str(left), datatype_to_str(right));
        semantic_errors++;
    }
    return TYPE_BOOLEANO;
}

static DataType check_logic_type(const char *op, DataType left, DataType right) {
    if (left != TYPE_UNKNOWN && left != TYPE_BOOLEANO) {
        fprintf(stderr, "Erro semantico na linha %d: operador logico '%s' requer operandos booleanos (recebido '%s').\n",
                yylineno, op, datatype_to_str(left));
        semantic_errors++;
    } else if (right != TYPE_UNKNOWN && right != TYPE_BOOLEANO) {
        fprintf(stderr, "Erro semantico na linha %d: operador logico '%s' requer operandos booleanos (recebido '%s').\n",
                yylineno, op, datatype_to_str(right));
        semantic_errors++;
    }
    return TYPE_BOOLEANO;
}

static void check_cond_type(const char *cmd, DataType cond_type) {
    if (cond_type != TYPE_UNKNOWN && cond_type != TYPE_BOOLEANO) {
        fprintf(stderr, "Erro semantico na linha %d: a condicao de '%s' deve ser do tipo 'booleano' (recebido '%s').\n",
                yylineno, cmd, datatype_to_str(cond_type));
        semantic_errors++;
    }
}

static void collect_return_types(ASTNode *body, DataType *return_type, size_t *return_count) {
    ASTNode *curr = body;
    while (curr) {
        if (curr->type == NODE_RETURN && curr->left) {
            DataType current = curr->left->data_type;
            if (*return_count == 0) {
                *return_type = current;
            } else if (*return_type != current) {
                bool both_numeric = (*return_type == TYPE_INTEIRO || *return_type == TYPE_REAL) &&
                                    (current == TYPE_INTEIRO || current == TYPE_REAL);
                if (both_numeric) {
                    *return_type = TYPE_REAL;
                } else {
                    fprintf(stderr, "Erro semantico na linha %d: tipos de retorno incompativeis em CHOCA.\n", yylineno);
                    semantic_errors++;
                }
            }
            (*return_count)++;
        } else if (curr->type == NODE_IF) {
            collect_return_types(curr->right, return_type, return_count);
            collect_return_types(curr->extra, return_type, return_count);
        } else if (curr->type == NODE_WHILE || curr->type == NODE_FOR) {
            collect_return_types(curr->right, return_type, return_count);
        } else if (curr->type == NODE_BLOCK) {
            collect_return_types(curr->left, return_type, return_count);
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

static void update_function_call_types(ASTNode *node, const char *name, DataType type) {
    for (ASTNode *curr = node; curr; curr = curr->next) {
        if (curr->type == NODE_FUNC_CALL && strcmp(curr->name, name) == 0) {
            curr->data_type = type;
        }
        update_function_call_types(curr->left, name, type);
        update_function_call_types(curr->right, name, type);
        update_function_call_types(curr->extra, name, type);
        update_function_call_types(curr->init, name, type);
    }
}

static DataType infer_return_type(ASTNode *body, const char *name) {
    DataType return_type = TYPE_UNKNOWN;
    size_t return_count = 0;
    collect_return_types(body, &return_type, &return_count);

    if (return_count == 0) {
        if (!contains_return_statement(body)) {
            fprintf(stderr, "Erro semantico na linha %d: CHOCA '%s' nao possui RETORNAGLU com valor.\n", yylineno, name);
            semantic_errors++;
        }
    } else if (!statement_list_returns(body)) {
        fprintf(stderr, "Erro semantico na linha %d: nem todos os caminhos de CHOCA '%s' retornam um valor.\n", yylineno, name);
        semantic_errors++;
    }

    if (return_type == TYPE_UNKNOWN) return_type = TYPE_INTEIRO;
    update_function_call_types(body, name, return_type);
    return return_type;
}
%}

%union {
    int num_int;
    double num_real;
    char *str;
    struct ASTNode *node;
    DataType data_type;
}

/* Tokens tipados */
%token <str> ID
%token <data_type> TIPO
%token <num_int> LIT_INT LIT_BOOL
%token <num_real> LIT_REAL
%token <str> LIT_TEXTO

/* Palavras-chave e operadores */
%token GLU ATRIB GORGOREJA CISCA IFGLU ELSEGLU WHILEGLU FORGLU STOPGLU PULAGLU
%token CHOCA NINHO RETORNAGLU
%token OP_LE OP_GE OP_EQ OP_NE OP_AND OP_OR OP_NOT

/* Não-terminais associados a ASTNode* */
%type <node> programa comando_lista comando_lista_opt comando bloco_escopo
%type <node> decl_var atribuicao comando_saida comando_entrada
%type <node> comando_if else_opt comando_while comando_for for_init
%type <node> decl_proc decl_func lista_params_opt lista_params param
%type <node> chamada_func lista_args_opt lista_args expressao

/* Precedência e associatividade de operadores */
%left OP_OR
%left OP_AND
%right OP_NOT
%left OP_EQ OP_NE
%left '<' '>' OP_LE OP_GE
%left '+' '-'
%left '*' '/'
%right UMINUS

%%

programa:
    comando_lista {
        root = $1;
    }
    ;

comando_lista:
    comando comando_lista {
        if ($1 != NULL) {
            $1->next = $2;
            $$ = $1;
        } else {
            $$ = $2;
        }
    }
    | comando {
        $$ = $1;
    }
    ;

comando_lista_opt:
    comando_lista { $$ = $1; }
    | /* vazio */ { $$ = NULL; }
    ;

comando:
    decl_var ';'            { $$ = $1; }
    | atribuicao ';'        { $$ = $1; }
    | comando_saida ';'     { $$ = $1; }
    | comando_entrada ';'   { $$ = $1; }
    | comando_if            { $$ = $1; }
    | comando_while         { $$ = $1; }
    | comando_for           { $$ = $1; }
    | STOPGLU ';'           {
        if (loop_depth == 0) {
            fprintf(stderr, "Erro semantico na linha %d: STOPGLU so pode ser usado dentro de um laco.\n", yylineno);
            semantic_errors++;
        }
        $$ = create_node(NODE_BREAK);
    }
    | PULAGLU ';'           {
        if (loop_depth == 0) {
            fprintf(stderr, "Erro semantico na linha %d: PULAGLU so pode ser usado dentro de um laco.\n", yylineno);
            semantic_errors++;
        }
        $$ = create_node(NODE_CONTINUE);
    }
    | RETORNAGLU expressao ';' {
        check_return_statement(true);
        ASTNode *n = create_node(NODE_RETURN);
        n->left = $2;
        n->data_type = $2->data_type;
        $$ = n;
    }
    | RETORNAGLU ';' {
        check_return_statement(false);
        ASTNode *n = create_node(NODE_RETURN);
        n->data_type = TYPE_VOID;
        $$ = n;
    }
    | chamada_func ';'      { $$ = $1; }
    | decl_proc             { $$ = $1; }
    | decl_func             { $$ = $1; }
    | bloco_escopo {
        ASTNode *n = create_node(NODE_BLOCK);
        n->left = $1;
        $$ = n;
    }
    ;

bloco_escopo:
    '{' { symtab_enter_scope(st); } comando_lista_opt '}' {
        symtab_exit_scope(st);
        $$ = $3;
    }
    ;

decl_var:
    GLU ':' ID ':' TIPO ATRIB expressao {
        DataType expr_type = $7->data_type;

        if (expr_type != TYPE_UNKNOWN && !is_type_compatible($5, expr_type)) {
            fprintf(stderr, "Erro semantico na linha %d: tipo incompativel ao inicializar '%s'. Esperado '%s', recebido '%s'.\n",
                    yylineno, $3, datatype_to_str($5), datatype_to_str(expr_type));
            semantic_errors++;
        }

        if (!symtab_insert(st, $3, $5, SYM_VAR)) {
            fprintf(stderr, "Erro semantico na linha %d: identificador '%s' ja declarado neste escopo.\n",
                    yylineno, $3);
            semantic_errors++;
        }

        ASTNode *n = create_node(NODE_VAR_DECL);
        n->name = strdup(datatype_to_str($5));
        n->data_type = $5;
        n->left = create_id($3, $5);
        n->right = $7;
        $$ = n;
    }
    ;

atribuicao:
    ID ATRIB expressao {
        Symbol *sym = symtab_lookup(st, $1);
        DataType var_type = TYPE_UNKNOWN;
        if (!sym) {
            fprintf(stderr, "Erro semantico na linha %d: identificador '%s' nao declarado.\n", yylineno, $1);
            semantic_errors++;
        } else {
            var_type = sym->type;
            if ($3->data_type != TYPE_UNKNOWN && !is_type_compatible(var_type, $3->data_type)) {
                fprintf(stderr, "Erro semantico na linha %d: tipo incompativel na atribuicao para '%s'. Esperado '%s', recebido '%s'.\n",
                        yylineno, $1, datatype_to_str(var_type), datatype_to_str($3->data_type));
                semantic_errors++;
            }
        }

        ASTNode *n = create_node(NODE_ASSIGN);
        n->data_type = var_type;
        n->left = create_id($1, var_type);
        n->right = $3;
        $$ = n;
    }
    ;

comando_saida:
    GORGOREJA '(' expressao ')' {
        ASTNode *n = create_node(NODE_PRINT);
        n->left = $3;
        $$ = n;
    }
    ;

comando_entrada:
    CISCA '(' ID ')' {
        Symbol *sym = symtab_lookup(st, $3);
        DataType var_type = TYPE_INTEIRO;
        if (!sym) {
            fprintf(stderr, "Erro semantico na linha %d: identificador '%s' nao declarado.\n", yylineno, $3);
            semantic_errors++;
        } else {
            var_type = sym->type;
        }
        ASTNode *n = create_node(NODE_READ);
        n->left = create_id($3, var_type);
        $$ = n;
    }
    ;

comando_if:
    IFGLU '(' expressao ')' bloco_escopo else_opt {
        check_cond_type("IFGLU", $3->data_type);
        ASTNode *n = create_node(NODE_IF);
        n->left = $3;
        n->right = $5;
        n->extra = $6;
        $$ = n;
    }
    ;

else_opt:
    ELSEGLU bloco_escopo { $$ = $2; }
    | /* vazio */        { $$ = NULL; }
    ;

comando_while:
    WHILEGLU '(' expressao ')' { loop_depth++; } bloco_escopo {
        check_cond_type("WHILEGLU", $3->data_type);
        loop_depth--;
        ASTNode *n = create_node(NODE_WHILE);
        n->left = $3;
        n->right = $6;
        $$ = n;
    }
    ;

for_init:
    decl_var     { $$ = $1; }
    | atribuicao { $$ = $1; }
    ;

comando_for:
    FORGLU '(' { symtab_enter_scope(st); } for_init ';' expressao ';' atribuicao ')' '{' { loop_depth++; } comando_lista_opt '}' {
        check_cond_type("FORGLU", $6->data_type);
        loop_depth--;
        symtab_exit_scope(st);
        ASTNode *n = create_node(NODE_FOR);
        n->init = $4;
        n->left = $6;
        n->extra = $8;
        n->right = $12;
        $$ = n;
    }
    ;

decl_proc:
    NINHO ID {
        Symbol *symbol = NULL;
        if (!symtab_insert(st, $2, TYPE_VOID, SYM_PROCEDURE)) {
            fprintf(stderr, "Erro semantico na linha %d: procedimento '%s' ja declarado neste escopo.\n",
                    yylineno, $2);
            semantic_errors++;
        } else {
            symbol = symtab_lookup_current_scope(st, $2);
        }
        enter_function_context(symbol, SYM_PROCEDURE);
        symtab_enter_scope(st);
    } '(' lista_params_opt ')' {
        set_current_signature($5);
    } '{' comando_lista_opt '}' {
        symtab_exit_scope(st);
        leave_function_context();
        ASTNode *n = create_node(NODE_FUNC_DECL);
        n->name = strdup($2);
        n->data_type = TYPE_VOID;
        n->extra = $5;
        n->right = $9;
        $$ = n;
    }
    ;

decl_func:
    CHOCA ID {
        Symbol *symbol = NULL;
        if (!symtab_insert(st, $2, TYPE_INTEIRO, SYM_FUNCTION)) {
            fprintf(stderr, "Erro semantico na linha %d: funcao '%s' ja declarada neste escopo.\n",
                    yylineno, $2);
            semantic_errors++;
        } else {
            symbol = symtab_lookup_current_scope(st, $2);
        }
        enter_function_context(symbol, SYM_FUNCTION);
        symtab_enter_scope(st);
    } '(' lista_params_opt ')' {
        set_current_signature($5);
    } '{' comando_lista_opt '}' {
        symtab_exit_scope(st);
        DataType ret_type = infer_return_type($9, $2);
        if (function_context && function_context->symbol) {
            function_context->symbol->type = ret_type;
        }
        leave_function_context();
        ASTNode *n = create_node(NODE_FUNC_DECL);
        n->name = strdup($2);
        n->data_type = ret_type;
        n->extra = $5;
        n->right = $9;
        $$ = n;
    }
    ;

lista_params_opt:
    lista_params  { $$ = $1; }
    | /* vazio */ { $$ = NULL; }
    ;

lista_params:
    param ',' lista_params {
        $1->next = $3;
        $$ = $1;
    }
    | param {
        $$ = $1;
    }
    ;

param:
    TIPO ID {
        if (!symtab_insert(st, $2, $1, SYM_VAR)) {
            fprintf(stderr, "Erro semantico na linha %d: parametro '%s' duplicado.\n", yylineno, $2);
            semantic_errors++;
        }
        ASTNode *n = create_node(NODE_PARAM);
        n->name = strdup($2);
        n->data_type = $1;
        $$ = n;
    }
    ;

chamada_func:
    ID '(' lista_args_opt ')' {
        Symbol *sym = symtab_lookup(st, $1);
        DataType ret_type = TYPE_UNKNOWN;
        if (!sym) {
            fprintf(stderr, "Erro semantico na linha %d: funcao ou procedimento '%s' nao declarado.\n", yylineno, $1);
            semantic_errors++;
        } else if (sym->kind == SYM_VAR) {
            fprintf(stderr, "Erro semantico na linha %d: identificador '%s' declarado como variavel e nao pode ser chamado.\n",
                    yylineno, $1);
            semantic_errors++;
        } else {
            ret_type = sym->type;
            check_call_arguments(sym, $1, $3);
        }
        ASTNode *n = create_node(NODE_FUNC_CALL);
        n->name = strdup($1);
        n->data_type = ret_type;
        n->left = $3;
        $$ = n;
    }
    ;

lista_args_opt:
    lista_args    { $$ = $1; }
    | /* vazio */ { $$ = NULL; }
    ;

lista_args:
    expressao ',' lista_args {
        $1->next = $3;
        $$ = $1;
    }
    | expressao {
        $$ = $1;
    }
    ;

expressao:
    expressao '+' expressao    { $$ = create_bin_op("+", infer_arith_type("+", $1->data_type, $3->data_type), $1, $3); }
    | expressao '-' expressao  { $$ = create_bin_op("-", infer_arith_type("-", $1->data_type, $3->data_type), $1, $3); }
    | expressao '*' expressao  { $$ = create_bin_op("*", infer_arith_type("*", $1->data_type, $3->data_type), $1, $3); }
    | expressao '/' expressao  { $$ = create_bin_op("/", infer_arith_type("/", $1->data_type, $3->data_type), $1, $3); }
    | expressao '<' expressao  { $$ = create_bin_op("<", check_rel_type("<", $1->data_type, $3->data_type), $1, $3); }
    | expressao '>' expressao  { $$ = create_bin_op(">", check_rel_type(">", $1->data_type, $3->data_type), $1, $3); }
    | expressao OP_LE expressao { $$ = create_bin_op("<=", check_rel_type("<=", $1->data_type, $3->data_type), $1, $3); }
    | expressao OP_GE expressao { $$ = create_bin_op(">=", check_rel_type(">=", $1->data_type, $3->data_type), $1, $3); }
    | expressao OP_EQ expressao { $$ = create_bin_op("==", check_rel_type("==", $1->data_type, $3->data_type), $1, $3); }
    | expressao OP_NE expressao { $$ = create_bin_op("!=", check_rel_type("!=", $1->data_type, $3->data_type), $1, $3); }
    | expressao OP_AND expressao { $$ = create_bin_op("&&", check_logic_type("And", $1->data_type, $3->data_type), $1, $3); }
    | expressao OP_OR expressao  { $$ = create_bin_op("||", check_logic_type("or", $1->data_type, $3->data_type), $1, $3); }
    | OP_NOT expressao           { $$ = create_unary_op("!", check_logic_type("not", $2->data_type, TYPE_BOOLEANO), $2); }
    | '-' expressao %prec UMINUS { $$ = create_unary_op("-", infer_arith_type("-", $2->data_type, $2->data_type), $2); }
    | '(' expressao ')'        { $$ = $2; }
    | LIT_INT                  { $$ = create_num_int($1); }
    | LIT_REAL                 { $$ = create_num_real($1); }
    | LIT_BOOL                 { $$ = create_bool($1); }
    | LIT_TEXTO                { $$ = create_str($1); }
    | chamada_func             {
        if ($1->data_type == TYPE_VOID) {
            fprintf(stderr, "Erro semantico na linha %d: procedimento nao pode ser usado como expressao.\n", yylineno);
            semantic_errors++;
        }
        $$ = $1;
    }
    | ID {
        Symbol *sym = symtab_lookup(st, $1);
        DataType var_type = TYPE_UNKNOWN;
        if (!sym) {
            fprintf(stderr, "Erro semantico na linha %d: identificador '%s' nao declarado.\n", yylineno, $1);
            semantic_errors++;
        } else {
            var_type = sym->type;
        }
        $$ = create_id($1, var_type);
    }
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Erro sintatico proximo a linha %d: %s\n", yylineno, s);
}

int main(int argc, char **argv) {
    int dump_ast = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--ast") == 0 || strcmp(argv[i], "-a") == 0) {
            dump_ast = 1;
        }
    }

    st = symtab_create();

    if (yyparse() == 0 && lexical_errors == 0 && semantic_errors == 0) {
        if (dump_ast) {
            print_ast(root, stdout);
        } else {
            generate_code(root, stdout);
        }
    } else {
        fprintf(stderr, "\nCompilacao abortada: foram encontrados erros no programa.\n");
        free_ast(root);
        symtab_destroy(st);
        return 1;
    }

    free_ast(root);
    symtab_destroy(st);
    return 0;
}
