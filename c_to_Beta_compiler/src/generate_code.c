#include "generate_code.h"
#include "instructions.h"

void write_to_file(char* file){

    if(sizeof(file) > 90){
        fprintf(stderr, "File name to long!\n");
        return;
    }

    char filename[100];
    memset(filename, 0, sizeof(filename));
    strcpy(filename, file);
    strcat(filename, ".uasm");

    FILE* f;
    f = fopen(filename, "w");

    if(f == NULL){
        fprintf(stderr, "Failed to create output file!\n");
        return;
    }


    // Init
    fprintf(f, "||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||\n");
    fprintf(f, "|||      Vladimir Andrisko ra95/2023 i Mihajlo Gajic ra133/2023      |||\n");
    fprintf(f, "|||                          Beta compiler                           |||\n");
    fprintf(f, "||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||\n\n");

    fprintf(f, ".include /usr/local/share/beta/beta.uasm\n");
    fprintf(f, "BR(start)\n");


    Instr* curr = instrList_head;

    // First declare variables
    while(curr != NULL){
        if(curr->Op == ST && curr->rb != NULL && !strcmp(curr->rb, "GLOBAL_DECL")){
            fprintf(f, "%s: LONG(0)\n", curr->ra);
        }
        curr = curr->next;
    }
    fprintf(f, "\nstart:\n");

    curr = instrList_head;
    while(curr != NULL){
        if(curr->Op == ST && curr->rb != NULL && !strcmp(curr->rb, "GLOBAL_DECL")){
            curr = curr->next;
            continue;
        }

        if(curr->Op == JMP && curr->rb != NULL && !strcmp(curr->rb, "LABEL")){
            fprintf(f, "\n%s:\n", curr->ra);
        } 
        else if(curr->Op == JMP && curr->rc != NULL){
            fprintf(f, "BR(%s)\n", curr->rc);
        }
        else{
            char *print_op = printBetaOP(curr->Op);
            fprintf(f, "%s(%s, %s, %s)\n", print_op, curr->ra, curr->rb, curr->rc);
        }
        curr = curr->next;
    }
    fprintf(f, "HALT()\n");

    fclose(f);
}