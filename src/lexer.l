%{
#include "ast.h"
#include "parser.tab.h"
#include <string.h>

void yyerror(const char *s);
%}

%option noyywrap
%option yylineno

%x MULTI_COMMENT

%%

[ \t\r]+                ; /* Ignora espacos e tabs */
\n                      ;

"%%".*                  ; /* Comentario de linha unica */

"%glu"                  { BEGIN(MULTI_COMMENT); }
<MULTI_COMMENT>"%glu"   { BEGIN(INITIAL); }
<MULTI_COMMENT>\n       ;
<MULTI_COMMENT>.        ;

"glu"                   { return GLU; }
"inteiro"   { yylval.data_type = TYPE_INTEIRO; return TIPO; }
"real"      { yylval.data_type = TYPE_REAL; return TIPO; }
"booleano"  { yylval.data_type = TYPE_BOOLEANO; return TIPO; }
"texto"     { yylval.data_type = TYPE_TEXTO; return TIPO; }

"GORGOREJA"             { return GORGOREJA; }
"CISCA"                 { return CISCA; }
"IFGLU"                 { return IFGLU; }
"WHILEGLU"              { return WHILEGLU; }
"FORGLU"                { return FORGLU; }
"STOPGLU"               { return STOPGLU; }
"PULAGLU"               { return PULAGLU; }
"CHOCA"                 { return CHOCA; }
"NINHO"                 { return NINHO; }
"RETORNAGLU"            { return RETORNAGLU; }

"true"                  { yylval.num_int = 1; return LIT_BOOL; }
"false"                 { yylval.num_int = 0; return LIT_BOOL; }

"<-"                    { return ATRIB; }
":"                     { return ':'; }
";"                     { return ';'; }
","                     { return ','; }
"{"                     { return '{'; }
"}"                     { return '}'; }
"("                     { return '('; }
")"                     { return ')'; }

"+"                     { return '+'; }
"-"                     { return '-'; }
"*"                     { return '*'; }
"/"                     { return '/'; }

"<="                    { return OP_LE; }
">="                    { return OP_GE; }
"=="                    { return OP_EQ; }
"<"                     { return '<'; }
">"                     { return '>'; }

[0-9]+\.[0-9]+          { yylval.num_real = atof(yytext); return LIT_REAL; }
[0-9]+                  { yylval.num_int = atoi(yytext); return LIT_INT; }

\<([^>\n]*)\>           { 
                            yytext[yyleng - 1] = '\0';
                            yylval.str = strdup(yytext + 1); 
                            return LIT_TEXTO; 
                        }

[a-zA-Z_][a-zA-Z0-9_]*  { yylval.str = strdup(yytext); return ID; }

.                       { printf("Erro lexico: simbolo desconhecido '%s' na linha %d\n", yytext, yylineno); }

%%