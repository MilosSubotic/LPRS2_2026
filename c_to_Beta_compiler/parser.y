%{
#include <stdio.h>
#include <stdlib.h>
#include "ast.h"

extern int yylex(void);
extern int yylineno;
extern FILE *yyin;

void yyerror(const char *msg);

ASTNode *root = NULL;
%}

%code requires {
    #include "ast.h"
}

%union {
    int      ival;
    char    *sval;
    ASTNode *node;
}

%token INT
%token IF
%token ELSE
%token WHILE
%token FOR
%token RETURN

%token EQ
%token NE
%token LE
%token GE

%token <sval> IDENTIFIER
%token <ival> INTEGER


%type <node> program
%type <node> block

%type <node> stmt_list
%type <node> stmt

%type <node> declaration

%type <node> assignment
%type <node> assignment_stmt

%type <node> if_stmt
%type <node> while_stmt
%type <node> for_stmt
%type <node> return_stmt

%type <node> expr

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%left EQ NE
%left '<' '>' LE GE

%left '+' '-'
%left '*' '/'

%%

program
    : block
      {
          root = $1;
          $$ = $1;
      }
    ;


block
    : '{' stmt_list '}'
      {
          $$ = ast_make_block($2);
      }
    ;

stmt_list
    : stmt_list stmt
      {
          $$ = ast_append($1, $2);
      }
    | stmt
      {
          $$ = $1;
      }
    | 
      {
          $$ = NULL;
      }
    ;

stmt
    : declaration
      {
          $$ = $1;
      }

    | assignment_stmt
      {
          $$ = $1;
      }

    | if_stmt
      {
          $$ = $1;
      }

    | while_stmt
      {
          $$ = $1;
      }

    | for_stmt
      {
          $$ = $1;
      }

    | return_stmt
      {
          $$ = $1;
      }

    | block
      {
          $$ = $1;
      }
    ;

declaration
    : INT IDENTIFIER ';'
      {
          $$ = ast_make_decl($2);
          free($2);
      }
    ;

assignment_stmt
    : assignment ';'
      {
          $$ = $1;
      }
    ;

assignment
    : IDENTIFIER '=' expr
      {
          $$ = ast_make_assign($1, $3);
          free($1);
      }
    ;

if_stmt
    : IF '(' expr ')' stmt %prec LOWER_THAN_ELSE
      {
          $$ = ast_make_if(
                  $3,
                  $5,
                  NULL);
      }

    | IF '(' expr ')' stmt ELSE stmt
      {
          $$ = ast_make_if(
                  $3,
                  $5,
                  $7);
      }
    ;

while_stmt
    : WHILE '(' expr ')' stmt
      {
          $$ = ast_make_while(
                  $3,
                  $5);
      }
    ;

for_stmt
    : FOR '(' assignment ';' expr ';' assignment ')' stmt
      {
          $$ = ast_make_for(
                  $3,
                  $5,
                  $7,
                  $9);
      }
    ;

return_stmt
    : RETURN expr ';'
      {
          $$ = ast_make_return($2);
      }
    ;

expr
    : expr '+' expr
      {
          $$ = ast_make_binop(
                  OP_ADD,
                  $1,
                  $3);
      }

    | expr '-' expr
      {
          $$ = ast_make_binop(
                  OP_SUB,
                  $1,
                  $3);
      }

    | expr '*' expr
      {
          $$ = ast_make_binop(
                  OP_MUL,
                  $1,
                  $3);
      }

    | expr '/' expr
      {
          $$ = ast_make_binop(
                  OP_DIV,
                  $1,
                  $3);
      }

    | expr '<' expr
      {
          $$ = ast_make_binop(
                  OP_LT,
                  $1,
                  $3);
      }

    | expr '>' expr
      {
          $$ = ast_make_binop(
                  OP_GT,
                  $1,
                  $3);
      }

    | expr LE expr
      {
          $$ = ast_make_binop(
                  OP_LE,
                  $1,
                  $3);
      }

    | expr GE expr
      {
          $$ = ast_make_binop(
                  OP_GE,
                  $1,
                  $3);
      }

    | expr EQ expr
      {
          $$ = ast_make_binop(
                  OP_EQ,
                  $1,
                  $3);
      }

    | expr NE expr
      {
          $$ = ast_make_binop(
                  OP_NE,
                  $1,
                  $3);
      }

    | '(' expr ')'
      {
          $$ = $2;
      }

    | IDENTIFIER
      {
          $$ = ast_make_ident($1);
          free($1);
      }

    | INTEGER
      {
          $$ = ast_make_int($1);
      }
    ;

%%

void yyerror(const char *msg)
{
    fprintf(stderr,
            "Parse error at line %d: %s\n",
            yylineno,
            msg);
}
