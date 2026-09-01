#include <stdio.h>
#include <stdlib.h>

#include "ast.h"
#include "munch.h"
#include "instructions.h"
#include "liveness.h"
#include "generate_code.h"

extern int yyparse(void);
extern FILE *yyin;
extern ASTNode *root;

Instr *instrList_head = NULL;
Instr *instrList_tail = NULL;

void ast_print(ASTNode *node, int indent);
void ast_free(ASTNode *node);

int main(int argc, char **argv){
    char *input_file = NULL;
    char *output_file = "a";

    for(int i = 1; i < argc; i++){
        if(!strcmp(argv[i], "-o")){
            if(i + 1 < argc){
                output_file = argv[i+1];
            }else{
                fprintf(stderr, "Error: option -o requires output file name.\n");
                return 1;
            }
        }else{
            input_file = argv[i];
        }
    }

    if(input_file == NULL){
        fprintf(stderr, "USE: %s <input_file> [-o <output_file>]\n", argv[0]);
        return 1;
    }

    FILE *input;
    input = fopen(argv[1], "r");

    if(!input){
        fprintf(stderr, "Cannot open file %s\n", argv[1]);
        return 1;
    }

    yyin = input;

    if(yyparse() != 0){
        fprintf(stderr, "Error: Parsing failed\n");
        fclose(input);
        return 1;
    }

    if(root == NULL){
        printf("Error: Empty program\n");
        fclose(input);
        return 1;
    }

    munch_stmt(root);

    if(instrList_head == NULL){
        printf("Error: Munch failed!\n");
        ast_free(root);
        fclose(input);
        return 1;
    }

    liveness();
    write_to_file(output_file);

    if(instrList_head != NULL){
        free_InstrList(instrList_head);
    }

    ast_free(root);
    fclose(input);

    return 0;
}
