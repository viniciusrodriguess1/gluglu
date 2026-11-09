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

static DataType infer_return_type(ASTNode *body) {
    ASTNode *curr = body;
    while (curr) {
        if (curr->type == NODE_RETURN && curr->left) {
            return curr->left->data_type;
        }
        if (curr->type == NODE_IF || curr->type == NODE_WHILE || curr->type == NODE_FOR) {
            DataType rt = infer_return_type(curr->right);
            if (rt != TYPE_UNKNOWN) return rt;
            if (curr->extra) {
                rt = infer_return_type(curr->extra);
                if (rt != TYPE_UNKNOWN) return rt;
            }
        } else if (curr->type == NODE_BLOCK) {
            DataType rt = infer_return_type(curr->left);
            if (rt != TYPE_UNKNOWN) return rt;
        }
        curr = curr->next;
    }
    return TYPE_INTEIRO;
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
    | STOPGLU ';'           { $$ = create_node(NODE_BREAK); }
    | PULAGLU ';'           { $$ = create_node(NODE_CONTINUE); }
    | RETORNAGLU expressao ';' {
        ASTNode *n = create_node(NODE_RETURN);
        n->left = $2;
        n->data_type = $2->data_type;
        $$ = n;
    }
    | RETORNAGLU ';' {
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
    WHILEGLU '(' expressao ')' bloco_escopo {
        check_cond_type("WHILEGLU", $3->data_type);
        ASTNode *n = create_node(NODE_WHILE);
        n->left = $3;
        n->right = $5;
        $$ = n;
    }
    ;

for_init:
    decl_var     { $$ = $1; }
    | atribuicao { $$ = $1; }
    ;

comando_for:
    FORGLU '(' { symtab_enter_scope(st); } for_init ';' expressao ';' atribuicao ')' '{' comando_lista_opt '}' {
        check_cond_type("FORGLU", $6->data_type);
        symtab_exit_scope(st);
        ASTNode *n = create_node(NODE_FOR);
        n->init = $4;
        n->left = $6;
        n->extra = $8;
        n->right = $11;
        $$ = n;
    }
    ;

decl_proc:
    NINHO ID {
        if (!symtab_insert(st, $2, TYPE_VOID, SYM_PROCEDURE)) {
            fprintf(stderr, "Erro semantico na linha %d: procedimento '%s' ja declarado neste escopo.\n",
                    yylineno, $2);
            semantic_errors++;
        }
        symtab_enter_scope(st);
    } '(' lista_params_opt ')' '{' comando_lista_opt '}' {
        symtab_exit_scope(st);
        ASTNode *n = create_node(NODE_FUNC_DECL);
        n->name = strdup($2);
        n->data_type = TYPE_VOID;
        n->extra = $5;
        n->right = $8;
        $$ = n;
    }
    ;

decl_func:
    CHOCA ID {
        if (!symtab_insert(st, $2, TYPE_INTEIRO, SYM_FUNCTION)) {
            fprintf(stderr, "Erro semantico na linha %d: funcao '%s' ja declarada neste escopo.\n",
                    yylineno, $2);
            semantic_errors++;
        }
        symtab_enter_scope(st);
    } '(' lista_params_opt ')' '{' comando_lista_opt '}' {
        symtab_exit_scope(st);
        DataType ret_type = infer_return_type($8);
        Symbol *f_sym = symtab_lookup(st, $2);
        if (f_sym && ret_type != TYPE_UNKNOWN) {
            f_sym->type = ret_type;
        }
        ASTNode *n = create_node(NODE_FUNC_DECL);
        n->name = strdup($2);
        n->data_type = (ret_type != TYPE_UNKNOWN) ? ret_type : TYPE_INTEIRO;
        n->extra = $5;
        n->right = $8;
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
        } else {
            ret_type = sym->type;
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
    | chamada_func             { $$ = $1; }
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
