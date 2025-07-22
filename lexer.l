%{
/* Lexer Ds9 XV  */
#include "scanner.tab.h"
#include <string.h>
#include <stdlib.h>
%}

%option noyywrap

DIGITO      [0-9]
ID          [a-zA-Z_][a-zA-Z0-9_]*
NUM         {DIGITO}+
REAL        ([0-9]*[.][0-9]+)|([0-9]+[.][0-9]*)
STRING      \"([^\\\"]|\\.)*\"

%%

(?i:if)         { return IF; }
(?i:elif)       { return ELIF; }
(?i:else)       { return ELSE; }

(?i:def)        { return DEF; }
(?i:print)      { return PRINT; }

"="             { return ASSIGN; }
"("             { return LPAREN; }
")"             { return RPAREN; }
"{"             { return LBRACE; }
"}"             { return RBRACE; }
":"             { return COLON; }

"=="            { return IGUAL; }
"!="            { return DIFERENTE; }
">="            { return MAYORIGUAL; }
"<="            { return MENORIGUAL; }
">"             { return MAYOR; }
"<"             { return MENOR; }

"+"             { return PLUS; }
"-"             { return MINUS; }
"*"             { return MUL; }
"/"             { return DIV; }

{STRING}        {
                    yytext[yyleng - 1] = '\0';
                    yylval.sval = strdup(yytext + 1);
                    return STRING;
                }

{REAL}          { yylval.fval = atof(yytext); return REAL; }
{NUM}           { yylval.ival = atoi(yytext); return INT; }
{ID}            { yylval.sval = strdup(yytext); return ID; }

"#".*           ;        
"//".*          ;       
[\t ]+          ;        
\r?\n           { return NEWLINE; }

.               { printf("  Caracter desconocido: '%c'\n", yytext[0]); }

%%
