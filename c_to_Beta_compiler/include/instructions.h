#ifndef INSTRUCTIONS_H
#define INSTRUCTIONS_H

#include <stdio.h>
#include "stb_ds.h"

#define MAX_REGISTERS 27

typedef enum{
    ADD, ADDC, AND, ANDC, BEQ, BNE, CMPEQ, CMPEQC, CMPLE,
    CMPLEC, CMPLT, CMPLTC, DIV, DIVC, JMP, LD, LDR, MUL,
    MULC, OR, ORC, SHL, SHLC, SHR, SHRC, SRA, SRAC,
    SUB, SUBC, ST, XOR, XORC, XNOR, XNORC
}BetaOp;

typedef struct instrSet{
    char* key;
    int value;
}instrSet;

typedef struct Instr{
    BetaOp Op;

    char *ra;
    char *rb;
    char *rc;
    
    struct Instr *next;
    
    struct Instr *succ1;
    struct Instr *succ2;

    instrSet *use;
    instrSet *def;
    instrSet *in;
    instrSet *out;
}Instr;

extern Instr *instrList_head;
extern Instr *instrList_tail;

static inline char* printBetaOP(BetaOp op){
    char *s;

    switch(op){
        case ADD: s = "ADD"; break;
        case ADDC: s = "ADDC"; break;
        case AND: s = "AND"; break;
        case ANDC: s = "ANDC"; break;
        case BEQ: s = "BEQ"; break;
        case BNE: s = "BNE"; break;
        case CMPEQ: s = "CMPEQ"; break;
        case CMPEQC: s = "CMPEQC"; break;
        case CMPLE: s = "CMPLE"; break;
        case CMPLEC: s = "CMPLEC"; break;
        case CMPLT: s = "CMPLT"; break;
        case CMPLTC: s = "CMPLTC"; break;
        case DIV: s = "DIV"; break;
        case DIVC: s = "DIVC"; break;
        case JMP: s = "JMP"; break;
        case LD: s = "LD"; break;
        case LDR: s = "LDR"; break;
        case MUL: s = "MUL"; break;
        case MULC: s = "MULC"; break;
        case OR: s = "OR"; break;
        case ORC: s = "ORC"; break;
        case SHL: s = "SHL"; break;
        case SHLC: s = "SHLC"; break;
        case SHR: s = "SHR"; break;
        case SHRC: s = "SHRC"; break;
        case SRA: s = "SRA"; break;
        case SRAC: s = "SRAC"; break;
        case SUB: s = "SUB"; break;
        case SUBC: s = "SUBC"; break;
        case ST: s = "ST"; break;
        case XOR: s = "XOR"; break;
        case XORC: s = "XORC"; break;
        case XNOR: s = "XNOR"; break;
        case XNORC: s = "XNORC"; break;
        
        default: break;
    }

    return s;
}

#endif