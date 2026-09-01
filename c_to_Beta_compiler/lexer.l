%option noinput nounput

%{
#include "parser.tab.h"
#include <stdlib.h>
#include <string.h>
%}

DIGIT   [0-9]
ID      [a-zA-Z_][a-zA-Z0-9_]*

%%

"int"       { return INT; }
"if"        { return IF; }
"else"      { return ELSE; }
"while"     { return WHILE; }
"for"       { return FOR; }
"return"    { return RETURN; }

"=="        { return EQ; }
"!="        { return NE; }
"<="        { return LE; }
">="        { return GE; }

"="         { return '='; }
"<"         { return '<'; }
">"         { return '>'; }
"+"         { return '+'; }
"-"         { return '-'; }
"*"         { return '*'; }
"/"         { return '/'; }

";"         { return ';'; }
","         { return ','; }
"("         { return '('; }
")"         { return ')'; }
"{"         { return '{'; }
"}"         { return '}'; }

{DIGIT}+    {
                yylval.ival = atoi(yytext);
                return INTEGER;
            }

{ID}        {
                yylval.sval = strdup(yytext);
                return IDENTIFIER;
            }

[ \t\r]+    ;

\n          { yylineno++; }

"//".*      ;

.           {
                fprintf(stderr,
                        "Unknown char %s at line %d\n",
                        yytext,
                        yylineno);
            }

%%

int yywrap(void)
{
    return 1;
}