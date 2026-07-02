#ifndef HELPERS_H
#define HELPERS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// --- Σταθερές ---
#define MAX_SYMBOLS 100
#define MAX_DIMENSIONS 3
#define MAX_PARAMETERS 10
#define MAX_ACTUAL_ARGS 20
#define MAX_NESTING_DEPTH 10

// --- Προκαταβολικές Δηλώσεις ---
typedef struct Symbol_s Symbol;
typedef struct ParameterDescriptor_s ParameterDescriptor;

// --- Βασικές Δομές ---
typedef struct
{
    double left;
    double right;
} couple;

typedef struct NameList_s
{
    char *name;
    struct NameList_s *next;
} NameList;

typedef struct
{
    int low;
    int high;
} DimensionRange;

typedef struct ArrayDetails_s
{
    int base_type_tag;
    int num_dimensions;
    DimensionRange dim_ranges[MAX_DIMENSIONS];
    void *data;
    int element_size;
    int total_elements;
} ArrayDetails;

// Περιγραφέας Τύπου για μεταφορά πληροφοριών από/προς τη Bison
typedef struct TypeDescriptor_Bison_s
{
    int tag;
    int base_type_tag;
    int num_dimensions;
    DimensionRange dim_ranges[MAX_DIMENSIONS];
} TypeDescriptor_Bison;

// --- Ετικέτες Τύπων ---
#define TYPE_UNDEFINED 0
#define TYPE_INTEGER 1
#define TYPE_REAL 2
#define TYPE_BOOLEAN 3
#define TYPE_CHAR 4
#define TYPE_STRING 5
#define TYPE_ARRAY 6
#define TYPE_COUPLE 7

// --- Είδη Συμβόλων ---
typedef enum
{
    SK_UNDEFINED,
    SK_VARIABLE,
    SK_CONSTANT,
    SK_TYPE_DEF,
    SK_PROCEDURE,
    SK_FUNCTION
} SymbolKind;

// --- Τρόποι Περάσματος Παραμέτρων ---
typedef enum
{
    PASS_BY_VALUE,
    PASS_BY_REFERENCE,
    PASS_MODE_NOT_A_PARAMETER // Για σύμβολα που δεν είναι τυπικές παράμετροι
} PassMode;

// Περιγραφέας Τυπικής Παραμέτρου (στη δήλωση υποπρογράμματος)
struct ParameterDescriptor_s
{
    char *name;
    TypeDescriptor_Bison type_desc;
    PassMode pass_mode;
    ParameterDescriptor *next;
};

typedef struct SubprogramDetails_s
{
    TypeDescriptor_Bison return_type_desc; // Για συναρτήσεις
    ParameterDescriptor *parameters;
    int nesting_level;
    int is_forward;
} SubprogramDetails;

// Λεπτομέρειες για παραμέτρους που περνούν με αναφορά (VAR)
typedef struct VarParamRefDetails_s
{
    int referenced_level;     // Επίπεδο του αρχικού συμβόλου στο οποίο γίνεται η αναφορά
    int referenced_offset;    // Offset του αρχικού συμβόλου
    Symbol *points_to_symbol; // Άμεσος Δείκτης στο αρχικό σύμβολο (πολύ χρήσιμο)
} VarParamRefDetails;

// --- Κύρια Δομή Συμβόλου ---
struct Symbol_s
{
    char *name;
    SymbolKind kind;
    int type_tag_general; // Ο κύριος τύπος (π.χ. TYPE_INTEGER) ή τύπος επιστροφής συνάρτησης

    union
    {
        double simple_value;                   // Για απλούς τύπους (INTEGER, REAL, BOOLEAN) και παραμέτρους τιμής
        char *string_value;                    // Για σταθερές STRING και παραμέτρους τιμής
        ArrayDetails *array_details;           // Για μεταβλητές πίνακα
        SubprogramDetails *subprogram_details; // Για συναρτήσεις/διαδικασίες
        VarParamRefDetails var_ref_details;    // Για VAR παραμέτρους, κρατά την αναφορά
    } details;

    int nesting_level;
    int offset;
};

// Για Λίστες Δεικτών Πίνακα (από την ανάλυση της πρόσβασης)
typedef struct IndexList_s
{
    int indices[MAX_DIMENSIONS];
    int count;
} IndexList;

// Για Πληροφορίες Πρόσβασης Μεταβλητής (επιστρέφεται από τον κανόνα 'variable')
typedef struct VariableAccessInfo_s
{
    char *name;
    IndexList index_values;
    int is_array_element_access; // 0 για απλό ID, 1 για ID[indices]
    Symbol *symbol_ptr;          // Δείκτης στο σύμβολο του L-value
    TypeDescriptor_Bison type_desc;
} VariableAccessInfo;

// Για Πραγματικά Ορίσματα σε Κλήση Υποπρογράμματος
typedef enum
{
    ARG_KIND_RVALUE,    // Το όρισμα είναι μια υπολογισμένη τιμή
    ARG_KIND_LVALUE_REF // Το όρισμα είναι ένα L-value για πέρασμα με αναφορά
} ActualArgumentKind;

typedef struct ActualArgumentRuntimeInfo_s
{
    ActualArgumentKind kind;
    TypeDescriptor_Bison type_desc;
    double rvalue_content;     // Για RVALUE (pass-by-value)
    Symbol *lvalue_symbol_ptr; // Για LVALUE_REF (pass-by-reference)
} ActualArgumentRuntimeInfo;

// --- Καθολικές Μεταβλητές (δηλώνονται στο .y, εδώ extern) ---
extern Symbol symbolTableStack[MAX_NESTING_DEPTH][MAX_SYMBOLS];
extern int symbolCountStack[MAX_NESTING_DEPTH];
extern int current_nesting_level;
extern int yylineno;
extern char *input_filename;
extern char *currently_parsing_function_name;

// --- Καθολικές Μεταβλητές για τη διαχείριση κλήσεων υποπρογραμμάτων ---
extern ActualArgumentRuntimeInfo actual_args_for_current_call[MAX_ACTUAL_ARGS];
extern int num_actual_args_for_current_call;
extern Symbol *called_subprogram_symbol_for_arg_processing;

// --- Πρωτότυπα Συναρτήσεων ---
void initSymbolTableManagement();
void enterScope();
void exitScope();
void printSymbolTable();
void freeSymbolTableData();

NameList *createNameNode(char *name);
NameList *appendName(NameList *list, char *name);
void freeNameList(NameList *list);

ParameterDescriptor *createParameterNode(char *name, TypeDescriptor_Bison type_desc, PassMode mode);
ParameterDescriptor *appendParameter(ParameterDescriptor *list, ParameterDescriptor *new_param);
void freeParameterList(ParameterDescriptor *list);

int addSymbol(char *name, SymbolKind kind, TypeDescriptor_Bison *type_desc, void *specific_details,
              PassMode param_mode_from_declaration,
              int ref_level, int ref_offset, Symbol *ref_sym_ptr);

int addVariableSymbol(char *name, TypeDescriptor_Bison *type_desc);
int addConstantSymbol(char *name, TypeDescriptor_Bison *type_desc, double value);
int addSubprogramSymbol(char *name, SymbolKind kind, SubprogramDetails *sub_details);

double getSymbolValue(char *name);
void updateSymbolValue(char *name, double value);

double getArrayElementValue(char *array_name, IndexList *indices);
void setArrayElementValue(char *array_name, IndexList *indices, double value);

const char *typeTagToString(int tag);
const char *symbolKindToString(SymbolKind kind);
Symbol *findSymbol(char *name, int *found_level_ptr, int *found_offset_ptr);

#endif // HELPERS_H
