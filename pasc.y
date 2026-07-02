//Χρησιμοποιούμε %code requires: για πράγματα που πρέπει να γνωρίζει ο compiler πριν από τον parser, στα headers
//Είναι απαραίτητο για να μπορεί να γίνει compile κώδικας που χρησιμοποιεί τους τύπους/συναρτήσεις του parser
%code requires {
    #include "helpers.h"
}

%{
    #include "helpers.h"
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    Symbol symbolTableStack[MAX_NESTING_DEPTH][MAX_SYMBOLS];
    int symbolCountStack[MAX_NESTING_DEPTH];
    int current_nesting_level = 0;
    //Η currently_parsing_function_name αφορά τον parser(αναλυτή κώδικα),και χρησιμοποιείται
    //για να κρατά προσωρινά το όνομα της συνάρτησης που αναλύεται εκείνη τη στιγμή
    char* currently_parsing_function_name = NULL;
    extern int yylineno;
    extern FILE *yyin;
    extern char *yytext;
    char *input_filename = "stdin";

    void yyerror(const char *s);
    int yylex(void);

    // ΚΑΘΟΛΙΚΕΣ ΜΕΤΑΒΛΗΤΕΣ ΓΙΑ ΤΗ ΔΙΑΧΕΙΡΙΣΗ ΤΩΝ ΠΡΑΓΜΑΤΙΚΩΝ ΟΡΙΣΜΑΤΩΝ ΚΑΤΑ ΤΗΝ ΚΛΗΣΗ
    //Δημιουργούμε έναν πίνακα δομών τύπου ActualArgumentRuntimeInfo, που κρατά πληροφορίες για 
    //κάθε actual argument σε μια κλήση υποπρογράμματος (όπως τιμή, τύπος, κατεύθυνση — π.χ. by value ή by reference)
    //Η MAX_ACTUAL_ARGS είναι σταθερά που περιορίζει πόσα ορίσματα επιτρέπονται
    ActualArgumentRuntimeInfo actual_args_for_current_call[MAX_ACTUAL_ARGS];
    int num_actual_args_for_current_call = 0;
    Symbol* called_subprogram_symbol_for_arg_processing = NULL;
%}

// --- Δηλώσεις τύπων-τιμών για την ενότητα %union ---
// Κάθε ένας από αυτούς τους τύπους μπορεί να χρησιμοποιηθεί σε ένα non-terminal
%union {
    int num;
    double real;
    char ch;
    char* str;
    couple cp;
    NameList *name_list;
    TypeDescriptor_Bison type_desc_val;
    int simple_type_tag_val;
    ParameterDescriptor *param_list_val;
    DimensionRange single_dimension_val;
    TypeDescriptor_Bison array_dimensions_val; 
    IndexList index_list_val;
    //Η VariableAccessInfo περιέχει πληροφορία για προσπέλαση μεταβλητών, όπως:
    //Αν είναι by value / by reference
    //Αν είναι πίνακας
    //Αν είναι σε record ή global scope
    VariableAccessInfo* var_access_info_val;
    Symbol* sym_ptr_val; //Για να επιστρέφει το callable_id_lookahead Symbol***
}

// Τόκεν με καθορισμένους τύπους για ανάκτηση τιμών από το λεξικό
%token <str> PROGRAM CONST TYPE COUPLE ARRAY OF VAR FORWARD FUNCTION PROCEDURE
%token <str> PASC_BEGIN PASC_END IF THEN ELSE WHILE DO FOR TO DOWNTO READ WRITE LENGTH
%token <str> INTEGER REAL BOOLEAN CHAR STRING
%token <str> ID WRITELN
%token <num> ICONST
%token <real> RCONST
%token <ch> CCONST
%token <str> SCONST
%token <num> BOOLCONST
%token OROP DIV MOD AND NOTOP HEAD TAIL LBRACK RBRACK

%token LPAREN RPAREN SEMI DOT COMMA ASSIGN COLON DOTDOT EQU NEQ LE GE LT GT
%token T_PLUS T_MINUS // Νέα tokens για + και - (δεν είναι <str>)
%token <str> MULOP DIVOP // Αν το pasc.l μας επιστρέφει string για * και /

// Δήλωση τύπων για μη τερματικά σύμβολα
%type <var_access_info_val> variable
%type <real> expression expressions or_expr and_expr equality_expr relational_expr additive_expr multiplicative_expr unary_expr literal string_comparison real_primary_expr
%type <real> assignment
%type <str> string_expr print_expr write_item
%type <cp> couple_expr
%type <name_list> identifiers
%type <type_desc_val> type_specification      // Ο κύριος κανόνας για ορισμό τύπου
%type <simple_type_tag_val> standard_type_rule base_element_type // Κανόνες που επιστρέφουν απλή ετικέτα τύπου
%type <num> bound_value_expr
%type <param_list_val> formal_parameters_opt parameter_group_list parameter_group
%type <simple_type_tag_val> pass_mode_opt
%type <array_dimensions_val> array_dimension_list_rule
%type <single_dimension_val> single_dimension_bounds_rule
%type <index_list_val> index_expression_list
%type <sym_ptr_val> callable_id_lookahead

// Καθορισμός προτεραιότητας τελεστών για σωστή ανάλυση εκφράσεων
%left OROP
%left ADDOP
%left MULOP DIVOP DIV MOD
%left AND
%right NOTOP
%nonassoc EQU NEQ LT LE GT GE
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%debug

%%

// === ΓΡΑΜΜΑΤΙΚΗ ===

program:
    header declarations comp_statement DOT
        { printf("Το πρόγραμμα αναλύθηκε επιτυχώς.\n"); }
    ;

/* Επικεφαλίδα προγράμματος, ξεκινάει με PROGRAM <όνομα> ; */
header:
    PROGRAM ID SEMI
    ;

/* Περιλαμβάνει σταθερές, τύπους και δηλώσεις μεταβλητών */
declarations:
    constdefs typedefs var_declarations_opt subprogram_declarations_opt
    ;

subprogram_declarations_opt:
    /* κενό */
    | subprogram_declaration_list SEMI
    ;

subprogram_declaration_list:
    subprogram_declaration
    | subprogram_declaration_list SEMI subprogram_declaration
    ;

subprogram_declaration:
    subprogram_header SEMI FORWARD {
        /* Action for FORWARD declaration */
        printf("DEBUG YACC: Processing FORWARD declaration for '%s'\n",
               currently_parsing_function_name ? currently_parsing_function_name : "UNKNOWN_FORWARD_SUB");

        if (currently_parsing_function_name) {
            int sym_idx_in_current_scope = -1;
            for (int i = 0; i < symbolCountStack[current_nesting_level]; i++) {
                if (symbolTableStack[current_nesting_level][i].name &&
                    strcmp(symbolTableStack[current_nesting_level][i].name, currently_parsing_function_name) == 0) {
                    sym_idx_in_current_scope = i;
                    break;
                }
            }

            if (sym_idx_in_current_scope != -1) {
                Symbol* sym_to_mark = &symbolTableStack[current_nesting_level][sym_idx_in_current_scope];
                if ((sym_to_mark->kind == SK_FUNCTION || sym_to_mark->kind == SK_PROCEDURE) &&
                    sym_to_mark->details.subprogram_details) {
                    sym_to_mark->details.subprogram_details->is_forward = 1;
                    printf("DEBUG YACC: Marked '%s' at [%d][%d] as FORWARD.\n",
                           currently_parsing_function_name, current_nesting_level, sym_idx_in_current_scope);
                } else {
                    fprintf(stderr, "ERROR YACC: Could not mark '%s' as FORWARD - symbol details missing or wrong kind.\n", currently_parsing_function_name);
                }
            } else {
                fprintf(stderr, "ERROR YACC: Symbol '%s' not found in current scope to mark as FORWARD.\n", currently_parsing_function_name);
            }
            free(currently_parsing_function_name);
            currently_parsing_function_name = NULL;
        } else {
            fprintf(stderr, "ERROR YACC: currently_parsing_function_name was NULL for FORWARD.\n");
        }
    }
    | subprogram_header SEMI
    { // ACTION BLOCK 1: Είσοδος στο scope και ΠΡΑΓΜΑΤΙΚΗ προσθήκη παραμέτρων
        printf("DEBUG YACC: Entering subprogram body definition for: %s (parent scope level was %d)\n",
            currently_parsing_function_name ? currently_parsing_function_name : "UNKNOWN_SUB_DEF",
            current_nesting_level);

        enterScope(); // Το current_nesting_level είναι τώρα το τοπικό επίπεδο του υποπρογράμματος

        if (currently_parsing_function_name) {
            int parent_scope_of_func = current_nesting_level - 1;

            if (parent_scope_of_func >= 0) {
                Symbol* current_func_sym_for_params = NULL; // Το σύμβολο του υποπρογράμματος που ορίζουμε τώρα
                int temp_level, temp_offset;
                current_func_sym_for_params = findSymbol(currently_parsing_function_name, &temp_level, &temp_offset);
                // Αυτό θα το βρει στο parent scope, καθώς το currently_parsing_function_name τέθηκε από το subprogram_header.
                // Άρα,τώρα πρέπει να ψάξουμε στο parent_scope_of_func.
                if (parent_scope_of_func >=0) {
                    for(int i=0; i<symbolCountStack[parent_scope_of_func]; ++i) {
                        if(symbolTableStack[parent_scope_of_func][i].name &&
                        strcmp(symbolTableStack[parent_scope_of_func][i].name, currently_parsing_function_name) == 0) {
                            current_func_sym_for_params = &symbolTableStack[parent_scope_of_func][i];
                            break;
                        }
                    }
                }

                
                //Ελέγχουμε αν δηλώνεται συνάρτηση,συγκεκριμένα	ελέγχει current_func_sym_for_params
                //Ελέγχουμε αν έχει δηλωθεί λίστα παραμέτρων μέσω subprogram_details
                //Ξεκινάμε τη διαδικασία προσθήκης των παραμέτρων στο scope,δηλώνουμε δείκτη και μετρητές
                //Επίσης κάνουμε debugging με printf
                if (current_func_sym_for_params && current_func_sym_for_params->details.subprogram_details) {
                    ParameterDescriptor* formal_param_desc_iter = current_func_sym_for_params->details.subprogram_details->parameters;
                    int params_added_this_scope = 0;
                    // έλεγχοι κύκλου για formal_param_desc_iter 
                    int formal_param_index = 0; // Για να διατρέξουμε την actual_args_for_current_call

                    printf("DEBUG YACC [Scope Setup]: Adding formal params for '%s' to its scope (level %d). Actual args available: %d\n",
                        currently_parsing_function_name, current_nesting_level, num_actual_args_for_current_call);


                    while (formal_param_desc_iter != NULL) {
                        //έλεγχοι κύκλου για formal_param_desc_iter
                        if (params_added_this_scope >= MAX_PARAMETERS + 5) { goto end_formal_param_processing_loop_final; }

                        //Ελέγχουμε αν η παράμετρος παιρνιέται με αναφορά
                        //pass by refernce,πρέπει να δείχνει σε μία υπαρκτή μεταβλητή
                        if (formal_param_desc_iter->pass_mode == PASS_BY_REFERENCE) {
                            Symbol* actual_arg_sym_for_ref = NULL;
                            int actual_ref_level = -1;
                            int actual_ref_offset = -1;

                            //Υπάρχει actual argument στη θέση formal_param_index
                            //Είναι L-value αναφορά (όχι αριθμός, αλλά κάτι όπως x)
                            //Υπάρχει Symbol* για την actual μεταβλητή (δηλ. είναι γνωστή στο symbol table)
                            if (formal_param_index < num_actual_args_for_current_call &&
                                actual_args_for_current_call[formal_param_index].kind == ARG_KIND_LVALUE_REF &&
                                actual_args_for_current_call[formal_param_index].lvalue_symbol_ptr != NULL) {

                                //Αυτό μας δίνει πληροφορίες για πού βρίσκεται η actual μεταβλητή στη μνήμη 
                                actual_arg_sym_for_ref = actual_args_for_current_call[formal_param_index].lvalue_symbol_ptr;
                                actual_ref_level = actual_arg_sym_for_ref->nesting_level;
                                actual_ref_offset = actual_arg_sym_for_ref->offset;
                                printf("DEBUG YACC [Scope Setup]: VAR Param '%s' will ref actual '%s'(L%d,O%d)\n",
                                    formal_param_desc_iter->name, actual_arg_sym_for_ref->name, actual_ref_level, actual_ref_offset);
                            } else {
                                // Αυτό συμβαίνει αν η κλήση δεν παρείχε σωστό L-value ή αν δεν καλέστηκε ακόμα (μόνο δήλωση)
                                printf("DEBUG YACC [Scope Setup]: VAR Param '%s' - no actual L-value provided yet or call error. Using placeholders.\n", formal_param_desc_iter->name);
                                // Οι placeholders (-1,-1,NULL) είναι σημαντικοί για την addSymbol
                                actual_ref_level = -1; // Σήμανση ότι δεν έχει οριστεί ακόμα η αναφορά
                                actual_ref_offset = -1;
                                actual_arg_sym_for_ref = NULL;
                            }
                            addSymbol(formal_param_desc_iter->name, SK_VARIABLE, &(formal_param_desc_iter->type_desc), NULL,
                                    PASS_BY_REFERENCE, actual_ref_level, actual_ref_offset, actual_arg_sym_for_ref);
                        } else { // PASS_BY_VALUE
                            double actual_val_for_value_param = 0.0; // Βάζουμε Default τιμές


                            //Η if που ρωτάς αφορά την **αντιστοίχιση actual παραμέτρων με τις τυπικές (formal) σε παράμετρο που περνάει
                            // με τιμή (PASS_BY_VALUE) — δηλαδή χωρίς VAR.
                                //Ουσιαστικά,ελέγχει αν υπάρχει actual παράμετρος στη θέση formal_param_index

                                //Επίσης,ελέγχει αν το actual argument είναι R-VALUE
                                //Δηλαδή, είναι κανονική αριθμητική/λογική τιμή και ΟΧΙ αναφορά σε μεταβλητή (L-value).
                            if (formal_param_index < num_actual_args_for_current_call &&
                                actual_args_for_current_call[formal_param_index].kind == ARG_KIND_RVALUE) {
                                actual_val_for_value_param = actual_args_for_current_call[formal_param_index].rvalue_content;
                                printf("DEBUG YACC [Scope Setup]: VALUE Param '%s' will be init with %f\n",
                                    formal_param_desc_iter->name, actual_val_for_value_param);
                            } else {
                                printf("DEBUG YACC [Scope Setup]: VALUE Param '%s' - no actual R-value provided yet or call error. Using default value.\n", formal_param_desc_iter->name);
                            }
                            int param_idx = addSymbol(formal_param_desc_iter->name, SK_VARIABLE, &(formal_param_desc_iter->type_desc), NULL,
                                                    PASS_BY_VALUE, -1, -1, NULL);
                            if (param_idx != -1) {
                                symbolTableStack[current_nesting_level][param_idx].details.simple_value = actual_val_for_value_param;
                            }
                        }
                        params_added_this_scope++;
                        formal_param_index++;
                        formal_param_desc_iter = formal_param_desc_iter->next;
                    }
                    end_formal_param_processing_loop_final:;
                    printf("DEBUG YACC [Scope Setup]: Finished adding formal parameters for '%s'. Added: %d\n",
                        currently_parsing_function_name, params_added_this_scope);
                }
            }
           
        }
    } // Τέλος του Action Block 1

      declarations comp_statement {
        printf("DEBUG YACC: Exiting subprogram scope for: %s (from level %d down to %d)\n",
               currently_parsing_function_name ? currently_parsing_function_name : "UNKNOWN_SUB_EXIT",
               current_nesting_level, current_nesting_level -1);
        exitScope();
        if (currently_parsing_function_name) {
            free(currently_parsing_function_name);
            currently_parsing_function_name = NULL;
        }
      }
;

subprogram_header:
    procedure_header
    | function_header
    ;

//Το procedure_header,παίρνει το όνομα της διαδικασίας και τις παραμέτρους της.
//Δημιουργεί μια δομή SubprogramDetails για να αποθηκεύσει πληροφορίες της διαδικασίας
//(όπως παράμετροι, επίπεδο εμβέλειας, ότι δεν είναι function).
//Προσθέτει τη διαδικασία στον πίνακα συμβόλων της τρέχουσας εμβέλειας.
//Αποθηκεύει το όνομα της διαδικασίας για να χρησιμοποιηθεί μετά(π.χ. για να βάλει τις παραμέτρους στο νέο scope).
procedure_header:
    PROCEDURE ID formal_parameters_opt {
        printf("DEBUG: Parsed PROCEDURE header for '%s'\n", $2);

        SubprogramDetails* sub_details = (SubprogramDetails*)calloc(1, sizeof(SubprogramDetails));
        if (!sub_details) { yyerror("Failed to allocate SubprogramDetails for procedure"); YYABORT; }

        sub_details->parameters = $3; //δολόριο3 είναι ParameterDescriptor* από formal_parameters_opt
        sub_details->is_forward = 0;
        sub_details->nesting_level = current_nesting_level; // Το επίπεδο όπου δηλώνεται
        // Η return_type_desc δεν χρειάζεται για procedures

        // Προσθήκη του ονόματος της διαδικασίας στον πίνακα συμβόλων της τρέχουσας (γονικής) εμβέλειας
        if (addSubprogramSymbol($2, SK_PROCEDURE, sub_details) == -1) {
            free(sub_details); // Απέτυχε η προσθήκη, ελευθέρωσε τη μνήμη
        }
        // Κράτα το όνομα για να ξέρουμε ποιες παραμέτρους να προσθέσουμε μετά το enterScope
        if (currently_parsing_function_name) free(currently_parsing_function_name);
        currently_parsing_function_name = strdup($2); 
    }
    ;
//function_header,καταχωρεί τα βασικά στοιχεία της συνάρτησης στο σύστημα συμβόλων
//για να συνεχιστεί η ανάλυση του σώματός της.
function_header:
    FUNCTION ID formal_parameters_opt COLON type_specification {
        printf("DEBUG: Parsed FUNCTION header for '%s', return type tag: %d\n", $2, $5.tag);

        SubprogramDetails* sub_details = (SubprogramDetails*)calloc(1, sizeof(SubprogramDetails));
        if (!sub_details) { yyerror("Failed to allocate SubprogramDetails for function"); YYABORT; }

        sub_details->parameters = $3;       // δολάριο3 είναι ParameterDescriptor*(Είναι ένας δείκτης (pointer) σε μια δομή που περιγράφει παραμέτρους μιας διαδικασίας ή συνάρτησης(by reference,by value))
        sub_details->return_type_desc = $5; // δολάριο5 είναι TypeDescriptor_Bison (δομή που περιγράφει έναν τύπο δεδομένων (π.χ. int, float, boolean, πίνακα)
        sub_details->is_forward = 0;
        sub_details->nesting_level = current_nesting_level;

        if (addSubprogramSymbol($2, SK_FUNCTION, sub_details) == -1) {
            free(sub_details);
        }
        if (currently_parsing_function_name) free(currently_parsing_function_name);
        currently_parsing_function_name = strdup($2);
    }
    ;

formal_parameters_opt:
    /* κενό */ { $$ = NULL; } // Καμία παράμετρος, επιστρέφει NULL λίστα
    | LPAREN parameter_group_list RPAREN { $$ = $2; } // $2 είναι η λίστα παραμέτρων
    ;

actual_param_list:
    actual_param_item
    | actual_param_list COMMA actual_param_item
    ;

actual_param_item: // Αυτός ο κανόνας γεμίζει την global actual_args_for_current_call
    expression { // Για R-VALUES (pass-by-value)
        if (num_actual_args_for_current_call < MAX_ACTUAL_ARGS) {
            ActualArgumentRuntimeInfo* current_arg = &actual_args_for_current_call[num_actual_args_for_current_call];
            current_arg->kind = ARG_KIND_RVALUE;
            current_arg->rvalue_content = $1; // δολάριο1 είναι το double από το expression

            // ΣΗΜΑΝΤΙΚΟ: Κανονικά εδώ θα έπρεπε να έχουμε τον τύπο του expression.
            // Προς το παρόν, υποθέτουμε ότι είναι REAL 
            current_arg->type_desc.tag = TYPE_REAL; // ΠΡΟΣΩΡΙΝΟ
            current_arg->type_desc.num_dimensions = 0;
            current_arg->lvalue_symbol_ptr = NULL; // Δεν είναι L-value

            printf("DEBUG YACC CallArg: Added RVALUE actual argument #%d, value: %f\n", num_actual_args_for_current_call, $1);
            num_actual_args_for_current_call++;
        } else {
            yyerror("Too many actual arguments provided in subprogram call.");
        }
    }
    | variable { // Για L-VALUES (πιθανό για VAR παραμέτρους)
        if (num_actual_args_for_current_call < MAX_ACTUAL_ARGS) {
            ActualArgumentRuntimeInfo* current_arg = &actual_args_for_current_call[num_actual_args_for_current_call];
            VariableAccessInfo* vai = $1; // δολάριο1 είναι VariableAccessInfo*

            current_arg->kind = ARG_KIND_LVALUE_REF; // Υποθέτουμε ότι αν είναι variable, μπορεί να είναι L-value
            current_arg->lvalue_symbol_ptr = vai->symbol_ptr; // Το symbol_ptr πρέπει να έχει τεθεί από τον κανόνα variable
            current_arg->type_desc = vai->type_desc;     // Ο τύπος του L-value
            // Τα lvalue_level και lvalue_offset τα έχουμε μέσω του lvalue_symbol_ptr->nesting_level και ->offset

            printf("DEBUG YACC CallArg: Added LVALUE actual argument #%d: '%s' (Symbol: %p, Type: %s)\n",
                   num_actual_args_for_current_call, vai->name, 
                   (void*)current_arg->lvalue_symbol_ptr, 
                   typeTagToString(current_arg->type_desc.tag));

            num_actual_args_for_current_call++;
            // Ελευθέρωση του VAI που δημιουργήθηκε από τον κανόνα 'variable'
            if (vai) { if (vai->name) free(vai->name); free(vai); }
        } else {
            yyerror("Too many actual arguments provided in subprogram call.");
            if ($1) { if ($1->name) free($1->name); free($1); } 
        }
    }
    ;

parameter_group_list: // Επιστρέφει <param_list_val> (ParameterDescriptor*)
    parameter_group { $$ = $1; } // Μια ομάδα παραμέτρων
    | parameter_group_list SEMI parameter_group { // Πολλές ομάδες, διαχωρισμένες με ;
        // $$ = appendParameterList($1, $3);
        // Χρειάζεται συνάρτηση για συνένωση λιστών παραμέτρων
        // Για απλότητα, αν το parameter_group επιστρέφει μια πλήρη λίστα (από το identifiers),
        // τότε η appendParameter θα μπορούσε να δουλέψει.
        $$ = appendParameter($1, $3); 
                                      // Το parameter_group φτιάχνει κόμβους για κάθε ID
                                      // και τους προσθέτει έναν-έναν σε μια προσωρινή λίστα.
                                      // Εδώ, το $1 είναι η "συνολική" λίστα και το $3 είναι η "νέα" λίστα.
                                      // Θα πρέπει να τα συνενώσουμε.
                                      // Εδώ, υποθέτουμε ότι το parameter_group επιστρέφει την κεφαλή head
                                      // μιας λίστας παραμέτρων για τα δικά του identifiers.
                                      // Και η appendParameter προσθέτει μια ολόκληρη λίστα στο τέλος μιας άλλης.
                                      // το parameter_group φτιάχνει μια λίστα,
                                      // και εδώ απλά τις συνδέουμε.
        ParameterDescriptor* tail = $1;
        if (tail) { while (tail->next) tail = tail->next; tail->next = $3; $$ = $1;}
        else { $$ = $3;}

    }
    ;

parameter_group: // Επιστρέφει <param_list_val> (ParameterDescriptor*) - μια λίστα από ParameterDescriptors
    pass_mode_opt identifiers COLON type_specification {
        NameList* original_name_list_head = $2;
        NameList* current_name_node = original_name_list_head;
        ParameterDescriptor* head_of_this_group_list = NULL;
        ParameterDescriptor* tail_of_this_group_list = NULL;
        PassMode p_mode = (PassMode)$1; // δολάριο1 είναι PassMode από pass_mode_opt
        TypeDescriptor_Bison param_type = $4; // δολάριο4 είναι TypeDescriptor_Bison από type_specification
        int processed_ids_count = 0;

        printf("DEBUG parameter_group (FULL): Received NameList head: %p for first ID: %s\n",
               (void*)current_name_node, (current_name_node ? current_name_node->name : "NULL_LIST"));

        while (current_name_node != NULL) {
            processed_ids_count++;
            printf("DEBUG parameter_group (FULL) LOOP [%d]: Processing ID: '%s'\n",
                   processed_ids_count, current_name_node->name);

            // Έλεγχος: string ή array πρέπει να είναι VAR
            if ((param_type.tag == TYPE_STRING || param_type.tag == TYPE_ARRAY) && p_mode == PASS_BY_VALUE) {
                char err_msg[120];
                sprintf(err_msg, "Semantic Error: Parameter '%s': STRING or ARRAY types must be passed by VAR.", current_name_node->name);
                yyerror(err_msg);
            }

            ParameterDescriptor* new_param = createParameterNode(current_name_node->name, param_type, p_mode);
            if (!new_param) {
                yyerror("Failed to create parameter node in parameter_group. Memory allocation likely failed.");
                if (head_of_this_group_list) freeParameterList(head_of_this_group_list);
                if (original_name_list_head) freeNameList(original_name_list_head);
                $$ = NULL;
                YYABORT;
            }

            if (head_of_this_group_list == NULL) {
                head_of_this_group_list = new_param;
                tail_of_this_group_list = new_param;
            } else {
                tail_of_this_group_list->next = new_param;
                tail_of_this_group_list = new_param;
            }
            
            current_name_node = current_name_node->next;
        }
        
        printf("DEBUG parameter_group (FULL): Exited loop. Processed %d identifier(s). Returning ParameterDescriptor list head: %p\n",
               processed_ids_count, (void*)head_of_this_group_list);

        if (original_name_list_head) {
            freeNameList(original_name_list_head);
        }
        $$ = head_of_this_group_list;
    }
    ;

pass_mode_opt: // Επιστρέφει <simple_type_tag_val> (PassMode)
    /* κενό */ { $$ = PASS_BY_VALUE; }
    | VAR { $$ = PASS_BY_REFERENCE; }
    ;

// Ο κανόνας type_specification χρησιμοποιείται ως έχει για τον τύπο των παραμέτρων
// και τον τύπο επιστροφής των συναρτήσεων.

/* Ορισμός σταθερών μέσω της λέξης-κλειδί CONST */
constdefs:
      /* κενό */
    | CONST constant_defs
    ;

/* Πολλοί ορισμοί σταθερών */
constant_defs:
      constant_def
    | constant_defs constant_def
    ;

constant_def:
    ID EQU literal SEMI {
        TypeDescriptor_Bison const_type_desc;

        if ($3 == (double)(int)$3) { // Ελέγχει αν το double είναι ουσιαστικά ακέραιος
            const_type_desc.tag = TYPE_INTEGER;
        } else {
            const_type_desc.tag = TYPE_REAL;
        }
        const_type_desc.base_type_tag = TYPE_UNDEFINED;
        const_type_desc.num_dimensions = 0; // Οι σταθερές δεν είναι πίνακες, οπότε 0 διαστάσεις

        printf("DEBUG constant_def: Defining constant '%s' with value %f and inferred type_tag %d at level %d\n", 
               $1, $3, const_type_desc.tag, current_nesting_level);

        // Κλήση της addSymbol με τα σωστά ορίσματα
         int symbol_idx_in_scope = addSymbol($1, SK_CONSTANT, &const_type_desc, NULL,
                                            PASS_MODE_NOT_A_PARAMETER, -1, -1, NULL);

        if (symbol_idx_in_scope != -1) {
            // Η addSymbol (όπως την έχουμε φτιάξει για scope) επιστρέφει το index ΜΕΣΑ στην τρέχουσα εμβέλεια.
            // Η τιμή της σταθεράς πρέπει να τεθεί. Η addSymbol δεν το κάνει για SK_CONSTANT.
            // Η updateSymbolValue είναι για μεταβλητές.
            // Θα θέσουμε την τιμή απευθείας στο symbolTableStack.

            // Δεν χρειάζεται έλεγχος ορίων εδώ, αφού το addSymbol θα το έχει κάνει
            // και θα έχει επιστρέψει έγκυρο index για την current_nesting_level.
            // αν η addSymbol αυξάνει το symbolCountStack[current_nesting_level] ΜΕΤΑ την προσθήκη.
            // Η addSymbol μας επιστρέφει το index όπου τοποθετήθηκε το σύμβολο.
            
            symbolTableStack[current_nesting_level][symbol_idx_in_scope].details.simple_value = $3;
            printf("DEBUG constant_def: Value %f set for constant '%s' at [%d][%d]\n", 
                   $3, $1, current_nesting_level, symbol_idx_in_scope);

            
        }
    }
    ;

/* Ορισμοί τύπων μέσω της λέξης-κλειδί TYPE */
typedefs:
      /* κενό */
    | TYPE type_defs
    ;

/* Πολλοί ορισμοί τύπων */
type_defs:
      type_def_entry
    | type_defs type_def_entry
    ;

/* Ένας ορισμός τύπου: <όνομα> = <τύπος>; */
type_def_entry:
      ID EQU type_def SEMI
    ;

/*
 * Οι τύποι μπορούν να είναι:
 * - Array τύπου (π.χ., ARRAY [1..10] OF INTEGER)
 * - Couple (π.χ., COUPLE OF REAL)
 * - Εύρος τιμών (π.χ., 1..10)
 * - Αναφορά σε άλλο τύπο
 */
type_def:
      ARRAY LBRACK dims RBRACK OF typename
    | COUPLE OF typename
    | limit DOTDOT limit
    | typename
    ;

/* Διαστάσεις πίνακα – μία ή περισσότερες */
dims:
    limits
    | dims COMMA limits
    ;

/* Όρια πίνακα (π.χ., 1..10 ή a..z) */
limits:
      limit DOTDOT limit
    | ID
    ;

/* Ένα όριο: αριθμός, χαρακτήρας, boolean, όνομα */
limit:
      sign ICONST
    | CCONST
    | BOOLCONST
    | ADDOP ID
    | ID
    ;

/* Προαιρετικό πρόσημο σε όριο */
sign:
      ADDOP
    | /* κενό */
    ;

/* Τύποι που μπορούν να χρησιμοποιηθούν σε μεταβλητές ή πίνακες */
typename:
    | ID
    ;

/* Προαιρετικό μπλοκ δηλώσεων μεταβλητών */
var_declarations_opt:
      /* κενό */
    | var_declarations
    ;

/* Μπλοκ δηλώσεων VAR */
var_declarations:
    VAR var_decl_list opt_semi
    ;

/* Προαιρετικό ; στο τέλος λίστας μεταβλητών */
opt_semi:
      /* κενό */
    | SEMI
    ;

/* Πολλές δηλώσεις μεταβλητών χωρισμένες με ; */
var_decl_list:
      var_decl
    | var_decl_list SEMI var_decl
    ;

/* Δήλωση μεταβλητών: λίστα ονομάτων : τύπος */
/*Αποθηκεύει δηλωμένες μεταβλητές με όνομα και τιμή*/
var_decl:
    identifiers COLON type_specification {
        NameList *list = $1;
        NameList *current = list;
        TypeDescriptor_Bison current_var_type_desc = $3;

        printf("DEBUG var_decl: Processing declaration. Type_tag from descriptor: %d\n", current_var_type_desc.tag);
        if (current_var_type_desc.tag == TYPE_ARRAY) {
            // Έλεγχος αν υπάρχουν διαστάσεις πριν την πρόσβαση στο dim_ranges[0]
            if (current_var_type_desc.num_dimensions > 0) {
                printf("DEBUG var_decl: Array base_type_tag: %d, Num_dims: %d, First Dim: %d..%d\n",
                    current_var_type_desc.base_type_tag,
                    current_var_type_desc.num_dimensions,
                    current_var_type_desc.dim_ranges[0].low,
                    current_var_type_desc.dim_ranges[0].high);
            } else {
                printf("DEBUG var_decl: Array base_type_tag: %d, Num_dims: 0 (or error in definition)\n",
                    current_var_type_desc.base_type_tag);
            }
        }

        while (current != NULL) {
            addSymbol(current->name, SK_VARIABLE, &current_var_type_desc, NULL,
                      PASS_MODE_NOT_A_PARAMETER, -1, -1, NULL);
            current = current->next;
        }
        if (list) freeNameList(list);
    }
;

/* Λίστα ονομάτων μεταβλητών (ID [, ID]*) */
identifiers:
    ID                { $$ = createNameNode($1); }
  | identifiers COMMA ID { $$ = appendName($1, $3); }
;

// Κανόνες για τον προσδιορισμό τύπου μιας μεταβλητής
type_specification: // Επιστρέφει TypeDescriptor_Bison (type_desc_val)
    standard_type_rule {
        $$.tag = $1;
        $$.base_type_tag = TYPE_UNDEFINED;
        $$.num_dimensions = 0; // Δεν είναι πίνακας
        printf("DEBUG type_specification: Matched standard_type_rule with tag %d\n", $$.tag);
    }
  | ARRAY LBRACK array_dimension_list_rule RBRACK OF base_element_type {
        $$.tag = TYPE_ARRAY;
        // δολάριο3 (array_dimension_list_rule) είναι ήδη ένα TypeDescriptor_Bison
        // που περιέχει τις διαστάσεις (num_dimensions, dim_ranges)
        // Απλά αντιγράφουμε τις πληροφορίες διαστάσεων και θέτουμε τον τύπο βάσης.
        $$.num_dimensions = $3.num_dimensions;
        for (int i = 0; i < $3.num_dimensions; ++i) {
            $$.dim_ranges[i] = $3.dim_ranges[i];
        }
        $$.base_type_tag = $6; // δολάριο6 είναι το tag από base_element_type
        printf("DEBUG type_specification: Matched ARRAY. Dimensions: %d, Base Type Tag: %d. First dim: %d..%d\n",
               $$.num_dimensions, $$.base_type_tag, ($$.num_dimensions > 0 ? $$.dim_ranges[0].low : -1), ($$.num_dimensions > 0 ? $$.dim_ranges[0].high : -1) );
    }
  | COUPLE OF base_element_type {
        $$.tag = TYPE_COUPLE;
        $$.base_type_tag = $3;
        $$.num_dimensions = 0;
        printf("DEBUG type_specification: Matched COUPLE OF type_tag %d\n", $$.base_type_tag);
    }
  | ID { // Αναφορά σε τύπο ορισμένο από χρήστη
        // Αυτό,χρειάζεται lookup στον πίνακα συμβόλων
        // για να αντιγραφεί η περιγραφή του τύπου $1 στο $$.
        // Προς το παρόν, υποθέτουμε ότι αν είναι ID, είναι ένας τύπος που θα ορίσουμε ως custom/alias
        // και η addSymbol θα πρέπει να τον χειριστεί κατάλληλα.
        yyerror("User-defined types by ID in type_specification not fully implemented for direct resolution here yet.");
        $$.tag = TYPE_UNDEFINED; // Placeholder
        $$.num_dimensions = 0;
        // $$.user_type_name = strdup($1); // Αν είχατε τέτοιο πεδίο
        printf("DEBUG type_specification: Matched user-defined type ID '%s'. Tag set to UNDEFINED.\n", $1);
    }
;

standard_type_rule: // Επιστρέφει simple_type_tag_val (int)
    INTEGER { $$ = TYPE_INTEGER; printf("DEBUG: Matched standard_type_rule INTEGER (tag %d)\n", TYPE_INTEGER); }
  | REAL    { $$ = TYPE_REAL;    printf("DEBUG: Matched standard_type_rule REAL (tag %d)\n", TYPE_REAL); }
  | BOOLEAN { $$ = TYPE_BOOLEAN; printf("DEBUG: Matched standard_type_rule BOOLEAN (tag %d)\n", TYPE_BOOLEAN); }
  | CHAR    { $$ = TYPE_CHAR;    printf("DEBUG: Matched standard_type_rule CHAR (tag %d)\n", TYPE_CHAR); }
  | STRING  { $$ = TYPE_STRING;  printf("DEBUG: Matched standard_type_rule STRING (tag %d)\n", TYPE_STRING); }
;

bound_value_expr: // Ελέγχει ένα όριο πίνακα σε ακέραια τιμή
    ICONST
        {
            $$ = $1;
            printf("DEBUG bound_value_expr: Matched ICONST with value %d\n", $$);
        }
  | ID
        {
            double const_val = getSymbolValue($1);
            // έλεγχος αν το σύμβολο είναι CONSTANT INTEGER
            $$ = (int)const_val;
            printf("DEBUG bound_value_expr: Matched ID '%s' (evaluated as const) to value %d\n", $1, $$);
        }
  | T_PLUS ICONST
        {
            $$ = $2;
            printf("DEBUG bound_value_expr: Matched T_PLUS ICONST %d, evaluated to %d\n", $2, $$);
        }
  | T_MINUS ICONST
        {
            $$ = -$2;
            printf("DEBUG bound_value_expr: Matched T_MINUS ICONST %d, evaluated to %d\n", $2, $$);
        }
  | T_PLUS ID
        {
            double const_val = getSymbolValue($2);
            $$ = (int)const_val;
            printf("DEBUG bound_value_expr: Matched T_PLUS ID '%s', evaluated to %d\n", $2, $$);
        }
  | T_MINUS ID
        {
            double const_val = getSymbolValue($2);
            $$ = -(int)const_val;
            printf("DEBUG bound_value_expr: Matched T_MINUS ID '%s', evaluated to %d\n", $2, $$);
        }
    ;

single_dimension_bounds_rule: // Επιστρέφει DimensionRange (single_dimension_val)
    bound_value_expr DOTDOT bound_value_expr {
        $$.low = $1;
        $$.high = $3;
        if ($1 > $3) {
            char err_msg[120];
            sprintf(err_msg, "Array lower bound %d is greater than upper bound %d.", $1, $3);
            yyerror(err_msg);
           
        }
        printf("DEBUG: Matched single_dimension_bounds_rule %d..%d\n", $1, $3);
    }
;

array_dimension_list_rule: // Επιστρέφει TypeDescriptor_Bison (ως array_dimensions_val) με συμπληρωμένα τα dim_ranges & num_dimensions
    single_dimension_bounds_rule {
        $$.num_dimensions = 1;
        $$.dim_ranges[0] = $1; // $1 είναι το DimensionRange από το single_dimension_bounds_rule
        printf("DEBUG array_dimension_list_rule: Single dim %d..%d\n", $1.low, $1.high);
    }
    | array_dimension_list_rule COMMA single_dimension_bounds_rule {
        if ($1.num_dimensions < MAX_DIMENSIONS) {
            $$ = $1; // Αντιγραφή των προηγούμενων διαστάσεων
            $$.dim_ranges[$$.num_dimensions] = $3; // $3 είναι το νέο DimensionRange
            $$.num_dimensions++;
            printf("DEBUG array_dimension_list_rule: Added dim #%d: %d..%d. Total dims: %d\n", $$.num_dimensions, $3.low, $3.high, $$.num_dimensions);
        } else {
            char err_msg[100];
            sprintf(err_msg, "Exceeded maximum allowed array dimensions (%d).", MAX_DIMENSIONS);
            yyerror(err_msg);
            $$ = $1; // Επιστροφή των όσων είχαν μαζευτεί για αποφυγή περαιτέρω σφαλμάτων
                    // ή θα μπορούσαμε να θέσουμε ένα error state.
        }
    }
;

base_element_type: // Επιστρέφει simple_type_tag_val (int) - τύπος βάσης για array/couple
    //Αν η είσοδος ταιριάζει με έναν standard_type_rule (π.χ. predefined τύπους όπως integer, boolean κτλ), 
    //τότε απλά επιστρέφει το tag του τύπου αυτού ($1).
    //Αν η είσοδος είναι ένα ID (δηλαδή ένα όνομα τύπου που πιθανώς ορίζεται από τον χρήστη)
    standard_type_rule  { $$ = $1; } // $1 είναι το tag από standard_type_rule
  | ID {
        // Εδώ θα έπρεπε να ψάξουμε αν το ID είναι ένας ορισμένος τύπος.
        // Προς το παρόν, το αντιμετωπίζουμε ως μη υποστηριζόμενο.
        printf("DEBUG base_element_type: User-defined base type ID '%s'. Not fully supported for lookup yet.\n", $1);
        $$ = TYPE_UNDEFINED; // Placeholder
    }
;

/* σύνθετη_εντολή → PASC_BEGIN προαιρετικές_εντολές PASC_END */
comp_statement:
    PASC_BEGIN statements_opt PASC_END
    ;

/* προαιρετικές_εντολές → | εντολές | εντολές SEMI */
statements_opt:
    | statements
    | statements SEMI
    ;
    
/* εντολές → εντολές SEMI εντολή | εντολή */
statements:
      statement
    | statements SEMI statement
    ;

/* εντολή → ανάθεση_συμβολοσειράς | αριθμητική_ανάθεση | ανάθεση_ζεύγους 
   | if | while | for | κλήση_υποπρογράμματος | είσοδος/έξοδος | σύνθετη_εντολή */
statement:
      string_assignment
    | assignment
    | couple_assignment
    | if_statement
    | while_statement
    | for_statement
    | subprogram_call
    | io_statement
    | comp_statement
    ;

/* ανάθεση_ζεύγους: μεταβλητή ← έκφραση_ζεύγους */
couple_assignment:
    variable ASSIGN couple_expr {
        printf("Ανάθεση ζεύγους (%f:%f)\n", $3.left, $3.right);
    }
    ;

/* ανάθεση_συμβολοσειράς: μεταβλητή ← έκφραση_συμβολοσειράς */
string_assignment:
    variable ASSIGN string_expr {
        // Το $1 είναι VariableAccessInfo*
        // Το $3 είναι char* (από string_expr)
        if ($1->is_array_element_access) {
            // Προς το παρόν, η ανάθεση συμβολοσειράς σε στοιχείο πίνακα δεν υποστηρίζεται πλήρως.
            // Η $1->name περιέχει την προσωρινή αναπαράσταση "arrayname[index]"
            char err_msg[100];
            sprintf(err_msg, "String assignment to array element '%s' is not supported.", $1->name);
            yyerror(err_msg);
        } else {
            printf("Ανάθεση %s := %s\n", $1->name, $3);
            // Εδώ θα χρειαζόταν updateSymbolStringValue($1->name, $3);
            // Η updateSymbolValue προς το παρόν παίρνει double.
            // Για απλότητα, ας υποθέσουμε ότι το $3 (SCONST) δεν αποθηκεύεται ακόμα.
        }
        if ($1->name) free($1->name); // Ελευθέρωση του str ονόματος
        free($1); // Ελευθέρωση της δομής VariableAccessInfo
        
    }
    ;

/* αριθμητική_ανάθεση: μεταβλητή ← αριθμητική έκφραση */
assignment: // Για αριθμητικές/boolean αναθέσεις
    variable ASSIGN expression {
        VariableAccessInfo* vai = $1; // Το $1 είναι VariableAccessInfo*
        double value_to_assign = $3;

        if (vai->is_array_element_access) {
            printf("DEBUG assignment: Attempting to set array element '%s' (index count: %d, first_idx: %d) to %f\n",
                   vai->name, vai->index_values.count, (vai->index_values.count > 0 ? vai->index_values.indices[0] : -999), value_to_assign);
            // Η setArrayElementValue θα πρέπει να ενημερωθεί να παίρνει char* name και IndexList
            setArrayElementValue(vai->name, &vai->index_values, value_to_assign);
        } else { // Απλή μεταβλητή ή όνομα συνάρτησης για τιμή επιστροφής
            if (currently_parsing_function_name != NULL &&
                vai->name && /* Check for NULL vai->name */
                strcmp(vai->name, currently_parsing_function_name) == 0) {
                // Ανάθεση τιμής επιστροφής στη συνάρτηση
                printf("DEBUG Assignment: Setting return value for function '%s' to %f (using VAI->name)\n",
                       vai->name, value_to_assign);
                int func_sym_idx = -1;
                int func_scope_level = current_nesting_level > 0 ? current_nesting_level - 1 : 0;
                for (int i=0; i < symbolCountStack[func_scope_level]; ++i) {
                    if (symbolTableStack[func_scope_level][i].name &&
                        strcmp(symbolTableStack[func_scope_level][i].name, vai->name) == 0 &&
                        symbolTableStack[func_scope_level][i].kind == SK_FUNCTION) {
                        func_sym_idx = i;
                        break;
                    }
                }
                if (func_sym_idx != -1) {
                    symbolTableStack[func_scope_level][func_sym_idx].details.simple_value = value_to_assign;
                } else {
                    char err_msg[100];
                    sprintf(err_msg, "Could not find function symbol '%s' to set return value.", vai->name);
                    yyerror(err_msg);
                }
            } else { // Απλή μεταβλητή
                if (vai->name) { // Check for NULL vai->name
                   updateSymbolValue(vai->name, value_to_assign);
                } else {
                   yyerror("Attempt to assign to variable with NULL name from VAI.");
                }
            }
        }

        //Ελευθέρωση μνήμης για το VariableAccessInfo(vai)
        //Αν το vai->name υπάρχει, τότε το απελευθερώνει (κάνει free), γιατί η αλυσίδα κώδικα θέλει να 
        //βεβαιωθεί ότι κάθε όνομα που αποθηκεύεται 
        //εκεί είναι ξεχωριστό αντίγραφο (αντιγραφή με //strdup) και άρα πρέπει να καθαριστεί.
        //Μετά, ελευθερώνει και το ίδιο το vai
        if (vai) { 
            if (vai->name) {
                
                free(vai->name);
            }
            free(vai);
        }
    }
    ;

/* if: IF έκφραση THEN εντολή | IF έκφραση THEN εντολή ELSE εντολή */
if_statement:
    IF expression THEN statement %prec LOWER_THAN_ELSE
  | IF expression THEN statement ELSE statement
    ;

/* while: WHILE έκφραση DO εντολή */
while_statement:
    WHILE expression DO statement
    ;
    
/* for: FOR ID ← εύρος_επανάληψης DO εντολή */
for_statement:
    FOR ID ASSIGN iter_space DO statement
    ;

/* κλήση υποπρογράμματος: ID ή ID (εκφράσεις) */
subprogram_call: // $1 is Symbol* from callable_id_lookahead
    callable_id_lookahead actual_params_opt {
        Symbol* sub_sym = $1; 

        if (!sub_sym) { 
            yyerror("Internal error: subprogram_call with NULL sub_sym.");
            YYABORT; // error
        }

        printf("DEBUG YACC SubCall: Processing call to '%s'. Num actual args collected: %d.\n",
               sub_sym->name, num_actual_args_for_current_call);

        if (!sub_sym->details.subprogram_details) {
            char err_msg[150]; sprintf(err_msg, "Subprogram '%s' called but has no internal details structure.", sub_sym->name);
            yyerror(err_msg);
            YYERROR;
        }

        ParameterDescriptor* formal_param = sub_sym->details.subprogram_details->parameters;
        int num_formal_params = 0;
        ParameterDescriptor* temp_fp = formal_param;
        while(temp_fp) { num_formal_params++; temp_fp = temp_fp->next; }

        if (num_actual_args_for_current_call != num_formal_params) {
            char err_msg[150];
            sprintf(err_msg, "Subprogram '%s': Argument count mismatch. Expected %d, got %d.",
                    sub_sym->name, num_formal_params, num_actual_args_for_current_call);
            yyerror(err_msg);
    
        } else {
            // Έλεγχος L-value για VAR και συμβατότητας τύπων 
            temp_fp = formal_param; 
            for (int i = 0; i < num_actual_args_for_current_call; ++i) {
                if (!temp_fp) { /* Αυτό δεν θα έπρεπε να συμβεί αν num_actual == num_formal */ break; }

                ActualArgumentRuntimeInfo* actual_arg = &actual_args_for_current_call[i];
                printf("DEBUG YACC SubCall: Checking formal '%s' (PassMode: %d) vs actual arg #%d (Kind: %d)\n",
                       temp_fp->name, temp_fp->pass_mode, i, actual_arg->kind);

                if (temp_fp->pass_mode == PASS_BY_REFERENCE) {
                    if (actual_arg->kind != ARG_KIND_LVALUE_REF || !actual_arg->lvalue_symbol_ptr) {
                        char err_msg[200];
                        sprintf(err_msg, "Subprogram '%s', formal parameter '%s' (VAR): Expected L-value argument, but got R-value or invalid L-value for actual argument #%d.",
                                sub_sym->name, temp_fp->name, i + 1);
                        yyerror(err_msg);
                    } else {
                        // Έλεγχος τύπων (απλοποιημένος - πρέπει να είναι ακριβώς ίδιοι)
                        // Μια πιο πλήρης υλοποίηση θα ελέγχει τη συμβατότητα τύπων.
                        if (temp_fp->type_desc.tag != actual_arg->type_desc.tag ||
                            (temp_fp->type_desc.tag == TYPE_ARRAY && ( // Για πίνακες, έλεγξε και τα υπόλοιπα
                             temp_fp->type_desc.base_type_tag != actual_arg->type_desc.base_type_tag ||
                             temp_fp->type_desc.num_dimensions != actual_arg->type_desc.num_dimensions 
                            
                             // (προς το παρόν ο τύπος του actual_arg είναι ο τύπος του στοιχείου για array L-value)
                             // Η actual_arg->type_desc για LVALUE είναι ο τύπος του ίδιου του LVALUE.
                             // Εδώ ελέγχουμε αν ο τύπος της VAR παραμέτρου ταιριάζει με τον τύπο του L-value.
                             
                            ))
                        ) {
                             char err_msg[250];
                             sprintf(err_msg, "Subprogram '%s', parameter '%s': Type mismatch for VAR argument #%d. Formal type %s, actual L-value type %s.",
                                     sub_sym->name, temp_fp->name, i + 1, 
                                     typeTagToString(temp_fp->type_desc.tag), 
                                     typeTagToString(actual_arg->type_desc.tag) );
                             yyerror(err_msg);
                        }
                    }
                } else { // PASS_BY_VALUE
                    // Έλεγχος τύπων (π.χ. επιτρέπεται ανάθεση INTEGER σε REAL παράμετρο)
                    if (temp_fp->type_desc.tag != actual_arg->type_desc.tag) {
                        if (! (temp_fp->type_desc.tag == TYPE_REAL && actual_arg->type_desc.tag == TYPE_INTEGER) ) { // Επιτρέπουμε int σε real
                            char err_msg[250];
                            sprintf(err_msg, "Subprogram '%s', parameter '%s': Type mismatch for VALUE argument #%d. Formal type %s, actual R-value type %s.",
                                    sub_sym->name, temp_fp->name, i + 1, 
                                    typeTagToString(temp_fp->type_desc.tag), 
                                    typeTagToString(actual_arg->type_desc.tag) );
                            yyerror(err_msg);
                        }
                    }
                }
                temp_fp = temp_fp->next;
            }
        }
        printf("DEBUG YACC SubCall: Call to '%s' processed. Actual args stored globally.\n", sub_sym->name);
       
    }
    ;

callable_id_lookahead: // Επιστρέφει Symbol*
    ID {
        num_actual_args_for_current_call = 0; // Μηδενισμός για την τρέχουσα κλήση
        int found_lvl = -1, found_off = -1;
        $$ = findSymbol($1, &found_lvl, &found_off); // Η findSymbol υπάρχει στο helpers.c
        if (!$$ || ($$->kind != SK_PROCEDURE && $$->kind != SK_FUNCTION)) {
            char err_msg[150]; sprintf(err_msg, "Identifier '%s' is not a declared procedure or function.", $1); yyerror(err_msg);
            free($1); // Το $1 είναι από το ID token, υποθέτουμε ότι ο lexer το κάνει strdup
            $$ = NULL; 
            YYERROR; // Προκαλεί σφάλμα bison 
        }
        printf("DEBUG YACC Call: Found callable ID '%s'. Symbol @ %p. Preparing for arguments.\n", $$->name, (void*)$$);
        called_subprogram_symbol_for_arg_processing = $$; // Αποθήκευση για χρήση από actual_param_item
    }
    ;

actual_params_opt:
    /* empty */ {
        // Αν δεν υπάρχουν παρενθέσεις στην κλήση (π.χ. MyProc;), αυτό δεν καλείται.
        // Αν υπάρχουν κενές παρενθέσεις (π.χ. MyProc()), τότε καλείται η παρακάτω εναλλακτική.
        // Ο num_actual_args_for_current_call θα είναι 0 από το callable_id_lookahead.
    }
    | LPAREN RPAREN { /* Κλήση με κενές παρενθέσεις, π.χ., f() */
        // num_actual_args_for_current_call παραμένει 0
        printf("DEBUG YACC CallArg: Call with empty parentheses.\n");
    }
    | LPAREN actual_param_list RPAREN
    ;


/* εύρος επανάληψης: έκφραση TO έκφραση | έκφραση DOWNTO έκφραση */
iter_space:
      expression TO expression
    | expression DOWNTO expression
    ;

/* είσοδος/έξοδος: READ(...) | WRITE(...) | WRITELN(...) */
io_statement:
    READ LPAREN read_list RPAREN
  | WRITE LPAREN write_list RPAREN
  | WRITELN LPAREN write_list RPAREN
  ;
    
/* λίστα ανάγνωσης: μεταβλητές χωρισμένες με κόμμα */
read_list:
    read_item
    | read_list COMMA read_item
    ;

/* στοιχείο ανάγνωσης: μεταβλητή */
read_item:
    variable {
        VariableAccessInfo* vai = $1; // Το $1 είναι VariableAccessInfo*

        if (vai->is_array_element_access) {
            // Η vai->name περιέχει την προσωρινή αναπαράσταση "arrayname[index]"
            printf("DEBUG read_item: Array element target (from VAI) '%s[%d]'. Read logic not fully implemented for array elements.\n",
                   vai->name, // Εδώ το vai->name είναι το "arrayname[index]" 
                              // Το vai->index_values.indices[0] έχει τον δείκτη.
                              
                   vai->index_values.indices[0]);
            
        } else {
            printf("DEBUG read_item: Simple variable target (from VAI) '%s'.\n", vai->name);
           
        }

        if (vai->name) free(vai->name); // Ελευθέρωση του strdup'd ονόματος
        free(vai); // Ελευθέρωση της δομής VariableAccessInfo
    }
    ;

/* λίστα εκτύπωσης: εκφράσεις προς εκτύπωση χωρισμένες με κόμμα */
write_list:
    write_item
    | write_list COMMA write_item
    ;

/* στοιχείο εκτύπωσης: έκφραση προς εμφάνιση */
write_item:
    print_expr { $$ = $1; }
    ;

/* έκφραση για εκτύπωση: είτε συμβολοσειρά είτε αριθμός */
print_expr:
    string_expr { $$ = $1; }
  | expression {
        char buf[64]; // Στατικός buffer, ασφαλής για άμεση χρήση αλλά όχι για επιστροφή εκτός αν αντιγραφεί
        sprintf(buf, "%f", $1);
        $$ = strdup(buf); // Το strdup είναι απαραίτητο εδώ για να επιζήσει το string
    }
  ;

/* --- Κανόνας για τις μεταβλητές (variable) ---
   Μια μεταβλητή μπορεί να είναι είτε απλό αναγνωριστικό είτε στοιχείο πίνακα.
*/
variable: 
    ID {
        $$ = (VariableAccessInfo*)calloc(1, sizeof(VariableAccessInfo)); // Χρήση calloc
        if (!$$) { yyerror("Malloc failed for VAI (ID)"); YYABORT; }
        $$->name = strdup($1); 
        if (!$$->name) { yyerror("strdup failed for VAI name (ID)"); free($$); YYABORT; }
        $$->is_array_element_access = 0;
        $$->index_values.count = 0;
        // Βρες το σύμβολο και τον τύπο του
        int found_l, found_o;
        $$->symbol_ptr = findSymbol($$->name, &found_l, &found_o);
        if ($$->symbol_ptr) {
            // Δημιούργησε TypeDescriptor_Bison από τις πληροφορίες του συμβόλου
            $$->type_desc.tag = $$->symbol_ptr->type_tag_general;
            if ($$->symbol_ptr->type_tag_general == TYPE_ARRAY && $$->symbol_ptr->details.array_details) {
                $$->type_desc.base_type_tag = $$->symbol_ptr->details.array_details->base_type_tag;
                $$->type_desc.num_dimensions = $$->symbol_ptr->details.array_details->num_dimensions;
                // Αντίγραψε τα ranges των διαστάσεων
                for (int i = 0; i < $$->symbol_ptr->details.array_details->num_dimensions && i < MAX_DIMENSIONS; i++) {
                    $$->type_desc.dim_ranges[i] = $$->symbol_ptr->details.array_details->dim_ranges[i];
                }
            } else {
                $$->type_desc.base_type_tag = $$->symbol_ptr->type_tag_general;
                $$->type_desc.num_dimensions = 0;
            }
        } else {
            yyerror("Variable ID not found during VAI creation (should not happen if declared)");
            $$->type_desc.tag = TYPE_UNDEFINED;
        }
    }
    | ID LBRACK index_expression_list RBRACK {
        $$ = (VariableAccessInfo*)calloc(1, sizeof(VariableAccessInfo));
        if (!$$) { yyerror("Malloc failed for VAI (Array Access)"); YYABORT; }
        $$->name = strdup($1); 
        if (!$$->name) { yyerror("strdup failed for VAI name (Array)"); free($$); YYABORT; }
        $$->is_array_element_access = 1;
        $$->index_values = $3;
        // Βρες το σύμβολο του πίνακα και τον τύπο του στοιχείου
        int found_l, found_o;
        $$->symbol_ptr = findSymbol($$->name, &found_l, &found_o);
        if ($$->symbol_ptr && $$->symbol_ptr->kind == SK_VARIABLE && $$->symbol_ptr->type_tag_general == TYPE_ARRAY) {
            $$->type_desc.tag = $$->symbol_ptr->details.array_details->base_type_tag; // Τύπος του στοιχείου
            $$->type_desc.base_type_tag = $$->symbol_ptr->details.array_details->base_type_tag;
            $$->type_desc.num_dimensions = 0; // Ένα στοιχείο δεν είναι πίνακας
        } else {
             yyerror("Array ID not found or not an array during VAI creation for element access");
             $$->type_desc.tag = TYPE_UNDEFINED;
             $$->type_desc.base_type_tag = TYPE_UNDEFINED;
             $$->type_desc.num_dimensions = 0;
        }
    }
;

index_expression_list: // Επιστρέφει IndexList (index_list_val)
    expression {
        $$.count = 1;
        $$.indices[0] = (int)$1; // Το $1 είναι double από το expression
        printf("DEBUG index_expression_list_rule: Single index value: %d\n", $$.indices[0]);
    }
    | index_expression_list COMMA expression {
        if ($1.count < MAX_DIMENSIONS) {
            $$ = $1; // Αντιγραφή της υπάρχουσας λίστας δεικτών
            $$.indices[$$.count] = (int)$3; // Προσθήκη του νέου δείκτη (το $3 είναι double)
            $$.count++;
            printf("DEBUG index_expression_list_rule: Added index #%d: value %d. Total indices: %d\n", $$.count, $$.indices[$$.count-1], $$.count);
        } else {
            char err_msg[100];
            sprintf(err_msg, "Exceeded maximum allowed indices for array access (%d).", MAX_DIMENSIONS);
            yyerror(err_msg);
            $$ = $1; // Επιστροφή των όσων είχαν μαζευτεί
        }
    }
;

/* --- Κανόνας για λίστα εκφράσεων ---
   Χρήσιμος για εκφράσεις π.χ. σε παραμέτρους κλήσεων ή πίνακες.
*/
expressions:
      expression { $$ = $1; }
    | expressions COMMA expression { $$ = $1 + $3; /* Εδώ γίνεται άθροιση των αποτελεσμάτων για απλότητα */ }
    ;

 /*   Η κύρια είσοδος για έκφραση είναι η or_expr (λογικό Ή).*/
expression:
    or_expr { $$ = $1; }
    ;

/* --- Λογικό Ή ---
   Επιστρέφει true αν οποιοδήποτε από τα δύο είναι true.
*/
or_expr:
    and_expr
    | or_expr OROP and_expr { $$ = ((int)$1 || (int)$3); }
    ;

/* --- Λογικό ΚΑΙ ---
   Επιστρέφει true μόνο αν και τα δύο είναι true.
*/
and_expr:
    equality_expr
    | and_expr AND equality_expr { $$ = ((int)$1 && (int)$3); }
    ;

/* --- Εκφράσεις Ισότητας ---
   Συγκρίνει για ισότητα ή ανισότητα. Μπορεί επίσης να συγκρίνει συμβολοσειρές.
*/
equality_expr:
      relational_expr
    | equality_expr EQU relational_expr { $$ = ($1 == $3); }
    | equality_expr NEQ relational_expr { $$ = ($1 != $3); }
    | string_comparison { $$ = $1; } /* Συγκρίσεις μεταξύ strings όταν εφαρμόζεται */
    ;

/* --- Σχεσιακές Εκφράσεις ---
   Περιλαμβάνουν τους τελεστές <, <=, >, >=.
*/
relational_expr:
    additive_expr
    | relational_expr LT additive_expr { $$ = ($1 < $3); }
    | relational_expr LE additive_expr { $$ = ($1 <= $3); }
    | relational_expr GT additive_expr { $$ = ($1 > $3); }
    | relational_expr GE additive_expr { $$ = ($1 >= $3); }
    ;

/* --- Πρόσθεση και Αφαίρεση ---
   Οι αριθμητικές πράξεις αθροίσματος και διαφοράς.
*/
additive_expr:
    multiplicative_expr
    | additive_expr T_PLUS multiplicative_expr {
        $$ = $1 + $3;
        printf("DEBUG additive_expr: %f + %f = %f\n", $1, $3, $$);
    }
    | additive_expr T_MINUS multiplicative_expr {
        $$ = $1 - $3;
        printf("DEBUG additive_expr: %f - %f = %f\n", $1, $3, $$);
    }
    ;
/* --- Πολλαπλασιασμός, Διαίρεση, Mod ---
   Πραγματικός και ακέραιος πολλαπλασιασμός, διαίρεση και υπολογισμός υπολοίπου.
*/
multiplicative_expr:
    unary_expr
  | multiplicative_expr MULOP unary_expr { $$ = $1 * $3; } /* Πολλαπλασιασμός */
  | multiplicative_expr DIVOP unary_expr { /* Πραγματική διαίρεση */
        if ($3 == 0.0) {
            yyerror("Διαίρεση με το μηδέν");
            $$ = 0.0;
        } else {
            $$ = $1 / $3;
        }
    }
  | multiplicative_expr DIV unary_expr { /* Ακέραια διαίρεση */
        if ($3 == 0) {
            yyerror("Ακέραια διαίρεση με το μηδέν");
            $$ = 0.0;
        } else {
            $$ = (double)((int)$1 / (int)$3); /* Ακέραια διαίρεση μετατρεπόμενη σε double */
        }
    }
  | multiplicative_expr MOD unary_expr { /* Υπόλοιπο ακέραιας διαίρεσης */
        if ($3 == 0) {
            yyerror("Υπόλοιπο διαίρεσης με το μηδέν");
            $$ = 0.0;
        } else {
            $$ = (double)((int)$1 % (int)$3); /* Υπολογισμός υπολοίπου */
        }
    }
;

/* ---  Μοναδιαίες Εκφράσεις(unary_expr) ---
   Περιλαμβάνουν αρνητικούς αριθμούς και λογική άρνηση.
*/
unary_expr:
    NOTOP unary_expr {
        // Εξασφάλισε ότι η τιμή είναι double αν ο τύπος του unary_expr είναι double
        $$ = !((int)$2) ? 1.0 : 0.0;
    }
  | T_PLUS real_primary_expr { // Μοναδιαίο +
        $$ = $2;
        printf("DEBUG unary_expr: + %f = %f\n", $2, $$);
    }
  | T_MINUS real_primary_expr { // Μοναδιαίο -
        $$ = -$2;
        printf("DEBUG unary_expr: - %f = %f\n", $2, $$);
    }
  | real_primary_expr { $$ = $1; }
    ;


/* --- string_expr ---
     Επιστρέφει από το lexeme ένα string constant ή  ένα identifier.
*/
string_expr:
    SCONST { $$ = $1; }
  ;

/* --- primary_expr ---
   Primary εκφράσεις που επιστρέφουν αριθμητική τιμή (double).
   Περιλαμβάνεται και η χρήση της συνάρτησης LENGTH πάνω σε έκφραση τύπου string.
*/
real_primary_expr:
    literal { $$ = $1; }
    | ID { // Απλή μεταβλητή ή σταθερά
         printf("DEBUG real_primary_expr: Accessing ID '%s' for its value.\n", $1);
         $$ = getSymbolValue($1); // Η getSymbolValue περιμένει char*
    }
    | ID LBRACK index_expression_list RBRACK { // ΧΡΗΣΗ ΤΟΥ ΝΕΟΥ ΚΑΝΟΝΑ ΕΔΩ (R-VALUE ARRAY ACCESS)
        VariableAccessInfo vai_info; // Τοπική στη στοίβα, 
        vai_info.name = $1; // Υποθέτουμε strdup'd από lexer,γενικά η συνάρτηση από την c,η strdup'd δημιουργεί ένα νέο αντίγραφο μιας συμβολοσειράς (string) που της δίνεις
        vai_info.is_array_element_access = 1;
        vai_info.index_values = $3; // $3 είναι το IndexList από το index_expression_list_rule

        printf("DEBUG real_primary_expr: R-Value Array Element Access for '%s'. Index count: %d. First index: %d\n",
               vai_info.name, vai_info.index_values.count, (vai_info.index_values.count > 0 ? vai_info.index_values.indices[0] : -999));

        // Η getArrayElementValue θα πρέπει να ενημερωθεί να παίρνει char* name και IndexList
        $$ = getArrayElementValue(vai_info.name, &vai_info.index_values);
        
    }
    
    | ID LPAREN expressions RPAREN { /* Function call */
        printf("DEBUG: R-Value Function Call '%s' (...) (using placeholder 0.0 for now)\n", $1);
        $$ = 0.0; // Placeholder - Η υλοποίηση κλήσης συνάρτησης είναι ξεχωριστό θέμα
    }
    | HEAD ID {
        printf("DEBUG: HEAD applied to ID '%s' (using placeholder 0.0 for now)\n", $2);
        $$ = 0.0; // Placeholder
    }
    | TAIL ID {
        printf("DEBUG: TAIL applied to ID '%s' (using placeholder 0.0 for now)\n", $2);
        $$ = 0.0; // Placeholder
    }
    | LPAREN expression RPAREN { $$ = $2; }
    | LENGTH LPAREN string_expr RPAREN {
        // Το $3 είναι char* από το string_expr. Η strlen είναι ασφαλής αν το $3 είναι null-terminated.
        if ($3) $$ = (double)strlen($3); else { yyerror("LENGTH applied to NULL string expr"); $$ = 0.0; }
    }
;

couple_expr:
    LPAREN expression COLON expression RPAREN {
        $$.left = $2;
        $$.right = $4;
        printf("Constructed couple: (%f : %f)\n", $2, $4);
    }
;



/* --- Σύγκριση Συμβολοσειρών (string_comparison) ---
   Γίνεται απευθείας σύγκριση δύο εκφράσεων τύπου συμβολοσειράς (string_expr) με strcmp.
*/
string_comparison:
    string_expr EQU string_expr {
        if(strcmp($1, $3) == 0) {
            printf("DEBUG: '%s' == '%s' είναι αληθές.\n", $1, $3);
            $$ = 1.0;
        } else {
            printf("DEBUG: '%s' == '%s' είναι ψευδές.\n", $1, $3);
            $$ = 0.0;
        }
    }
  | string_expr NEQ string_expr {
        if(strcmp($1, $3) != 0) {
            printf("DEBUG: '%s' != '%s' είναι αληθές.\n", $1, $3);
            $$ = 1.0;
        } else {
            printf("DEBUG: '%s' != '%s' είναι ψευδές.\n", $1, $3);
            $$ = 0.0;
        }
    }
  | string_expr LT string_expr {
        if(strcmp($1, $3) < 0) {
            printf("DEBUG: '%s' < '%s' είναι αληθές.\n", $1, $3);
            $$ = 1.0;
        } else {
            printf("DEBUG: '%s' < '%s' είναι ψευδές.\n", $1, $3);
            $$ = 0.0;
        }
    }
  | string_expr LE string_expr {
        if(strcmp($1, $3) <= 0) {
            printf("DEBUG: '%s' <= '%s' είναι αληθές.\n", $1, $3);
            $$ = 1.0;
        } else {
            printf("DEBUG: '%s' <= '%s' είναι ψευδές.\n", $1, $3);
            $$ = 0.0;
        }
    }
  | string_expr GT string_expr {
        if(strcmp($1, $3) > 0) {
            printf("DEBUG: '%s' > '%s' είναι αληθές.\n", $1, $3);
            $$ = 1.0;
        } else {
            printf("DEBUG: '%s' > '%s' είναι ψευδές.\n", $1, $3);
            $$ = 0.0;
        }
    }
  | string_expr GE string_expr {
        if(strcmp($1, $3) >= 0) {
            printf("DEBUG: '%s' >= '%s' είναι αληθές.\n", $1, $3);
            $$ = 1.0;
        } else {
            printf("DEBUG: '%s' >= '%s' είναι ψευδές.\n", $1, $3);
            $$ = 0.0;
        }
    }
;

/* --- Κυριολεκτικές τιμές (literal) ---
   Υποστήριξη για ακέραιες, πραγματικές, boolean και χαρακτήρες.
*/
literal:
    ICONST     { $$ = (double)$1; }
  | RCONST     { $$ = $1; }
  | BOOLCONST  { $$ = (double)$1; }
  | CCONST     { $$ = (double)$1; }
;
%%


/* C CODE */

void yyerror(const char *s) {
    /* Εμφάνιση σφάλματος με όνομα αρχείου και γραμμή */
    fprintf(stderr, "%s:%d: Σφάλμα: %s\n", input_filename, yylineno, s);
}

int main(int argc, char **argv) {
    /* Αν έχει δοθεί αρχείο ως όρισμα */
    if (argc > 1) {
        input_filename = argv[1]; // Αποθήκευση ονόματος αρχείου
        FILE *fp = fopen(argv[1], "r");
        if (!fp) {
            perror(argv[1]); // Εμφάνιση σφάλματος ανοίγματος αρχείου
            exit(1);
        }
        yyin = fp; // Ο Flex να διαβάζει από το αρχείο
    } else {
        printf("Χρήση: %s <εισ_αρχείο.p>\n", argv[0]);
        return 1; // Δεν δόθηκε αρχείο ως όρισμα
    }
    initSymbolTableManagement();

    int result = yyparse(); // Εκκίνηση ανάλυσης

    if (yyin != stdin && yyin != NULL) { // έλεγχο για NULL
        fclose(yyin); // Κλείσιμο αρχείου εισόδου
    }

    freeSymbolTableData();

    return result;
}
