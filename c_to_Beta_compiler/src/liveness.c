#include "liveness.h"
#include "munch.h"

InterferenceGraph* interference_graph = NULL;
ColorMap* color_map = NULL;

void liveness(){
    if(!instrList_head) return;

    sh_new_strdup(interference_graph);
    sh_new_strdup(color_map);

    build_cfg();
    liveness_analasis();
    resource_allocation();
}

void build_cfg(){
    LabelMap *label_map = NULL;
    Instr *curr = instrList_head;

    // find labels from dummy instr.
    while (curr != NULL) {
        if(curr->Op == JMP && curr->rb != NULL && !strcmp(curr->rb, "LABEL")){
            Instr *target = curr->next;
            while(target != NULL && target->Op == JMP && target->rb != NULL && !strcmp(target->rb, "LABEL")) {
                target = target->next;
            }
            shput(label_map, curr->ra, target);
        }
        curr = curr->next;
    }

    // find succ instr, of every instr.
    curr = instrList_head;
    while (curr != NULL) {
        curr->succ1 = NULL;
        curr->succ2 = NULL;

        // Dummy instr markers.
        if((curr->Op == JMP && curr->rb != NULL && !strcmp(curr->rb, "LABEL")) ||
            (curr->Op == ST && curr->rb != NULL && !strcmp(curr->rb, "GLOBAL_DECL"))){
            curr = curr->next;
            continue;
        }

        // no condition jump
        if(curr->Op == JMP && curr->ra != NULL && !strcmp(curr->ra, "r31")){
            if(shgeti(label_map, curr->rc) != -1){
                Instr *x = shget(label_map, curr->rc); 
                curr->succ1 = x;
            }else{
                curr->succ1 = NULL;
            }
        }
        // End of function LP
        else if(curr->Op == JMP && curr->ra != NULL && !strcmp(curr->ra, "lp")){
            curr->succ1 = NULL;
        }
        // conditional jump, only instruction with two succ
        else if(curr->Op == BEQ){
            Instr *next_real = curr->next;
            while(next_real != NULL && next_real->Op == JMP && next_real->rb != NULL && !strcmp(next_real->rb, "LABEL")){
                next_real = next_real->next;
            }
            curr->succ1 = next_real;
            if(shgeti(label_map, curr->rb) != -1){
                Instr *x = shget(label_map, curr->rb); 
                curr->succ2 = x;
            }else{
                curr->succ2 = NULL;
            }
        }
        // default instr
        else{
            Instr *next_real = curr->next;
            while(next_real != NULL && next_real->Op == JMP && next_real->rb != NULL && !strcmp(next_real->rb, "LABEL")){
                next_real = next_real->next;
            }
            curr->succ1 = next_real;
        }
        curr = curr->next;
    }

    shfree(label_map);
}

void compute_use_def(){
    Instr *curr = instrList_head;

    while(curr != NULL){
        curr->use = NULL;
        curr->def = NULL;
        curr->in = NULL;
        curr->out = NULL;

        // SKIP dummy instructions
        if((curr->Op == JMP && curr->rb != NULL && !strcmp(curr->rb, "LABEL")) ||
            (curr->Op == ST && curr->rb != NULL && !strcmp(curr->rb, "GLOBAL_DECL"))){
            curr = curr->next;
            continue;
        }

        if(curr->Op == ST){
            if(is_virtual_reg(curr->ra)) shput(curr->use, curr->ra, 0);
            if(is_virtual_reg(curr->rc)) shput(curr->use, curr->rc, 0);
            
        }else{
            if(is_virtual_reg(curr->ra)) shput(curr->use, curr->ra, 0);
            if(is_virtual_reg(curr->rb)) shput(curr->use, curr->rb, 0);
            if(is_virtual_reg(curr->rc)) shput(curr->def, curr->rc, 0);
        }

        curr = curr->next;
    }
}

int is_virtual_reg(char *reg){ 
    return (reg != NULL && reg[0] == '%' && reg[1] == 't');
}

void liveness_analasis(){
    compute_use_def();

    int done = 0;
    while(!done){
        Instr *curr =  instrList_head;
        done = 1;

        while(curr != NULL){
            // Skip dummy instructions
            if((curr->Op == JMP && curr->rb != NULL && !strcmp(curr->rb, "LABEL")) ||
                (curr->Op == ST && curr->rb != NULL && !strcmp(curr->rb, "GLOBAL_DECL"))){
                curr = curr->next;
                continue;
            }

            if(curr->succ1){
                for(int i = 0; i < hmlen(curr->succ1->in); i++){
                    if(shgeti(curr->out, curr->succ1->in[i].key) == -1){
                        shput(curr->out, curr->succ1->in[i].key, 0);
                        done = 0;
                    }
                }
            }
            if(curr->succ2){
                for(int i = 0; i < hmlen(curr->succ2->in); i++){
                    if(shgeti(curr->out, curr->succ2->in[i].key) == -1){
                        shput(curr->out, curr->succ2->in[i].key, 0);
                        done = 0;
                    }
                }
            }

            instrSet* temp = NULL;

            // Copy out[n] to temp
            for(int i = 0; i < hmlen(curr->out); i++){
                shput(temp, curr->out[i].key, 0);
            }
            // temp[n] = temp[n] \ def[n]
            for(int i = 0; i < hmlen(curr->def); i++){
                (void)hmdel(temp, curr->def[i].key);
            }
            // in[n] += use[n] 
            for(int i = 0; i < hmlen(curr->use); i++){
                if(shgeti(curr->in, curr->use[i].key) == -1){
                    shput(curr->in, curr->use[i].key, 0);
                    done = 0;
                }
            }
            // in[n] += out[n] \ def[n]
            for(int i = 0; i < hmlen(temp); i++){
                if(shgeti(curr->in, temp[i].key) == -1){
                    shput(curr->in, temp[i].key, 0);
                    done = 0;
                }
            }

            if(temp) hmfree(temp);
            
            curr = curr->next;
        }
    }
}

void resource_allocation(){
    build_interference_graph(&interference_graph);

    int num_nodes = hmlen(interference_graph);
    if (num_nodes == 0) return;

    for (int i = 0; i < num_nodes; i++) {
        char *curr_reg = interference_graph[i].key;
        RegSet *neighbors = interference_graph[i].value;

        int available_reg[MAX_REGISTERS];
        available_reg[0] = 0;   // r0 is used as return val for functions
        for(int c = 1; c < MAX_REGISTERS; c++) available_reg[c] = 1;

        for(int j = 0; j < hmlen(neighbors); j++){
            char *neighbor_reg = neighbors[j].key;
            
            int color_idx = shgeti(color_map, neighbor_reg);
            if (color_idx != -1) {
                int assigned_color = color_map[color_idx].value;
                available_reg[assigned_color] = 0;
            }
        }

        int chosen_color = 0;
        for(int c = 0; c < MAX_REGISTERS; c++){
            if (available_reg[c] == 1) {
                chosen_color = c;
                break;
            }
        }

        shput(color_map, curr_reg, chosen_color);
    }

    emplace_registers();

    for(int i = 0; i < hmlen(interference_graph); i++){
        hmfree(interference_graph[i].value);    
    }
    hmfree(interference_graph);
    hmfree(color_map);
}

void add_node(InterferenceGraph **graph, char *a){
    if(!is_virtual_reg(a)) return;
    if(shgeti(*graph, a) == -1){
        RegSet *set = NULL;
        shput(*graph, a, set);
    }
}

void add_edge(InterferenceGraph **graph, char *a, char *b){
    if(!strcmp(a, b)) return;
    if(!is_virtual_reg(a)) return;
    if(!is_virtual_reg(b)) return;

    int ia = shgeti(*graph, a);
    if(ia == -1){
        RegSet *set = NULL;
        shput(*graph, a, set);
        ia = shgeti(*graph, a);
    }

    int ib = shgeti(*graph, b);
    if(ib == -1){
        RegSet *set = NULL;
        shput(*graph, b, set);
        ib = shgeti(*graph, b);
    }

    shput((*graph)[ia].value, b, 0);
    shput((*graph)[ib].value, a, 0);
}

void build_interference_graph(InterferenceGraph **graph){
    Instr *curr = instrList_head;

    while(curr != NULL){
        // Skip dummy
        if((curr->Op == JMP && curr->rb != NULL && !strcmp(curr->rb, "LABEL")) ||
            (curr->Op == ST && curr->rb != NULL && !strcmp(curr->rb, "GLOBAL_DECL"))){
            curr = curr->next;
            continue;
        }

        // DEF interfere OUT
        for(int i = 0; i < hmlen(curr->def); i++){
            char *def_reg = curr->def[i].key;
            add_node(graph, def_reg);
            
            for(int j = 0; j < hmlen(curr->out); j++){
                char *out_reg = curr->out[j].key;
                add_edge(graph, def_reg, out_reg);
            }
        }

        // USE registers
        for(int i = 0; i < hmlen(curr->use); i++){
            add_node(graph, curr->use[i].key);
        }

        curr = curr->next;
    }
}

void emplace_registers(){
    ColorMap* map = color_map;
    Instr* curr = instrList_head;

    while(curr != NULL){
        // Skip dummy instructions
        if((curr->Op == JMP && curr->rb != NULL && !strcmp(curr->rb, "LABEL")) ||
            (curr->Op == ST && curr->rb != NULL && !strcmp(curr->rb, "GLOBAL_DECL"))){
            curr = curr->next;
            continue;
        }

        if(is_virtual_reg(curr->ra) && shgeti(map, curr->ra) != -1){
            char new_reg[15];
            int val = shget(map, curr->ra);
            char* temp = curr->ra;
            free(temp);

            sprintf(new_reg, "r%d", val);

            curr->ra = strdup(new_reg);
        }
        if(is_virtual_reg(curr->rb) && shgeti(map, curr->rb) != -1){
            char new_reg[15];
            int val = shget(map, curr->rb);
            char* temp = curr->rb;
            free(temp);

            sprintf(new_reg, "r%d", val);

            curr->rb = strdup(new_reg);
        }
        if(is_virtual_reg(curr->rc) && shgeti(map, curr->rc) != -1){
            char new_reg[15];
            int val = shget(map, curr->rc);
            char* temp = curr->rc;
            free(temp);

            sprintf(new_reg, "r%d", val);

            curr->rc = strdup(new_reg);
        }

        curr = curr->next;
    }
}