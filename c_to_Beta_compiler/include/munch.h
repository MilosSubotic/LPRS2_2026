#ifndef MUNCH_H
#define MUNCH_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ast.h"
#include "instructions.h"

void munch_stmt(ASTNode *Node);
char* munch_expr(ASTNode *Node);
void free_InstrList(Instr *head);
char* get_reg();
char* new_label();
BetaOp get_c_op(BinOp op);
int c_op(BinOp op);
void print_instructionList(Instr *head);

#endif