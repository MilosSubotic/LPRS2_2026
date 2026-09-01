#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ast.h"

static ASTNode *new_node(ASTNodeType type)
{
    ASTNode *n = calloc(1, sizeof(ASTNode));

    if (!n) {
        fprintf(stderr, "out of memory\n");
        exit(EXIT_FAILURE);
    }

    n->type = type;
    n->next = NULL;

    return n;
}

ASTNode *ast_make_block(ASTNode *children)
{
    ASTNode *n = new_node(AST_BLOCK);
    n->data.block.children = children;
    return n;
}

ASTNode *ast_make_decl(char *name)
{
    ASTNode *n = new_node(AST_DECL);
    n->data.decl.name = strdup(name);
    return n;
}

ASTNode *ast_make_assign(char *name,
                         ASTNode *expr)
{
    ASTNode *n = new_node(AST_ASSIGN);

    n->data.assign.name = strdup(name);
    n->data.assign.expr = expr;

    return n;
}

ASTNode *ast_make_if(ASTNode *cond,
                     ASTNode *then_branch,
                     ASTNode *else_branch)
{
    ASTNode *n = new_node(AST_IF);

    n->data.if_stmt.cond = cond;
    n->data.if_stmt.then_branch = then_branch;
    n->data.if_stmt.else_branch = else_branch;

    return n;
}

ASTNode *ast_make_while(ASTNode *cond,
                        ASTNode *body)
{
    ASTNode *n = new_node(AST_WHILE);

    n->data.while_stmt.cond = cond;
    n->data.while_stmt.body = body;

    return n;
}

ASTNode *ast_make_for(ASTNode *init,
                      ASTNode *cond,
                      ASTNode *update,
                      ASTNode *body)
{
    ASTNode *n = new_node(AST_FOR);

    n->data.for_stmt.init = init;
    n->data.for_stmt.cond = cond;
    n->data.for_stmt.update = update;
    n->data.for_stmt.body = body;

    return n;
}

ASTNode *ast_make_return(ASTNode *expr)
{
    ASTNode *n = new_node(AST_RETURN);

    n->data.return_stmt.expr = expr;

    return n;
}

ASTNode *ast_make_binop(BinOp op,
                        ASTNode *left,
                        ASTNode *right)
{
    ASTNode *n = new_node(AST_BINOP);

    n->data.binop.op = op;
    n->data.binop.left = left;
    n->data.binop.right = right;

    return n;
}

ASTNode *ast_make_ident(char *name)
{
    ASTNode *n = new_node(AST_IDENT);

    n->data.ident.name = strdup(name);

    return n;
}

ASTNode *ast_make_int(int value)
{
    ASTNode *n = new_node(AST_INT);

    n->data.integer.value = value;

    return n;
}

ASTNode *ast_append(ASTNode *list,
                    ASTNode *node)
{
    ASTNode *p;

    if (!list)
        return node;

    p = list;

    while (p->next)
        p = p->next;

    p->next = node;

    return list;
}

static void print_indent(int level){
    int i;

    for (i = 0; i < level; i++)
        printf("  ");
}

static const char *op_name(BinOp op){
    switch (op) {
        case OP_ADD: return "+";
        case OP_SUB: return "-";
        case OP_MUL: return "*";
        case OP_DIV: return "/";

        case OP_LT: return "<";
        case OP_LE: return "<=";
        case OP_GT: return ">";
        case OP_GE: return ">=";

        case OP_EQ: return "==";
        case OP_NE: return "!=";
    }

    return "?";
}

void ast_print(ASTNode *node, int indent){
    while (node) {

        print_indent(indent);

        switch (node->type) {

        case AST_BLOCK:
            printf("BLOCK\n");
            ast_print(node->data.block.children,
                      indent + 1);
            break;

        case AST_DECL:
            printf("DECL %s\n",
                   node->data.decl.name);
            break;

        case AST_ASSIGN:
            printf("ASSIGN %s\n",
                   node->data.assign.name);

            ast_print(node->data.assign.expr,
                      indent + 1);
            break;

        case AST_IF:
            printf("IF\n");

            print_indent(indent + 1);
            printf("COND\n");

            ast_print(node->data.if_stmt.cond,
                      indent + 2);

            print_indent(indent + 1);
            printf("THEN\n");

            ast_print(node->data.if_stmt.then_branch,
                      indent + 2);

            if (node->data.if_stmt.else_branch) {

                print_indent(indent + 1);
                printf("ELSE\n");

                ast_print(node->data.if_stmt.else_branch,
                          indent + 2);
            }

            break;

        case AST_WHILE:
            printf("WHILE\n");

            print_indent(indent + 1);
            printf("COND\n");

            ast_print(node->data.while_stmt.cond,
                      indent + 2);

            print_indent(indent + 1);
            printf("BODY\n");

            ast_print(node->data.while_stmt.body,
                      indent + 2);

            break;

        case AST_FOR:
            printf("FOR\n");

            print_indent(indent + 1);
            printf("INIT\n");

            ast_print(node->data.for_stmt.init,
                      indent + 2);

            print_indent(indent + 1);
            printf("COND\n");

            ast_print(node->data.for_stmt.cond,
                      indent + 2);

            print_indent(indent + 1);
            printf("UPDATE\n");

            ast_print(node->data.for_stmt.update,
                      indent + 2);

            print_indent(indent + 1);
            printf("BODY\n");

            ast_print(node->data.for_stmt.body,
                      indent + 2);

            break;

        case AST_RETURN:
            printf("RETURN\n");

            ast_print(node->data.return_stmt.expr,
                      indent + 1);
            break;

        case AST_BINOP:
            printf("BINOP %s\n",
                   op_name(node->data.binop.op));

            ast_print(node->data.binop.left,
                      indent + 1);

            ast_print(node->data.binop.right,
                      indent + 1);

            break;

        case AST_IDENT:
            printf("IDENT %s\n",
                   node->data.ident.name);
            break;

        case AST_INT:
            printf("INT %d\n",
                   node->data.integer.value);
            break;
        }

        node = node->next;
    }
}

void ast_free(ASTNode *node){
    ASTNode *next;

    while (node) {

        next = node->next;

        switch (node->type) {

        case AST_BLOCK:
            ast_free(node->data.block.children);
            break;

        case AST_ASSIGN:
            free(node->data.assign.name);
            ast_free(node->data.assign.expr);
            break;

        case AST_DECL:
            free(node->data.decl.name);
            break;

        case AST_IF:
            ast_free(node->data.if_stmt.cond);
            ast_free(node->data.if_stmt.then_branch);
            ast_free(node->data.if_stmt.else_branch);
            break;

        case AST_WHILE:
            ast_free(node->data.while_stmt.cond);
            ast_free(node->data.while_stmt.body);
            break;

        case AST_FOR:
            ast_free(node->data.for_stmt.init);
            ast_free(node->data.for_stmt.cond);
            ast_free(node->data.for_stmt.update);
            ast_free(node->data.for_stmt.body);
            break;

        case AST_RETURN:
            ast_free(node->data.return_stmt.expr);
            break;

        case AST_BINOP:
            ast_free(node->data.binop.left);
            ast_free(node->data.binop.right);
            break;

        case AST_IDENT:
            free(node->data.ident.name);
            break;

        case AST_INT:
            break;
        }

        free(node);

        node = next;
    }
}
