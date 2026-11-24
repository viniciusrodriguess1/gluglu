%{
#include "symtab.h"
#include "ast.h"
#include "parser.tab.h"
#include <stdlib.h>
#include <string.h>

extern int lexical_errors;

typedef enum {
    LEX_CTX_EXPR_START = 0,
    LEX_CTX_AFTER_TYPE = 1,
    LEX_CTX_AFTER_VALUE = 2
} LexContext;

static LexContext lex_ctx = LEX_CTX_EXPR_START;
static char *text_buf = NULL;
static size_t text_len = 0;
static size_t text_cap = 0;

static void text_buf_reset(void) {
    free(text_buf);
    text_buf = NULL;
    text_len = 0;
    text_cap = 0;
}

static void text_buf_append(const char *src, size_t len) {
    if (text_len + len + 1 > text_cap) {
        size_t new_cap = text_cap == 0 ? 64 : text_cap;
        while (new_cap < text_len + len + 1) {
            new_cap *= 2;
        }
        char *grown = (char *)realloc(text_buf, new_cap);
        if (!grown) {
            text_buf_reset();
            fputs("Erro interno: memoria insuficiente ao ler literal de texto.\n", stderr);
            exit(EXIT_FAILURE);
        }
        text_buf = grown;
        text_cap = new_cap;
    }
    memcpy(text_buf + text_len, src, len);
    text_len += len;
    text_buf[text_len] = '\0';
}

static char *text_buf_take(void) {
    if (!text_buf) {
        char *empty = gluglu_strdup("");
        if (!empty) {
            fputs("Erro interno: memoria insuficiente ao ler literal de texto.\n", stderr);
            exit(EXIT_FAILURE);
        }
        return empty;
    }
    char *result = text_buf;
    text_buf = NULL;
    text_len = 0;
    text_cap = 0;
    return result;
}
%}

%option noyywrap
%option yylineno
%option nounput
%option noinput

%x MULTI_COMMENT
%x TEXT_LIT

%%

[ \t\r]+                ; /* Ignora espacos e tabs */
\n                      ;

"%%".*                  ; /* Comentario de linha unica */

"%glu"                  { BEGIN(MULTI_COMMENT); }
<MULTI_COMMENT>"%glu"   { BEGIN(INITIAL); }
<MULTI_COMMENT>\n       ;
<MULTI_COMMENT>.        ;
<MULTI_COMMENT><<EOF>>  {
                            fprintf(stderr, "Erro lexico na linha %d: comentario multilinha nao fechado.\n", yylineno);
                            lexical_errors++;
                            BEGIN(INITIAL);
                            return 0;
                        }

<TEXT_LIT>">"           {
                            yylval.str = text_buf_take();
                            lex_ctx = LEX_CTX_AFTER_VALUE;
                            BEGIN(INITIAL);
                            return LIT_TEXTO;
                        }
<TEXT_LIT>[^>\n]+       {
                            text_buf_append(yytext, (size_t)yyleng);
                        }
<TEXT_LIT>\n            {
                            text_buf_reset();
                            fprintf(stderr, "Erro lexico na linha %d: literal de texto nao fechado.\n", yylineno - 1);
                            lexical_errors++;
                            lex_ctx = LEX_CTX_EXPR_START;
                            BEGIN(INITIAL);
                        }
<TEXT_LIT><<EOF>>       {
                            text_buf_reset();
                            fprintf(stderr, "Erro lexico na linha %d: literal de texto nao fechado.\n", yylineno);
                            lexical_errors++;
                            lex_ctx = LEX_CTX_EXPR_START;
                            BEGIN(INITIAL);
                            return 0;
                        }

"glu"                   { lex_ctx = LEX_CTX_EXPR_START; return GLU; }
"inteiro"               { lex_ctx = LEX_CTX_AFTER_TYPE; yylval.data_type = TYPE_INTEIRO; return TIPO; }
"real"                  { lex_ctx = LEX_CTX_AFTER_TYPE; yylval.data_type = TYPE_REAL; return TIPO; }
"booleano"              { lex_ctx = LEX_CTX_AFTER_TYPE; yylval.data_type = TYPE_BOOLEANO; return TIPO; }
"texto"                 { lex_ctx = LEX_CTX_AFTER_TYPE; yylval.data_type = TYPE_TEXTO; return TIPO; }

"GORGOREJA"             { lex_ctx = LEX_CTX_EXPR_START; return GORGOREJA; }
"CISCA"                 { lex_ctx = LEX_CTX_EXPR_START; return CISCA; }
"IFGLU"                 { lex_ctx = LEX_CTX_EXPR_START; return IFGLU; }
"ELSEGLU"               { lex_ctx = LEX_CTX_EXPR_START; return ELSEGLU; }
"WHILEGLU"              { lex_ctx = LEX_CTX_EXPR_START; return WHILEGLU; }
"FORGLU"                { lex_ctx = LEX_CTX_EXPR_START; return FORGLU; }
"STOPGLU"               { lex_ctx = LEX_CTX_EXPR_START; return STOPGLU; }
"PULAGLU"               { lex_ctx = LEX_CTX_EXPR_START; return PULAGLU; }
"CHOCA"                 { lex_ctx = LEX_CTX_EXPR_START; return CHOCA; }
"NINHO"                 { lex_ctx = LEX_CTX_EXPR_START; return NINHO; }
"RETORNAGLU"            { lex_ctx = LEX_CTX_EXPR_START; return RETORNAGLU; }

"and"                   { lex_ctx = LEX_CTX_EXPR_START; return OP_AND; }
"or"                    { lex_ctx = LEX_CTX_EXPR_START; return OP_OR; }
"not"                   { lex_ctx = LEX_CTX_EXPR_START; return OP_NOT; }

"true"                  { lex_ctx = LEX_CTX_AFTER_VALUE; yylval.num_int = 1; return LIT_BOOL; }
"false"                 { lex_ctx = LEX_CTX_AFTER_VALUE; yylval.num_int = 0; return LIT_BOOL; }

"<-"                    {
                            if (lex_ctx == LEX_CTX_EXPR_START) {
                                yyless(1);
                                text_buf_reset();
                                BEGIN(TEXT_LIT);
                            } else {
                                lex_ctx = LEX_CTX_EXPR_START;
                                return ATRIB;
                            }
                        }
"<="                    {
                            if (lex_ctx == LEX_CTX_AFTER_VALUE) {
                                lex_ctx = LEX_CTX_EXPR_START;
                                return OP_LE;
                            } else {
                                yyless(1);
                                text_buf_reset();
                                BEGIN(TEXT_LIT);
                            }
                        }
"<"                     {
                            if (lex_ctx == LEX_CTX_AFTER_VALUE) {
                                lex_ctx = LEX_CTX_EXPR_START;
                                return '<';
                            } else {
                                text_buf_reset();
                                BEGIN(TEXT_LIT);
                            }
                        }

":"                     { lex_ctx = LEX_CTX_EXPR_START; return ':'; }
";"                     { lex_ctx = LEX_CTX_EXPR_START; return ';'; }
","                     { lex_ctx = LEX_CTX_EXPR_START; return ','; }
"{"                     { lex_ctx = LEX_CTX_EXPR_START; return '{'; }
"}"                     { lex_ctx = LEX_CTX_EXPR_START; return '}'; }
"("                     { lex_ctx = LEX_CTX_EXPR_START; return '('; }
")"                     { lex_ctx = LEX_CTX_AFTER_VALUE; return ')'; }

"+"                     { lex_ctx = LEX_CTX_EXPR_START; return '+'; }
"-"                     { lex_ctx = LEX_CTX_EXPR_START; return '-'; }
"*"                     { lex_ctx = LEX_CTX_EXPR_START; return '*'; }
"/"                     { lex_ctx = LEX_CTX_EXPR_START; return '/'; }

">="                    { lex_ctx = LEX_CTX_EXPR_START; return OP_GE; }
"=="                    { lex_ctx = LEX_CTX_EXPR_START; return OP_EQ; }
"!="                    { lex_ctx = LEX_CTX_EXPR_START; return OP_NE; }
">"                     { lex_ctx = LEX_CTX_EXPR_START; return '>'; }

[0-9]+\.[0-9]+          { lex_ctx = LEX_CTX_AFTER_VALUE; yylval.num_real = atof(yytext); return LIT_REAL; }
[0-9]+                  { lex_ctx = LEX_CTX_AFTER_VALUE; yylval.num_int = atoi(yytext); return LIT_INT; }

[a-zA-Z_][a-zA-Z0-9_]*  {
                            lex_ctx = LEX_CTX_AFTER_VALUE;
                            yylval.str = gluglu_strdup(yytext);
                            if (!yylval.str) {
                                fputs("Erro interno: memoria insuficiente.\n", stderr);
                                exit(EXIT_FAILURE);
                            }
                            return ID;
                        }

.                       {
                            fprintf(stderr, "Erro lexico na linha %d: simbolo desconhecido '%s'.\n", yylineno, yytext);
                            lexical_errors++;
                        }

%%
