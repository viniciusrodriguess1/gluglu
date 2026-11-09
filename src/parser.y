%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"
#include "symtab.h"

extern int yylineno;
int yylex();
void yyerror(const char *s);

SymbolTable *st = NULL;
ASTNode *root = NULL;
int semantic_errors = 0;
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
%token GLU ATRIB GORGOREJA CISCA IFGLU WHILEGLU FORGLU STOPGLU PULAGLU
%token CHOCA NINHO RETORNAGLU OP_LE OP_GE OP_EQ

/* Não-terminais associados a ASTNode* */
%type <node> programa comando_lista comando decl_var comando_saida expressao

/* Precedência de operadores aritméticos */
%left '+' '-'
%left '*' '/'

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

comando:
    decl_var ';'        { $$ = $1; }
    | comando_saida ';' { $$ = $1; }
    | '{' { symtab_enter_scope(st); } comando_lista '}' { 
        symtab_exit_scope(st); 
        $$ = $3; 
    }
    ;

decl_var:
    GLU ':' ID ':' TIPO ATRIB expressao {
        /* 1. Validação Semântica: Compatibilidade de tipos na inicialização */
        DataType expr_type = TYPE_UNKNOWN;
        if ($7->type == NODE_NUM_INT) expr_type = TYPE_INTEIRO;
        else if ($7->type == NODE_NUM_REAL) expr_type = TYPE_REAL;
        else if ($7->type == NODE_STRING) expr_type = TYPE_TEXTO;
        else if ($7->type == NODE_BOOL) expr_type = TYPE_BOOLEANO;
        else if ($7->type == NODE_ID) {
            Symbol *s = symtab_lookup(st, $7->name);
            if (s) expr_type = s->type;
        }

        if (expr_type != TYPE_UNKNOWN && !is_type_compatible($5, expr_type)) {
            fprintf(stderr, "Erro semantico na linha %d: tipo incompativel ao inicializar '%s'. Esperado '%s', recebido '%s'.\n",
                    yylineno, $3, datatype_to_str($5), datatype_to_str(expr_type));
            semantic_errors++;
        }

        /* 2. Validação Semântica: Duplicidade no mesmo escopo */
        if (!symtab_insert(st, $3, $5, SYM_VAR)) {
            fprintf(stderr, "Erro semantico na linha %d: identificador '%s' ja declarado neste escopo.\n",
                    yylineno, $3);
            semantic_errors++;
        }

        /* 3. Construção do nó na AST para tradução posterior */
        ASTNode *n = create_node(NODE_VAR_DECL);
        n->name = strdup(datatype_to_str($5)); // Armazena o tipo C correspondente
        n->left = create_id($3);
        n->right = $7;
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
    | ID {
        /* Validação Semântica: Uso de variável não declarada */
        Symbol *sym = symtab_lookup(st, $1);
        if (!sym) {
            fprintf(stderr, "Erro semantico na linha %d: identificador '%s' nao declarado.\n", yylineno, $1);
            semantic_errors++;
        }
        $$ = create_id($1);
    }
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Erro sintatico proximo a linha %d: %s\n", yylineno, s);
}

int main(int argc, char **argv) {
    st = symtab_create();

    if (yyparse() == 0 && semantic_errors == 0) {
        generate_code(root, stdout);
    } else {
        fprintf(stderr, "\nCompilacao abortada: foram encontrados erros no programa.\n");
    }

    symtab_destroy(st);
    return (semantic_errors == 0) ? 0 : 1;
}