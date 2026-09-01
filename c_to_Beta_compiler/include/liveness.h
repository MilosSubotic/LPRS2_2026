#ifndef LIVENESS_H
#define LIVENESS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "instructions.h"
#include "stb_ds.h"

typedef struct{
    char* key;              // label name
    Instr *value;
}LabelMap;

typedef struct{
    char* key;
    int value;
}RegSet;

typedef struct{
    char* key;
    RegSet* value;
}InterferenceGraph;

typedef struct{
    char* key;
    int value;
}ColorMap;

void build_cfg();
void liveness_analasis();
void liveness();
void resource_allocation();
void compute_use_def();
int is_virtual_reg(char *reg);
void add_edge(InterferenceGraph **graph, char *a, char *b);
void build_interference_graph(InterferenceGraph **graph);
void emplace_registers();

#endif