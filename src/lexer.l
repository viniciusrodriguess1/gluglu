%{
#include "symtab.h"
#include "ast.h"
#include "lexer.h"
#include "parser.tab.h"
#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>

int lexical_errors = 0;
int token_column = 1;

static int yycolumn = 1;
static int text_start_line = 1;
static int text_start_col = 1;
static int comment_start_line = 1;
static int comment_start_col = 1;

#define YY_USER_ACTION \
    token_column = yycolumn; \
    yycolumn += yyleng;

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

static int parse_int_literal(const char *text) {
    char *end = NULL;
    errno = 0;
    long value = strtol(text, &end, 10);
    if (errno == ERANGE || !end || *end != '\0' || value < INT_MIN || value > INT_MAX) {
        fprintf(stderr, "Erro lexico na linha %d, coluna %d: literal inteiro '%s' fora da faixa suportada.\n",
                yylineno, token_column, text);
        lexical_errors++;
        return 0;
    }
    return (int)value;
}

static double parse_real_literal(const char *text) {
    char *end = NULL;
    errno = 0;
    double value = strtod(text, &end);
    if (errno == ERANGE || !end || *end != '\0') {
        fprintf(stderr, "Erro lexico na linha %d, coluna %d: literal real '%s' fora da faixa suportada.\n",
                yylineno, token_column, text);
        lexical_errors++;
        return 0.0;
    }
    return value;
}

const char *lexer_token_name(int token) {
    switch (token) {
        case ID:            return "ID";
        case TIPO:          return "TIPO";
        case LIT_INT:       return "LIT_INT";
        case LIT_REAL:      return "LIT_REAL";
        case LIT_BOOL:      return "LIT_BOOL";
        case LIT_TEXTO:     return "LIT_TEXTO";
        case GLU:           return "GLU";
        case ATRIB:         return "ATRIB";
        case GORGOREJA:     return "GORGOREJA";
        case CISCA:         return "CISCA";
        case IFGLU:         return "IFGLU";
        case ELSEGLU:       return "ELSEGLU";
        case WHILEGLU:      return "WHILEGLU";
        case FORGLU:        return "FORGLU";
        case STOPGLU:       return "STOPGLU";
        case PULAGLU:       return "PULAGLU";
        case CHOCA:         return "CHOCA";
        case NINHO:         return "NINHO";
        case RETORNAGLU:    return "RETORNAGLU";
        case DOIS_PONTOS:   return "DOIS_PONTOS";
        case PONTO_VIRGULA: return "PONTO_VIRGULA";
        case VIRGULA:       return "VIRGULA";
        case ABRE_CHAVE:    return "ABRE_CHAVE";
        case FECHA_CHAVE:   return "FECHA_CHAVE";
        case ABRE_PAREN:    return "ABRE_PAREN";
        case FECHA_PAREN:   return "FECHA_PAREN";
        case OP_MAIS:       return "OP_MAIS";
        case OP_MENOS:      return "OP_MENOS";
        case OP_MULT:       return "OP_MULT";
        case OP_DIV:        return "OP_DIV";
        case OP_MENOR:      return "OP_MENOR";
        case OP_MAIOR:      return "OP_MAIOR";
        case OP_LE:         return "OP_LE";
        case OP_GE:         return "OP_GE";
        case OP_EQ:         return "OP_EQ";
        case OP_NE:         return "OP_NE";
        case OP_AND:        return "OP_AND";
        case OP_OR:         return "OP_OR";
        case OP_NOT:        return "OP_NOT";
        default:            return "DESCONHECIDO";
    }
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
\n                      { yycolumn = 1; }

"%%".*                  ; /* Comentario de linha unica */

"%glu"                  {
                            comment_start_line = yylineno;
                            comment_start_col = token_column;
                            BEGIN(MULTI_COMMENT);
                        }
<MULTI_COMMENT>"%glu"   { BEGIN(INITIAL); }
<MULTI_COMMENT>\n       { yycolumn = 1; }
<MULTI_COMMENT>.        ;
<MULTI_COMMENT><<EOF>>  {
                            fprintf(stderr, "Erro lexico na linha %d, coluna %d: comentario multilinha nao fechado.\n",
                                    comment_start_line, comment_start_col);
                            lexical_errors++;
                            BEGIN(INITIAL);
                            return 0;
                        }

<TEXT_LIT>">"           {
                            yylval.str = text_buf_take();
                            token_column = text_start_col;
                            lex_ctx = LEX_CTX_AFTER_VALUE;
                            BEGIN(INITIAL);
                            return LIT_TEXTO;
                        }
<TEXT_LIT>[^>\n]+       {
                            text_buf_append(yytext, (size_t)yyleng);
                        }
<TEXT_LIT>\n            {
                            text_buf_reset();
                            fprintf(stderr, "Erro lexico na linha %d, coluna %d: literal de texto nao fechado.\n",
                                    text_start_line, text_start_col);
                            lexical_errors++;
                            yycolumn = 1;
                            lex_ctx = LEX_CTX_EXPR_START;
                            BEGIN(INITIAL);
                        }
<TEXT_LIT><<EOF>>       {
                            text_buf_reset();
                            fprintf(stderr, "Erro lexico na linha %d, coluna %d: literal de texto nao fechado.\n",
                                    text_start_line, text_start_col);
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
                                yycolumn -= 1;
                                text_start_line = yylineno;
                                text_start_col = token_column;
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
                                yycolumn -= 1;
                                text_start_line = yylineno;
                                text_start_col = token_column;
                                text_buf_reset();
                                BEGIN(TEXT_LIT);
                            }
                        }
"<"                     {
                            if (lex_ctx == LEX_CTX_AFTER_VALUE) {
                                lex_ctx = LEX_CTX_EXPR_START;
                                return OP_MENOR;
                            } else {
                                text_start_line = yylineno;
                                text_start_col = token_column;
                                text_buf_reset();
                                BEGIN(TEXT_LIT);
                            }
                        }

":"                     { lex_ctx = LEX_CTX_EXPR_START; return DOIS_PONTOS; }
";"                     { lex_ctx = LEX_CTX_EXPR_START; return PONTO_VIRGULA; }
","                     { lex_ctx = LEX_CTX_EXPR_START; return VIRGULA; }
"{"                     { lex_ctx = LEX_CTX_EXPR_START; return ABRE_CHAVE; }
"}"                     { lex_ctx = LEX_CTX_EXPR_START; return FECHA_CHAVE; }
"("                     { lex_ctx = LEX_CTX_EXPR_START; return ABRE_PAREN; }
")"                     { lex_ctx = LEX_CTX_AFTER_VALUE; return FECHA_PAREN; }

"+"                     { lex_ctx = LEX_CTX_EXPR_START; return OP_MAIS; }
"-"                     { lex_ctx = LEX_CTX_EXPR_START; return OP_MENOS; }
"*"                     { lex_ctx = LEX_CTX_EXPR_START; return OP_MULT; }
"/"                     { lex_ctx = LEX_CTX_EXPR_START; return OP_DIV; }

">="                    { lex_ctx = LEX_CTX_EXPR_START; return OP_GE; }
"=="                    { lex_ctx = LEX_CTX_EXPR_START; return OP_EQ; }
"!="                    { lex_ctx = LEX_CTX_EXPR_START; return OP_NE; }
">"                     { lex_ctx = LEX_CTX_EXPR_START; return OP_MAIOR; }

[0-9]+\.[0-9]+          {
                            lex_ctx = LEX_CTX_AFTER_VALUE;
                            yylval.num_real = parse_real_literal(yytext);
                            return LIT_REAL;
                        }
[0-9]+                  {
                            lex_ctx = LEX_CTX_AFTER_VALUE;
                            yylval.num_int = parse_int_literal(yytext);
                            return LIT_INT;
                        }

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
                            fprintf(stderr, "Erro lexico na linha %d, coluna %d: simbolo desconhecido '%s'.\n",
                                    yylineno, token_column, yytext);
                            lexical_errors++;
                        }

%%
