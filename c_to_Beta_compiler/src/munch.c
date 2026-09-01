#include "munch.h"

static unsigned int register_count = 0;
static int label_count = 0;

char* get_reg(){
    char* regist = malloc(12*sizeof(char));
    if(regist == NULL){
        fprintf(stderr, "Not enough space for registers!\n");
        return NULL;
    }

    sprintf(regist, "%%t%u", register_count);
    register_count++;
    return regist;
}

char* new_label(){
    char *lbl = malloc(13*sizeof(char));

    if(lbl == NULL){
        fprintf(stderr, "Not enough space for labels!\n");
        return NULL;
    }

    sprintf(lbl, "L%d", label_count++);
    return lbl;
}

void emit(BetaOp op, char *ra, char *rb, char *rc) {
    Instr *new_instr = malloc(sizeof(Instr));
    new_instr->Op = op;
    new_instr->ra = ra ? strdup(ra) : NULL;
    new_instr->rb = rb ? strdup(rb) : NULL;
    new_instr->rc = rc ? strdup(rc) : NULL;
    new_instr->next = NULL;

    new_instr->use = NULL;
    new_instr->def = NULL;
    new_instr->in = NULL;
    new_instr->out = NULL;

    if (!instrList_head) {
        instrList_head = new_instr;
        instrList_tail = new_instr;
    } else {
        instrList_tail->next = new_instr;
        instrList_tail = new_instr;
    }
}

void munch_stmt(ASTNode *Node){
    if (!Node) return;

    switch(Node->type){
        case AST_BLOCK: {
            munch_stmt(Node->data.block.children);
            break;
        }

        case AST_ASSIGN: {
            char* reg = munch_expr(Node->data.assign.expr);
            emit(ST, reg, Node->data.assign.name, "r31");
            free(reg);
            break;
        }

        case AST_DECL: {
            emit(ST, Node->data.decl.name, "GLOBAL_DECL", NULL);
            break;
        }

        case AST_IF: {
            char *else_lbl = new_label();
            char *end_lbl = new_label();

            char *cond_reg = munch_expr(Node->data.if_stmt.cond);
            emit(BEQ, cond_reg, else_lbl, "r31");
            munch_stmt(Node->data.if_stmt.then_branch);
            emit(JMP, "r31", "r31", end_lbl);

            emit(JMP, else_lbl, "LABEL", NULL);
            if (Node->data.if_stmt.else_branch) {
                munch_stmt(Node->data.if_stmt.else_branch);
            }
            emit(JMP, end_lbl, "LABEL", NULL);

            free(else_lbl); free(end_lbl); free(cond_reg);
            break;
        }

        case AST_WHILE: {
            char *start_lbl = new_label();
            char *end_lbl = new_label();

            emit(JMP, start_lbl, "LABEL", NULL);

            char *cond_reg = munch_expr(Node->data.while_stmt.cond);
            emit(BEQ, cond_reg, end_lbl, "r31");
            munch_stmt(Node->data.while_stmt.body);

            emit(JMP, "r31", "r31", start_lbl);
            emit(JMP, end_lbl, "LABEL", NULL);

            free(cond_reg); free(start_lbl); free(end_lbl);
            break;
        }

        case AST_FOR: {
            char *start_lbl = new_label();
            char *end_lbl = new_label();

            if(Node->data.for_stmt.init){
                munch_stmt(Node->data.for_stmt.init);
            }

            emit(JMP, start_lbl, "LABEL", NULL);

            if(Node->data.for_stmt.cond){
                char *cond_reg = munch_expr(Node->data.for_stmt.cond);
                emit(BEQ, cond_reg, end_lbl, "r31");
                free(cond_reg);
            }

            if(Node->data.for_stmt.body){
                munch_stmt(Node->data.for_stmt.body);
            }

            if(Node->data.for_stmt.update){
                munch_stmt(Node->data.for_stmt.update);
            }

            emit(JMP, "r31", "r31", start_lbl);
            emit(JMP, end_lbl, "LABEL", NULL);

            free(start_lbl); free(end_lbl);
            break;
        }

        case AST_RETURN: {
            if(Node->data.return_stmt.expr){
                char *res_reg = munch_expr(Node->data.return_stmt.expr);
                
                emit(ADD, res_reg, "r31", "r0");
                free(res_reg);
            }
            break;
        }

        default: return;
    }

    if(Node->next) munch_stmt(Node->next);
}

char* munch_expr(ASTNode *Node){
    if(!Node) return NULL;

    switch (Node->type){
        case AST_INT: {
            char* reg = get_reg();
            char* val = malloc(16*sizeof(char));
            sprintf(val, "%d", Node->data.integer.value);
            emit(ADDC, "r31", val, reg);
            free(val);
            return reg;
            break;
        }
        case AST_BINOP: {
            if(Node->data.binop.right->type == AST_INT && c_op(Node->data.binop.op)){
                char *left_reg = munch_expr(Node->data.binop.left);
                char *reg_c = get_reg();
                char val_str[16];
                sprintf(val_str, "%d", Node->data.binop.right->data.integer.value);

                emit(get_c_op(Node->data.binop.op), left_reg, val_str, reg_c);

                free(left_reg);
                return reg_c;
            }
            if(Node->data.binop.left->type == AST_INT && c_op(Node->data.binop.op)){
                char *right_reg = munch_expr(Node->data.binop.right);
                char *reg_c = get_reg();
                char val_str[16];
                sprintf(val_str, "%d", Node->data.binop.left->data.integer.value);

                emit(get_c_op(Node->data.binop.op), val_str, right_reg, reg_c);

                free(right_reg);
                return reg_c;
            }

            char *left_reg = munch_expr(Node->data.binop.left);
            char *right_reg = munch_expr(Node->data.binop.right);
            char *reg_c = get_reg();
            int rotiraj = 0;

            BetaOp op;
            switch(Node->data.binop.op){
                case OP_ADD: op = ADD; break;
                case OP_SUB: op = SUB; break;
                case OP_MUL: op = MUL; break;
                case OP_DIV: op = DIV; break;
                case OP_EQ:  op = CMPEQ; break;
                case OP_LT:  op = CMPLT; break;
                case OP_LE:  op = CMPLE; break;
                case OP_GT:  op = CMPLT; rotiraj = 1; break;
                case OP_GE:  op = CMPLE; rotiraj = 1; break;
                default: break;
            }

            if (rotiraj) emit(op, right_reg, left_reg, reg_c);
            else emit(op, left_reg, right_reg, reg_c);

            free(left_reg); free(right_reg);
            return reg_c;
        }
        case AST_IDENT:{
            char* reg = get_reg();
            emit(LD, "r31", Node->data.ident.name, reg);
            return reg;
            break;
        }

        default:
            return NULL;
            break;
    }

    return NULL;
}


void free_InstrList(Instr *head){
    Instr *curr = head;
    
    while(curr != NULL){
        Instr *next_instr = curr->next;
        
        if(curr->ra != NULL) free(curr->ra);
        if(curr->rb != NULL) free(curr->rb);
        if(curr->rc != NULL) free(curr->rc);

        if(curr->use != NULL) shfree(curr->use);
        if(curr->def != NULL) shfree(curr->def);
        if(curr->in != NULL) shfree(curr->in);
        if(curr->out != NULL) shfree(curr->out);
        
        free(curr);
        curr = next_instr;
    }
}

int c_op(BinOp op){
    return (op != OP_GT && op != OP_GE && op != OP_NE);
}

BetaOp get_c_op(BinOp op){
    switch(op) {
        case OP_ADD: return ADDC; case OP_SUB: return SUBC;
        case OP_MUL: return MULC; case OP_DIV: return DIVC;
        case OP_LT:  return CMPLTC; case OP_LE: return CMPLEC;
        case OP_EQ:  return CMPEQC;
        default: return ADD;
    }
}

void print_instructionList(Instr *head){
    if(!head) return;

    Instr *curr = head;

    while(curr != NULL){
        BetaOp op = curr->Op;
        char* ra = curr->ra;
        char* rb = curr->rb;
        char* rc = curr->rc;
        char* op_print = printBetaOP(op);

        printf("%s(%s, %s, %s)\n", op_print, ra, rb, rc);

        // if(curr->succ1){
        //     printf("SUCC1:      ");
        //     BetaOp op = curr->succ1->Op;
        //     char* ra = curr->succ1->ra;
        //     char* rb = curr->succ1->rb;
        //     char* rc = curr->succ1->rc;
        //     char* op_print = printBetaOP(op);

        //     printf("%s(%s, %s, %s)\n", op_print, ra, rb, rc);
        // }

        // if(curr->succ2){
        //     printf("SUCC2:      ");
        //     BetaOp op = curr->succ2->Op;
        //     char* ra = curr->succ2->ra;
        //     char* rb = curr->succ2->rb;
        //     char* rc = curr->succ2->rc;
        //     char* op_print = printBetaOP(op);

        //     printf("%s(%s, %s, %s)\n", op_print, ra, rb, rc);
        // }

        // printf("USE: ");
        // for(int i = 0; i < hmlen(curr->use); i++){
        //     printf("%s, ", curr->use[i].key);
        // }
        // printf("\n");

        // printf("DEF: ");
        // for(int i = 0; i < hmlen(curr->def); i++){
        //     printf("%s, ", curr->def[i].key);
        // }
        // printf("\n");

        // printf("IN: ");
        // for(int i = 0; i < hmlen(curr->in); i++){
        //     printf("%s, ", curr->in[i].key);
        // }
        // printf("\n");

        // printf("OUT: ");
        // for(int i = 0; i < hmlen(curr->out); i++){
        //     printf("%s, ", curr->out[i].key);
        // }
        // printf("\n");

        curr = curr->next;
    }
}