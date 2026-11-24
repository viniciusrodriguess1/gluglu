#ifndef LEXER_H
#define LEXER_H

#include <stdio.h>

extern int yylineno;
extern int token_column;
extern int lexical_errors;
extern FILE *yyin;

int yylex(void);
int yylex_destroy(void);
const char *lexer_token_name(int token);

#endif
