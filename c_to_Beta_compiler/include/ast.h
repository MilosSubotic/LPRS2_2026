#ifndef AST_H
#define AST_H

#include <stdio.h>

typedef enum {
    AST_BLOCK,

    AST_DECL,
    AST_ASSIGN,

    AST_IF,
    AST_WHILE,
    AST_FOR,

    AST_RETURN,

    AST_BINOP,

    AST_IDENT,
    AST_INT
} ASTNodeType;

typedef enum {
    OP_ADD,
    OP_SUB,
    OP_MUL,
    OP_DIV,

    OP_LT,
    OP_LE,
    OP_GT,
    OP_GE,

    OP_EQ,
    OP_NE
} BinOp;

typedef struct ASTNode ASTNode;

struct ASTNode {
    ASTNodeType type;

    union {
        struct {
            ASTNode *children;
        } block;

        struct {
            char *name;
        } decl;

        struct {
            char *name;
            ASTNode *expr;
        } assign;

        struct {
            ASTNode *cond;
            ASTNode *then_branch;
            ASTNode *else_branch;
        } if_stmt;
        
        struct {
            ASTNode *cond;
            ASTNode *body;
        } while_stmt;

        struct {
            ASTNode *init;
            ASTNode *cond;
            ASTNode *update;
            ASTNode *body;
        } for_stmt;

        struct {
            ASTNode *expr;
        } return_stmt;

        struct {
            BinOp op;
            ASTNode *left;
            ASTNode *right;
        } binop;

        struct {
            char *name;
        } ident;

        struct {
            int value;
        } integer;

    } data;

    ASTNode *next;
};


ASTNode *ast_make_block(ASTNode *children);
ASTNode *ast_make_decl(char *name);
ASTNode *ast_make_assign(char *name, ASTNode *expr);
ASTNode *ast_make_if(ASTNode *cond, ASTNode *then_branch, ASTNode *else_branch);

ASTNode *ast_make_while(ASTNode *cond, ASTNode *body);
ASTNode *ast_make_for(ASTNode *init, ASTNode *cond, ASTNode *update, ASTNode *body);
ASTNode *ast_make_return(ASTNode *expr);
ASTNode *ast_make_binop(BinOp op, ASTNode *left, ASTNode *right);
ASTNode *ast_make_ident(char *name);
ASTNode *ast_make_int(int value);
ASTNode *ast_append(ASTNode *list, ASTNode *node);

void ast_print(ASTNode *node, int indent);
void ast_free(ASTNode *node);

#endif
