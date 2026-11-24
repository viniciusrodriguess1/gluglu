%{
#include <stdio.h>
#include <stdlib.h>
#include "ast.h"
#include "lexer.h"
#include "semantic.h"

void yyerror(const char *s);

ASTNode *root = NULL;
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

%destructor { free($$); } ID LIT_TEXTO

/* Palavras-chave */
%token GLU ATRIB GORGOREJA CISCA IFGLU ELSEGLU WHILEGLU FORGLU STOPGLU PULAGLU
%token CHOCA NINHO RETORNAGLU

/* Delimitadores e pontuação */
%token DOIS_PONTOS PONTO_VIRGULA VIRGULA ABRE_CHAVE FECHA_CHAVE ABRE_PAREN FECHA_PAREN

/* Operadores */
%token OP_MAIS OP_MENOS OP_MULT OP_DIV
%token OP_MENOR OP_MAIOR OP_LE OP_GE OP_EQ OP_NE OP_AND OP_OR OP_NOT

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
%left OP_MENOR OP_MAIOR OP_LE OP_GE
%left OP_MAIS OP_MENOS
%left OP_MULT OP_DIV
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
    decl_var PONTO_VIRGULA          { $$ = $1; }
    | atribuicao PONTO_VIRGULA      { $$ = $1; }
    | comando_saida PONTO_VIRGULA   { $$ = $1; }
    | comando_entrada PONTO_VIRGULA { $$ = $1; }
    | comando_if                    { $$ = $1; }
    | comando_while                 { $$ = $1; }
    | comando_for                   { $$ = $1; }
    | STOPGLU PONTO_VIRGULA {
        semantic_check_loop_control("STOPGLU", yylineno);
        $$ = create_node(NODE_BREAK);
    }
    | PULAGLU PONTO_VIRGULA {
        semantic_check_loop_control("PULAGLU", yylineno);
        $$ = create_node(NODE_CONTINUE);
    }
    | RETORNAGLU expressao PONTO_VIRGULA {
        semantic_check_return(true, yylineno);
        ASTNode *n = create_node(NODE_RETURN);
        n->left = $2;
        n->data_type = $2->data_type;
        $$ = n;
    }
    | RETORNAGLU PONTO_VIRGULA {
        semantic_check_return(false, yylineno);
        ASTNode *n = create_node(NODE_RETURN);
        n->data_type = TYPE_VOID;
        $$ = n;
    }
    | chamada_func PONTO_VIRGULA    { $$ = $1; }
    | decl_proc                     { $$ = $1; }
    | decl_func                     { $$ = $1; }
    | bloco_escopo {
        ASTNode *n = create_node(NODE_BLOCK);
        n->left = $1;
        $$ = n;
    }
    ;

bloco_escopo:
    ABRE_CHAVE { semantic_enter_scope(); } comando_lista_opt FECHA_CHAVE {
        semantic_exit_scope();
        $$ = $3;
    }
    ;

decl_var:
    GLU DOIS_PONTOS ID DOIS_PONTOS TIPO ATRIB expressao {
        semantic_declare_var($3, $5, $7->data_type, yylineno);

        ASTNode *n = create_node(NODE_VAR_DECL);
        n->name = gluglu_strdup(datatype_to_str($5));
        n->data_type = $5;
        n->left = create_id($3, $5);
        n->right = $7;
        free($3);
        $$ = n;
    }
    ;

atribuicao:
    ID ATRIB expressao {
        DataType var_type = semantic_check_assignment($1, $3->data_type, yylineno);

        ASTNode *n = create_node(NODE_ASSIGN);
        n->data_type = var_type;
        n->left = create_id($1, var_type);
        n->right = $3;
        free($1);
        $$ = n;
    }
    ;

comando_saida:
    GORGOREJA ABRE_PAREN expressao FECHA_PAREN {
        ASTNode *n = create_node(NODE_PRINT);
        n->left = $3;
        $$ = n;
    }
    ;

comando_entrada:
    CISCA ABRE_PAREN ID FECHA_PAREN {
        DataType var_type = semantic_check_read($3, yylineno);

        ASTNode *n = create_node(NODE_READ);
        n->left = create_id($3, var_type);
        free($3);
        $$ = n;
    }
    ;

comando_if:
    IFGLU ABRE_PAREN expressao FECHA_PAREN bloco_escopo else_opt {
        semantic_check_condition("IFGLU", $3->data_type, yylineno);

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
    WHILEGLU ABRE_PAREN expressao FECHA_PAREN { semantic_enter_loop(); } bloco_escopo {
        semantic_check_condition("WHILEGLU", $3->data_type, yylineno);
        semantic_exit_loop();

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
    FORGLU ABRE_PAREN { semantic_enter_scope(); } for_init PONTO_VIRGULA expressao PONTO_VIRGULA atribuicao FECHA_PAREN
    ABRE_CHAVE { semantic_enter_loop(); } comando_lista_opt FECHA_CHAVE {
        semantic_check_condition("FORGLU", $6->data_type, yylineno);
        semantic_exit_loop();
        semantic_exit_scope();

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
        semantic_begin_procedure($2, yylineno);
    } ABRE_PAREN lista_params_opt FECHA_PAREN {
        semantic_register_params($5, yylineno);
    } ABRE_CHAVE comando_lista_opt FECHA_CHAVE {
        semantic_end_procedure();

        ASTNode *n = create_node(NODE_FUNC_DECL);
        n->name = gluglu_strdup($2);
        n->data_type = TYPE_VOID;
        n->extra = $5;
        n->right = $9;
        free($2);
        $$ = n;
    }
    ;

decl_func:
    CHOCA ID {
        semantic_begin_function($2, yylineno);
    } ABRE_PAREN lista_params_opt FECHA_PAREN {
        semantic_register_params($5, yylineno);
    } ABRE_CHAVE comando_lista_opt FECHA_CHAVE {
        DataType ret_type = semantic_end_function($9, $2, yylineno);

        ASTNode *n = create_node(NODE_FUNC_DECL);
        n->name = gluglu_strdup($2);
        n->data_type = ret_type;
        n->extra = $5;
        n->right = $9;
        free($2);
        $$ = n;
    }
    ;

lista_params_opt:
    lista_params  { $$ = $1; }
    | /* vazio */ { $$ = NULL; }
    ;

lista_params:
    param VIRGULA lista_params {
        $1->next = $3;
        $$ = $1;
    }
    | param {
        $$ = $1;
    }
    ;

param:
    TIPO ID {
        semantic_declare_param($2, $1, yylineno);

        ASTNode *n = create_node(NODE_PARAM);
        n->name = gluglu_strdup($2);
        n->data_type = $1;
        free($2);
        $$ = n;
    }
    ;

chamada_func:
    ID ABRE_PAREN lista_args_opt FECHA_PAREN {
        DataType ret_type = semantic_check_call($1, $3, yylineno);

        ASTNode *n = create_node(NODE_FUNC_CALL);
        n->name = gluglu_strdup($1);
        n->data_type = ret_type;
        n->left = $3;
        free($1);
        $$ = n;
    }
    ;

lista_args_opt:
    lista_args    { $$ = $1; }
    | /* vazio */ { $$ = NULL; }
    ;

lista_args:
    expressao VIRGULA lista_args {
        $1->next = $3;
        $$ = $1;
    }
    | expressao {
        $$ = $1;
    }
    ;

expressao:
    expressao OP_MAIS expressao        { $$ = create_bin_op("+", semantic_infer_arith("+", $1->data_type, $3->data_type, yylineno), $1, $3); }
    | expressao OP_MENOS expressao     { $$ = create_bin_op("-", semantic_infer_arith("-", $1->data_type, $3->data_type, yylineno), $1, $3); }
    | expressao OP_MULT expressao      { $$ = create_bin_op("*", semantic_infer_arith("*", $1->data_type, $3->data_type, yylineno), $1, $3); }
    | expressao OP_DIV expressao       { $$ = create_bin_op("/", semantic_infer_arith("/", $1->data_type, $3->data_type, yylineno), $1, $3); }
    | expressao OP_MENOR expressao     { $$ = create_bin_op("<", semantic_check_rel("<", $1->data_type, $3->data_type, yylineno), $1, $3); }
    | expressao OP_MAIOR expressao     { $$ = create_bin_op(">", semantic_check_rel(">", $1->data_type, $3->data_type, yylineno), $1, $3); }
    | expressao OP_LE expressao        { $$ = create_bin_op("<=", semantic_check_rel("<=", $1->data_type, $3->data_type, yylineno), $1, $3); }
    | expressao OP_GE expressao        { $$ = create_bin_op(">=", semantic_check_rel(">=", $1->data_type, $3->data_type, yylineno), $1, $3); }
    | expressao OP_EQ expressao        { $$ = create_bin_op("==", semantic_check_rel("==", $1->data_type, $3->data_type, yylineno), $1, $3); }
    | expressao OP_NE expressao        { $$ = create_bin_op("!=", semantic_check_rel("!=", $1->data_type, $3->data_type, yylineno), $1, $3); }
    | expressao OP_AND expressao       { $$ = create_bin_op("&&", semantic_check_logic("and", $1->data_type, $3->data_type, yylineno), $1, $3); }
    | expressao OP_OR expressao        { $$ = create_bin_op("||", semantic_check_logic("or", $1->data_type, $3->data_type, yylineno), $1, $3); }
    | OP_NOT expressao                 { $$ = create_unary_op("!", semantic_check_logic("not", $2->data_type, TYPE_BOOLEANO, yylineno), $2); }
    | OP_MENOS expressao %prec UMINUS  { $$ = create_unary_op("-", semantic_infer_unary_minus($2->data_type, yylineno), $2); }
    | ABRE_PAREN expressao FECHA_PAREN { $$ = $2; }
    | LIT_INT                          { $$ = create_num_int($1); }
    | LIT_REAL                         { $$ = create_num_real($1); }
    | LIT_BOOL                         { $$ = create_bool($1); }
    | LIT_TEXTO                        { $$ = create_str($1); free($1); }
    | chamada_func {
        semantic_check_call_as_expr($1->data_type, yylineno);
        $$ = $1;
    }
    | ID {
        DataType var_type = semantic_check_var_use($1, yylineno);
        $$ = create_id($1, var_type);
        free($1);
    }
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Erro sintatico proximo a linha %d, coluna %d: %s\n", yylineno, token_column, s);
}
