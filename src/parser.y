%{
#include <stdio.h>
#include <stdlib.h>
#include "ast.h"

int yylex();
void yyerror(const char *s);
extern int yylineno;

ASTNode *root = NULL;
%}

%union {
    int num_int;
    double num_real;
    char *str;
    struct ASTNode *node;
}

%token <str> ID TIPO LIT_TEXTO
%token <num_int> LIT_INT LIT_BOOL
%token <num_real> LIT_REAL
%token GLU ATRIB GORGOREJA CISCA IFGLU WHILEGLU FORGLU STOPGLU PULAGLU
%token CHOCA NINHO RETORNAGLU OP_LE OP_GE OP_EQ

%type <node> programa comando_lista comando decl_var comando_saida expressao

%left '+' '-'
%left '*' '/'

%%

programa:
    comando_lista { root = $1; }
    ;

comando_lista:
    comando comando_lista {
        $1->next = $2;
        $$ = $1;
    }
    | comando {
        $$ = $1;
    }
    ;

comando:
    decl_var ';'      { $$ = $1; }
    | comando_saida ';' { $$ = $1; }
    ;

decl_var:
    GLU ':' ID ':' TIPO ATRIB expressao {
        ASTNode *n = create_node(NODE_VAR_DECL);
        n->name = $5;             // Tipo C (int, double, ...)
        n->left = create_id($3);  // Nome da variavel
        n->right = $7;            // Expressao atribuida
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

expressao:
    expressao '+' expressao   { $$ = create_bin_op('+', $1, $3); }
    | expressao '-' expressao { $$ = create_bin_op('-', $1, $3); }
    | expressao '*' expressao { $$ = create_bin_op('*', $1, $3); }
    | expressao '/' expressao { $$ = create_bin_op('/', $1, $3); }
    | '(' expressao ')'       { $$ = $2; }
    | LIT_INT                 { $$ = create_num_int($1); }
    | LIT_REAL                { $$ = create_num_real($1); }
    | LIT_TEXTO               { $$ = create_str($1); }
    | ID                      { $$ = create_id($1); }
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Erro sintatico proximo a linha %d: %s\n", yylineno, s);
}

int main(int argc, char **argv) {
    if (yyparse() == 0) {
        generate_code(root, stdout);
    }
    return 0;
}