%{
#include "symtab.h"
#include "ast.h"
#include "parser.tab.h"
#include <string.h>

void yyerror(const char *s);
extern int lexical_errors;
static int can_be_relop = 0;
%}

%option noyywrap
%option yylineno
%option nounput
%option noinput

%x MULTI_COMMENT

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

"glu"                   { can_be_relop = 0; return GLU; }
"inteiro"               { can_be_relop = 0; yylval.data_type = TYPE_INTEIRO; return TIPO; }
"real"                  { can_be_relop = 0; yylval.data_type = TYPE_REAL; return TIPO; }
"booleano"              { can_be_relop = 0; yylval.data_type = TYPE_BOOLEANO; return TIPO; }
"texto"                 { can_be_relop = 0; yylval.data_type = TYPE_TEXTO; return TIPO; }

"GORGOREJA"             { can_be_relop = 0; return GORGOREJA; }
"CISCA"                 { can_be_relop = 0; return CISCA; }
"IFGLU"                 { can_be_relop = 0; return IFGLU; }
"ELSEGLU"               { can_be_relop = 0; return ELSEGLU; }
"WHILEGLU"              { can_be_relop = 0; return WHILEGLU; }
"FORGLU"                { can_be_relop = 0; return FORGLU; }
"STOPGLU"               { can_be_relop = 0; return STOPGLU; }
"PULAGLU"               { can_be_relop = 0; return PULAGLU; }
"CHOCA"                 { can_be_relop = 0; return CHOCA; }
"NINHO"                 { can_be_relop = 0; return NINHO; }
"RETORNAGLU"            { can_be_relop = 0; return RETORNAGLU; }

"And"|"and"             { can_be_relop = 0; return OP_AND; }
"or"|"OR"               { can_be_relop = 0; return OP_OR; }
"not"|"NOT"             { can_be_relop = 0; return OP_NOT; }

"true"                  { can_be_relop = 1; yylval.num_int = 1; return LIT_BOOL; }
"false"                 { can_be_relop = 1; yylval.num_int = 0; return LIT_BOOL; }

"<-"/[ \t\r\n]*\<([^>\n]*)\> {
                            can_be_relop = 0;
                            return ATRIB;
                        }
"<-"                    { can_be_relop = 0; return ATRIB; }
":"                     { can_be_relop = 0; return ':'; }
";"                     { can_be_relop = 0; return ';'; }
","                     { can_be_relop = 0; return ','; }
"{"                     { can_be_relop = 0; return '{'; }
"}"                     { can_be_relop = 0; return '}'; }
"("                     { can_be_relop = 0; return '('; }
")"                     { can_be_relop = 1; return ')'; }

"+"                     { can_be_relop = 0; return '+'; }
"-"                     { can_be_relop = 0; return '-'; }
"*"                     { can_be_relop = 0; return '*'; }
"/"                     { can_be_relop = 0; return '/'; }

"<="                    { can_be_relop = 0; return OP_LE; }
">="                    { can_be_relop = 0; return OP_GE; }
"=="                    { can_be_relop = 0; return OP_EQ; }
"!="                    { can_be_relop = 0; return OP_NE; }
"<"                     { can_be_relop = 0; return '<'; }
">"                     { can_be_relop = 0; return '>'; }

[0-9]+\.[0-9]+          { can_be_relop = 1; yylval.num_real = atof(yytext); return LIT_REAL; }
[0-9]+                  { can_be_relop = 1; yylval.num_int = atoi(yytext); return LIT_INT; }

\<([^>\n]*)\>           {
                            if (can_be_relop) {
                                yyless(1);
                                can_be_relop = 0;
                                return '<';
                            }
                            yytext[yyleng - 1] = '\0';
                            yylval.str = strdup(yytext + 1);
                            can_be_relop = 1;
                            return LIT_TEXTO;
                        }

[a-zA-Z_][a-zA-Z0-9_]*  { can_be_relop = 1; yylval.str = strdup(yytext); return ID; }

.                       {
                            fprintf(stderr, "Erro lexico na linha %d: simbolo desconhecido '%s'.\n", yylineno, yytext);
                            lexical_errors++;
                        }

%%
