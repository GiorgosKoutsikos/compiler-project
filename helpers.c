// --- helpers.c ---
#include "helpers.h"
#include "pasc.tab.h"

// --- Αρχικοποίηση ---
void initSymbolTableManagement()
{
    current_nesting_level = 0;
    for (int i = 0; i < MAX_NESTING_DEPTH; i++)
    {
        symbolCountStack[i] = 0;
    }
    // Αρχικοποίηση της καθολικής εμβέλειας
}

// --- Διαχείριση Εμβέλειας ---
void enterScope()
{
    if (current_nesting_level + 1 >= MAX_NESTING_DEPTH)
    {
        fprintf(stderr, "%s:%d: Error: Maximum nesting depth (%d) exceeded.\n", input_filename, yylineno, MAX_NESTING_DEPTH);
        // Χειρισμός σφάλματος, π.χ. exit(1) ή προσπάθεια ανάκαμψης

        exit(1); // Βάζουμε ένα exit για περισσότερη ασφάλεια
    }
    current_nesting_level++;
    symbolCountStack[current_nesting_level] = 0; // Νέα εμβέλεια, άδειος πίνακας συμβόλων
    printf("DEBUG Scope: Entered scope, new level: %d\n", current_nesting_level);
}

void exitScope()
{
    if (current_nesting_level < 0)
    {
        // Σφάλμα: Προσπάθεια εξόδου από επίπεδο περιοχής μικρότερο του 0 (δεν θα έπρεπε να συμβεί)
        fprintf(stderr, "DEBUG Scope: Σφάλμα - Προσπάθεια εξόδου από περιοχή κάτω του επιπέδου 0.\n");
        return;
    }

    // Εμφανίζει πληροφορίες αποσφαλμάτωσης πριν την εκκαθάριση της περιοχής
    printf("DEBUG Scope: Έξοδος από επίπεδο περιοχής %d. Πίνακας συμβόλων πριν την εκκαθάριση:\n", current_nesting_level);
    // printSymbolTable(); // Αν απαιτείται, μπορούμε να εμφανίσουμε τον πίνακα συμβόλων αυτού του επιπέδου

    // Επαναφέρει τον αριθμό συμβόλων στο τρέχον επίπεδο περιοχής στο μηδέν
    symbolCountStack[current_nesting_level] = 0;
    // Αν δεν είμαστε ήδη στο εξώτατο επίπεδο, μειώνεται το επίπεδο φωλεοποίησης κατά 1
    if (current_nesting_level > 0)
    {
        current_nesting_level--;
    }

    // Εμφανίζει το νέο επίπεδο περιοχής μετά την έξοδο
    printf("DEBUG Scope: Έξοδος από περιοχή, τρέχον επίπεδο: %d\n", current_nesting_level);
}

// --- Βοηθητική συνάρτηση που επιστρέφει το όνομα του τύπου δεδομένων με βάση την ακέραια ετικέτα ---
const char *typeTagToString(int tag)
{
    switch (tag)
    {
    case TYPE_UNDEFINED:
        return "UNDEFINED"; // Ακαθόριστος τύπος (συνήθως ένδειξη λάθους ή μη αρχικοποιημένου τύπου)
    case TYPE_INTEGER:
        return "INTEGER"; // Ακέραιος τύπος
    case TYPE_REAL:
        return "REAL"; // Πραγματικός τύπος (δεκαδικός αριθμός)
    case TYPE_BOOLEAN:
        return "BOOLEAN"; // Λογικός τύπος (True/False)
    case TYPE_CHAR:
        return "CHAR"; // Χαρακτήρας (π.χ. 'a', 'b', κτλ.)
    case TYPE_STRING:
        return "STRING"; // Συμβολοσειρά χαρακτήρων (π.χ. "hello")
    case TYPE_ARRAY:
        return "ARRAY"; // Πίνακας (συλλογή στοιχείων του ίδιου τύπου)
    case TYPE_COUPLE:
        return "COUPLE"; // Ζεύγος (δομή δύο πραγματικών αριθμών, τύπου couple)
    default:
        return "UNKNOWN_TAG"; // Άγνωστος τύπος (σε περίπτωση που η ετικέτα δεν αντιστοιχεί σε κάποιον γνωστό τύπο)
    }
}

// --- Βοηθητική συνάρτηση που επιστρέφει το είδος ενός συμβόλου με βάση το enum SymbolKind ---
// κάθε σύμβολο (π.χ. μια μεταβλητή, μια σταθερά, μια συνάρτηση, κ.λπ.) ανήκει σε κάποιο
// είδος (ή «κατηγορία»).
// Το SymbolKind είναι ένα enum (απαρίθμηση) που ορίζει
// όλους τους δυνατούς τύπους/είδη που μπορεί να έχει ένα σύμβολο στον μεταγλωττιστή.
// Δηλαδή, η SymbolKind επιστρέφει ως αποτέλεσμα μια συμβολοσειρά (string), όπως
// "VARIABLE" ή "FUNCTION"
const char *symbolKindToString(SymbolKind kind)
{
    switch (kind)
    {
    case SK_UNDEFINED:
        return "UNDEFINED_KIND"; // Ακαθόριστο είδος (πιθανό σφάλμα ή μη αρχικοποιημένο σύμβολο)
    case SK_VARIABLE:
        return "VARIABLE"; // Μεταβλητή (δηλωμένη με δυνατότητα ανάθεσης τιμής)
    case SK_CONSTANT:
        return "CONSTANT"; // Σταθερά (δηλωμένη με σταθερή τιμή που δεν αλλάζει)
    case SK_TYPE_DEF:
        return "TYPE_DEF"; // Ορισμός νέου τύπου (typedef)
    case SK_PROCEDURE:
        return "PROCEDURE"; // Διαδικασία (υπορουτίνα χωρίς τιμή επιστροφής)
    case SK_FUNCTION:
        return "FUNCTION"; // Συνάρτηση (υπορουτίνα που επιστρέφει τιμή)
    default:
        return "UNKNOWN_KIND"; // Άγνωστο είδος συμβόλου (σε περίπτωση σφάλματος ή μη έγκυρης τιμής)
    }
}

// --- Συνάρτηση που εκτυπώνει τον πίνακα συμβόλων για την τρέχουσα εμβέλεια (τρέχον επίπεδο εμφωλευμένων blocks) ---
void printSymbolTable()
{
    // Εμφάνιση επικεφαλίδας με πληροφορίες για το επίπεδο εμβέλειας και τον αριθμό συμβόλων
    printf("\n========= Πίνακας Συμβόλων (Επίπεδο Εμβέλειας: %d, Πλήθος Συμβόλων: %d) =========\n",
           current_nesting_level,
           symbolCountStack[current_nesting_level]);
    // Επικεφαλίδα πινάκων (στήλες)
    printf("| Idx | Όνομα                  | Είδος     | Τύπος     | Λεπτομέρειες (Τιμή/Παράμετροι/Πίνακας)\n");
    printf("|-----|------------------------|-----------|-----------|--------------------------------------------------------------\n");

    // Βρόχος για κάθε σύμβολο στο τρέχον επίπεδο εμβέλειας
    for (int i = 0; i < symbolCountStack[current_nesting_level]; i++)
    {
        Symbol *sym = &symbolTableStack[current_nesting_level][i];
        // Εκτύπωση βασικών στοιχείων: δείκτης, όνομα, είδος, τύπος
        printf("| %-3d | %-22s | %-9s | %-9s | ",
               i,
               sym->name ? sym->name : "N/A",
               symbolKindToString(sym->kind),
               typeTagToString(sym->type_tag_general));
        // Εκτύπωση λεπτομερειών ανάλογα με το είδος συμβόλου
        switch (sym->kind)
        {
        case SK_VARIABLE:
        case SK_CONSTANT:
            // Αν είναι string τύπος και έχει αποθηκευμένη τιμή
            if (sym->type_tag_general == TYPE_STRING && sym->details.string_value)
            {

                printf("Str: \"%.15s...\"", sym->details.string_value); // Εμφανίζει μόνο τα πρώτα 15 χαρακτήρες
            }
            // Αν είναι πίνακας
            else if (sym->type_tag_general == TYPE_ARRAY && sym->details.array_details)
            {
                ArrayDetails *ad = sym->details.array_details;
                printf("ArrBase: %s, %d..%d, %d στοιχεία",
                       typeTagToString(ad->base_type_tag),
                       ad->dim_ranges[0].low,
                       ad->dim_ranges[0].high,
                       ad->total_elements);
            }
            // Απλή αριθμητική τιμή (για int, real κ.λπ.)
            else
            {
                printf("Τιμή: %.2f", sym->details.simple_value);
            }
            break;
        case SK_PROCEDURE:
        case SK_FUNCTION:
            // Αν υπάρχει διαθέσιμη λίστα παραμέτρων
            if (sym->details.subprogram_details)
            {
                SubprogramDetails *sd = sym->details.subprogram_details;
                printf("Παράμετροι: ");

                ParameterDescriptor *param = sd->parameters;
                int param_print_count = 0; // Μετρητής ασφαλείας για αποφυγή ατέρμονου βρόχου

                while (param)
                {
                    // Έλεγχος για αυτοαναφορές (αν ο δείκτης next δείχνει στον εαυτό του)
                    if (param == param->next)

                    {
                        fprintf(stderr, "\nΣΦΑΛΜΑ printSymbolTable: Η παράμετρος '%s' δείχνει στον εαυτό της! Διακοπή εκτύπωσης.\n",
                                param->name ? param->name : "ΑΓΝΩΣΤΟ");
                        printf("... [ΚΑΤΕΣΤΡΑΜΜΕΝΗ ΛΙΣΤΑ] ...");
                        break;
                    }

                    // Εκτύπωση ονόματος, τύπου και τρόπου περάσματος (με ή χωρίς VAR)
                    printf("%s:%s%s ",
                           param->name,

                           typeTagToString(param->type_desc.tag),
                           (param->pass_mode == PASS_BY_REFERENCE ? "(VAR)" : ""));
                    param = param->next;
                    param_print_count++;

                    // Προστασία από πολύ μεγάλες ή κυκλικές λίστες παραμέτρων
                    if (param_print_count > MAX_PARAMETERS + 5)
                    {
                        fprintf(stderr, "\nΣΦΑΛΜΑ printSymbolTable: Υπέρβαση ορίου παραμέτρων (%d) για '%s'. Διακοπή εκτύπωσης.\n",

                                param_print_count, sym->name);
                        printf("... [ΠΟΛΥ ΜΕΓΑΛΗ ΛΙΣΤΑ] ...");
                        break;
                    }
                }

                // Αν είναι συνάρτηση, εκτύπωσε και τον τύπο επιστροφής
                if (sym->kind == SK_FUNCTION)
                {

                    printf("Επιστρέφει: %s", typeTagToString(sd->return_type_desc.tag));
                }

                // Αν πρόκειται για forward δήλωση
                if (sd->is_forward)
                    printf(" (FORWARD)");
            }
            break;
        default:
            printf("N/A"); // Για άγνωστους ή ακαθόριστους τύπους συμβόλων
        }

        printf("\n");
    }

    // Τέλος πίνακα
    printf("================================================================================================================\n\n");
}

// --- Συναρτήσεις διαχείρισης της συνδεδεμένης λίστας ονομάτων (NameList) ---

// Δημιουργεί έναν κόμβο NameList με το όνομα που δίνεται
NameList *createNameNode(char *name)
{
    // Δέσμευση μνήμης για νέο κόμβο
    NameList *node = (NameList *)malloc(sizeof(NameList));
    if (!node)
    {
        fprintf(stderr, "ΣΦΑΛΜΑ: Η malloc απέτυχε για κόμβο NameList με όνομα '%s'\n", name);
        return NULL;
    }

    // Αντιγραφή του ονόματος (για αποφυγή αλλαγών στην αρχική συμβολοσειρά)
    node->name = strdup(name);
    if (!node->name)
    {
        fprintf(stderr, "ΣΦΑΛΜΑ: Η strdup απέτυχε για το όνομα στον κόμβο NameList ('%s')\n", name);
        free(node);
        return NULL;
    }

    // Ο κόμβος δείχνει σε NULL (είναι ο τελευταίος προς το παρόν)
    node->next = NULL;
    // Μήνυμα αποσφαλμάτωσης (debug)
    printf("DEBUG NameList: Δημιουργήθηκε κόμβος με όνομα '%s' στη διεύθυνση %p\n", name, (void *)node);
    return node;
}

// Προσθέτει ένα νέο όνομα στο τέλος της λίστας
NameList *appendName(NameList *list, char *name)
{
    // Δημιουργία νέου κόμβου με το ζητούμενο όνομα
    NameList *newNode = createNameNode(name);
    if (!newNode)
        return list; // Αν ο επόμενος κόμβος στην λίστα είναι κενός επιστρέφεται η λίστα

    // Αν η λίστα είναι άδεια, επιστρέφεται ο νέος κόμβος ως πρώτη εγγραφή
    if (!list)
        return newNode;
    // Εύρεση του τελευταίου κόμβου
    NameList *current = list;
    while (current->next != NULL)
        current = current->next;
    // Σύνδεση του νέου κόμβου στο τέλος της λίστας
    current->next = newNode;
    // Μήνυμα αποσφαλμάτωσης
    printf("DEBUG NameList: Προστέθηκε το όνομα '%s' (κόμβος %p) στο τέλος της λίστας %p\n",
           name, (void *)newNode, (void *)current);
    return list;
}

// Ελευθερώνει όλη τη μνήμη που χρησιμοποιείται από τη λίστα ονομάτων
void freeNameList(NameList *list)
{
    NameList *current = list;
    NameList *next_node;

    // Έναρξη απελευθέρωσης της λίστας
    printf("DEBUG NameList: Ξεκινά η απελευθέρωση της λίστας που αρχίζει στη διεύθυνση %p...\n", (void *)list);
    while (current != NULL)
    {
        next_node = current->next;
        // Μήνυμα για κάθε όνομα που ελευθερώνεται
        printf("DEBUG NameList:   Απελευθέρωση ονόματος '%s' (κόμβος %p)\n", current->name, (void *)current);
        if (current->name)
            free(current->name); // Απελευθέρωση του string ονόματος

        free(current); // Απελευθέρωση του κόμβου
        current = next_node;
    }

    // Τέλος
    printf("DEBUG NameList: Η λίστα ονομάτων απελευθερώθηκε.\n");
}

// --- Συναρτήσεις διαχείρισης της λίστας παραμέτρων (ParameterList) ---

// Δημιουργεί έναν νέο κόμβο παραμέτρου με όνομα, τύπο και τρόπο περάσματος
// Οι τροποι περασματος που χρησιμοποιούμε είναι
// Πέρασμα με τιμή (Pass by Value):Η συνάρτηση δουλεύει με ένα αντίγραφο της τιμής της παραμέτρου.
// Πέρασμα με αναφορά(Pass by Reference: Η συνάρτηση δουλεύει με την ίδια τη μεταβλητή, και οι αλλαγές στην παράμετρο επηρεάζουν την αρχική μεταβλητή)
ParameterDescriptor *createParameterNode(char *name, TypeDescriptor_Bison type_desc, PassMode mode)
{
    // Δέσμευση μνήμης για νέο κόμβο
    ParameterDescriptor *newNode = (ParameterDescriptor *)malloc(sizeof(ParameterDescriptor));
    if (!newNode)
    {
        fprintf(stderr, "ΣΦΑΛΜΑ: Αποτυχία malloc για κόμβο παραμέτρου με όνομα '%s'\n", name);
        return NULL;
    }

    // Αντιγραφή του ονόματος παραμέτρου
    newNode->name = strdup(name);
    if (!newNode->name)
    {
        fprintf(stderr, "ΣΦΑΛΜΑ: Αποτυχία strdup για όνομα παραμέτρου '%s'\n", name);
        free(newNode);
        return NULL;
    }

    // Αντιγραφή τύπου και τρόπου περάσματος
    newNode->type_desc = type_desc;
    newNode->pass_mode = mode;

    // Αρχικοποίηση του δείκτη επόμενου κόμβου
    newNode->next = NULL;
    // Μήνυμα αποσφαλμάτωσης
    printf("DEBUG Params: Δημιουργήθηκε κόμβος παραμέτρου για '%s' (κόμβος %p, επόμενος %p), τύπος %d, τρόπος %s\n",
           name, (void *)newNode, (void *)newNode->next, type_desc.tag,
           (mode == PASS_BY_REFERENCE ? "VAR" : "VALUE"));
    return newNode;
}

// Προσθέτει έναν νέο κόμβο παραμέτρου στο τέλος της λίστας
ParameterDescriptor *appendParameter(ParameterDescriptor *list, ParameterDescriptor *new_param_node)
{
    // Έλεγχος αν ο νέος κόμβος είναι NULL
    if (!new_param_node)
    {
        fprintf(stderr, "DEBUG Params: Κλήθηκε η appendParameter με NULL κόμβο παραμέτρου.\n");
        return list;
    }

    // Μήνυμα αποσφαλμάτωσης
    printf("DEBUG Params: Προσθήκη κόμβου παραμέτρου '%s' (%p, επόμενος %p) στη λίστα %p\n",
           new_param_node->name, (void *)new_param_node, (void *)new_param_node->next, (void *)list);
    // Αν η λίστα είναι κενή, επιστρέφεται ο νέος κόμβος ως αρχή της λίστας
    if (!list)
        return new_param_node;
    // Εύρεση του τελευταίου κόμβου
    ParameterDescriptor *current = list;
    while (current->next != NULL)
    {
        current = current->next;
    }

    // Σύνδεση του νέου κόμβου στο τέλος της λίστας
    current->next = new_param_node;
    return list;
}

// Ελευθερώνει όλη τη μνήμη που καταλαμβάνεται από τη λίστα παραμέτρων
void freeParameterList(ParameterDescriptor *list)
{
    ParameterDescriptor *current = list;
    ParameterDescriptor *next_node;

    printf("DEBUG Params: Ξεκινά η απελευθέρωση της λίστας παραμέτρων από τη διεύθυνση %p...\n", (void *)list);

    int count = 0; // Μετρητής ασφαλείας
    while (current != NULL)
    {
        if (++count > MAX_PARAMETERS + 20)
        {
            fprintf(stderr, "ΣΦΑΛΜΑ: Η freeParameterList εντόπισε πιθανώς κατεστραμμένη λίστα (υπερβολικό μήκος). Διακοπή.\n");
            break;
        }

        next_node = current->next;
        // Μήνυμα αποσφαλμάτωσης για κάθε κόμβο
        printf("DEBUG Params:   Απελευθέρωση παραμέτρου '%s' (κόμβος %p, επόμενος %p)\n",
               current->name, (void *)current, (void *)current->next);
        if (current->name)
            free(current->name); // Απελευθέρωση μνήμης για το όνομα

        free(current); // Απελευθέρωση του κόμβου

        current = next_node;
    }

    printf("DEBUG Params: Η λίστα παραμέτρων απελευθερώθηκε.\n");
}

// --- Συναρτήσεις Διαχείρισης Πίνακα Συμβόλων (με υποστήριξη επιπέδων εμφωλευμένων περιοχών) ---

// Αναζητά ένα σύμβολο με το όνομα name, είτε μόνο στο τρέχον επίπεδο εμφώλευσης είτε και στα εξωτερικά επίπεδα
int lookupSymbol(char *name, int search_outer_scopes)
{
    // Ξεκινάμε την αναζήτηση από το τρέχον επίπεδο εμφώλευσης προς τα έξω
    for (int level = current_nesting_level; level >= 0; level--)
    {
        // Ελέγχουμε κάθε σύμβολο στο συγκεκριμένο επίπεδο
        for (int i = 0; i < symbolCountStack[level]; i++)

        {
            if (symbolTableStack[level][i].name != NULL &&
                strcmp(symbolTableStack[level][i].name, name) == 0)
            {
                // Βρέθηκε το σύμβολο - επιστρέφουμε τη θέση του
                printf("DEBUG SymbolTable: Βρέθηκε το '%s' στο επίπεδο %d, θέση %d.\n", name,
                       level, i);
                return i;
            }
        }

        // Αν επιτρέπεται αναζήτηση μόνο στο τρέχον επίπεδο, σταματάμε εδώ
        if (!search_outer_scopes)
        {
            break;
        }
        // Αν επιτρέπεται αναζήτηση και σε εξωτερικά επίπεδα, συνεχίζουμε μέχρι το επίπεδο 0
    }

    // Δεν βρέθηκε το σύμβολο
    printf("DEBUG SymbolTable: Το σύμβολο '%s' δεν βρέθηκε (έγινε αναζήτηση εξωτερικών: %d, τρέχον επίπεδο: %d).\n",
           name, search_outer_scopes, current_nesting_level);
    return -1;
}

// Προσθέτει ένα νέο σύμβολο στον πίνακα συμβόλων του τρέχοντος επιπέδου
int addSymbol(char *name, SymbolKind kind, TypeDescriptor_Bison *type_desc, void *specific_details,
              PassMode param_mode_from_declaration,
              int ref_level, int ref_offset, Symbol *ref_sym_ptr)
{
    int current_scope_symbol_count = symbolCountStack[current_nesting_level];
    // Έλεγχος υπερχείλισης πίνακα συμβόλων στο τρέχον επίπεδο
    if (current_scope_symbol_count >= MAX_SYMBOLS)
    {
        fprintf(stderr, "%s:%d: Σφάλμα: Ο πίνακας συμβόλων του επιπέδου %d είναι πλήρης. Δεν μπορεί να προστεθεί το '%s'.\n",
                input_filename, yylineno, current_nesting_level, name);
        return -1;
    }

    // Έλεγχος αν το σύμβολο υπάρχει ήδη στο τρέχον επίπεδο
    for (int i = 0; i < current_scope_symbol_count; i++)
    {
        if (symbolTableStack[current_nesting_level][i].name != NULL &&
            strcmp(symbolTableStack[current_nesting_level][i].name, name) == 0)
        {
            Symbol *existing_sym = &symbolTableStack[current_nesting_level][i];
            // Επιτρέπεται η επανεισαγωγή μόνο στην περίπτωση που πρόκειται για forward δήλωση
            // Forward δήλωση είναι μια προκαταρκτική δήλωση μιας συνάρτησης ή διαδικασίας, που ενημερώνει
            // τον μεταγλωττιστή μας για την ύπαρξή της, χωρίς όμως να δίνει την πλήρη υλοποίηση (σώμα) της.
            if (!((existing_sym->kind == SK_FUNCTION || existing_sym->kind == SK_PROCEDURE) &&
                  existing_sym->details.subprogram_details &&
                  existing_sym->details.subprogram_details->is_forward))
            {
                // Αν δεν είναι forward, πρόκειται για επαναδήλωση στο ίδιο επίπεδο - σφάλμα

                fprintf(stderr, "%s:%d: Σφάλμα: Το σύμβολο '%s' έχει ήδη δηλωθεί στο επίπεδο %d.\n",
                        input_filename, yylineno, name, current_nesting_level);
                return i;
            }

            // Αν είναι forward δήλωση, έχουμε βάλει να επιτρέπεται η "επανεισαγωγή" για συμπλήρωση
            // των στοιχείων της
            // Σε αυτή την περίπτωση, ορίζεται από την γραμματική ότι πρέπει πρώτα να γίνει lookup και μετά update
        }
    }

    int current_idx = current_scope_symbol_count;
    // Δείκτης για τον νέο σύμβολο, τοποθετείται στην πρώτη κενή θέση του τρέχοντος επιπέδου

    Symbol *new_sym = &symbolTableStack[current_nesting_level][current_idx];
    // Δημιουργία νέας εγγραφής συμβόλου στη στοίβα συμβόλων στο τρέχον επίπεδο

    new_sym->name = strdup(name); // strdup αντιγράφει μια συμβολοσειρά
    // Αντιγραφή του ονόματος συμβόλου (δημιουργία νέας μνήμης για το όνομα)

    if (!new_sym->name)
    {
        fprintf(stderr, "Αποτυχία κατανομής μνήμης για το όνομα συμβόλου '%s'\n", name);
        return -1;
    }

    new_sym->kind = kind;
    // Καθορισμός είδους συμβόλου (π.χ. μεταβλητή, συνάρτηση κλπ)

    new_sym->nesting_level = current_nesting_level;
    // Καταχώρηση του τρέχοντος επιπέδου εμφώλευσης (scope level)

    new_sym->offset = current_idx;
    // **ΝΕΑ ΑΝΑΘΕΣΗ ΓΙΑ ΤΟ OFFSET**
    // Το offset εδώ απλά παίρνει την τρέχουσα θέση στον πίνακα συμβόλων

    new_sym->type_tag_general = (type_desc ? type_desc->tag : TYPE_UNDEFINED);
    // Καθορισμός γενικού τύπου δεδομένων, αν υπάρχει, αλλιώς ορίζεται ως undefined

    new_sym->details.simple_value = 0.0;
    new_sym->details.string_value = NULL;
    new_sym->details.array_details = NULL;
    new_sym->details.subprogram_details = NULL;
    // Αρχικοποίηση των ειδικών πεδίων του συμβόλου με προεπιλεγμένες τιμές

    printf("DEBUG SymbolTable: Προσθήκη συμβόλου '%s', είδος %s, τύπος %d, επίπεδο %d, offset %d, δείκτης %d\n",
           name, symbolKindToString(kind), new_sym->type_tag_general, current_nesting_level, new_sym->offset, current_idx);
    if (kind == SK_VARIABLE && type_desc)
    {
        if (type_desc->tag == TYPE_ARRAY)
        {
            // Αν το σύμβολο είναι πίνακας, πρέπει να δεσμευτεί και να αρχικοποιηθεί η δομή που περιγράφει τον πίνακα
            if (new_sym->details.array_details == NULL)
            {
                // Αν δεν έχει ήδη δεσμευτεί μνήμη, τη δεσμεύουμε τώρα
                new_sym->details.array_details = (ArrayDetails *)calloc(1, sizeof(ArrayDetails));
            }

            if (!new_sym->details.array_details)
            {
                fprintf(stderr, "Αποτυχία κατανομής μνήμης για λεπτομέρειες πίνακα '%s'\n", name);
                free(new_sym->name);
                return -1;
            }

            ArrayDetails *ad = new_sym->details.array_details;

            ad->base_type_tag = type_desc->base_type_tag;
            ad->num_dimensions = type_desc->num_dimensions;

            if (ad->num_dimensions <= 0 || ad->num_dimensions > MAX_DIMENSIONS)
            {
                fprintf(stderr, "%s:%d: Σφάλμα: Μη έγκυρος αριθμός διαστάσεων (%d) για τον πίνακα '%s'. Μέγιστο %d.\n",
                        input_filename, yylineno, ad->num_dimensions, name, MAX_DIMENSIONS);
                free(ad);
                new_sym->details.array_details = NULL;
                free(new_sym->name);
                return -1;
            }

            ad->total_elements = 1;
            for (int k = 0; k < ad->num_dimensions; ++k)
            {
                ad->dim_ranges[k] = type_desc->dim_ranges[k];
                // Αντιγραφή των ορίων κάθε διάστασης

                if (ad->dim_ranges[k].low > ad->dim_ranges[k].high)
                {
                    fprintf(stderr, "%s:%d: Σφάλμα: Ο πίνακας '%s', διάσταση %d, έχει μη έγκυρα όρια %d..%d\n",
                            input_filename, yylineno, name, k + 1, ad->dim_ranges[k].low, ad->dim_ranges[k].high);
                    free(ad);
                    new_sym->details.array_details = NULL;
                    free(new_sym->name);
                    return -1;
                }

                // Υπολογισμός συνολικών στοιχείων πολλαπλασιάζοντας το εύρος κάθε διάστασης
                ad->total_elements *= (ad->dim_ranges[k].high - ad->dim_ranges[k].low + 1);
            }

            ad->element_size = sizeof(double);
            // Προσωρινά, θεωρούμε τα στοιχεία τύπου double

            ad->data = calloc(ad->total_elements, ad->element_size);
            if (!ad->data)
            {
                fprintf(stderr, "Αποτυχία κατανομής αποθηκευτικού χώρου για τον πίνακα '%s' (στοιχεία: %d)\n", name, ad->total_elements);
                free(ad);
                new_sym->details.array_details = NULL;
                free(new_sym->name);
                return -1;
            }
            // Τα δεδομένα μηδενίζονται αυτόματα από το calloc
            // calloc μηδενίζει ουσιαστικά την δεσμευμένη μνήμη
            printf("DEBUG SymbolTable: Πίνακας '%s' δεσμεύτηκε. Διαστάσεις: %d, Συνολικά στοιχεία: %d, Βασικός τύπος: %s. Πρώτη διάσταση: %d..%d\n",
                   name, ad->num_dimensions, ad->total_elements, typeTagToString(ad->base_type_tag),
                   (ad->num_dimensions > 0 ? ad->dim_ranges[0].low : -1),

                   (ad->num_dimensions > 0 ? ad->dim_ranges[0].high : -1));
        }
    }
    else if (kind == SK_FUNCTION || kind == SK_PROCEDURE)
    {
        // Τα επιπλέον στοιχεία υποπρογράμματος διαχειρίζεται ο καλών κώδικας ( Bison)
        new_sym->details.subprogram_details = (SubprogramDetails *)specific_details;
        if (new_sym->details.subprogram_details)
        {
            // Αν το σύμβολο είναι συνάρτηση, ενημερώνουμε τον γενικό τύπο επιστροφής
            if (kind == SK_FUNCTION)
            {
                new_sym->type_tag_general = new_sym->details.subprogram_details->return_type_desc.tag;
            }

            printf("DEBUG SymbolTable: Υποπρόγραμμα '%s' προστέθηκε. Forward: %d. Λίστα παραμέτρων στο %p\n",
                   name,
                   new_sym->details.subprogram_details->is_forward,
                   (void *)new_sym->details.subprogram_details->parameters);
        }
        else
        {
            printf("DEBUG SymbolTable: Υποπρόγραμμα '%s' προστέθηκε αλλά τα συγκεκριμένα στοιχεία ήταν NULL.\n", name);
        }
    }

    symbolCountStack[current_nesting_level]++;
    // Αύξηση του πλήθους συμβόλων στο τρέχον επίπεδο

    printSymbolTable();
    // Εκτύπωση της τρέχουσας κατάστασης του πίνακα συμβόλων (για debug)

    return current_idx;
    // Επιστροφή της θέσης όπου προστέθηκε το νέο σύμβολο
}
int addVariableSymbol(char *name, TypeDescriptor_Bison *type_desc)
{
    // Μια κανονική μεταβλητή δεν είναι παράμετρος και δεν περνιέται με κάποιον τρόπο.
    // Επίσης, δεν αναφέρεται σε κάποιο άλλο σύμβολο μέσω VAR.
    // Οπότε, περνάμε ουδέτερες/default τιμές για τις νέες παραμέτρους.
    // Έχουμε ορίσει το PASS_MODE_NOT_A_PARAMETER στο enum PassMode.
    return addSymbol(name, SK_VARIABLE, type_desc, NULL,
                     PASS_MODE_NOT_A_PARAMETER, // Δεν είναι παράμετρος ή δεν ισχύει ο τρόπος περάσματος
                     -1,                        // ref_level: Δεν ισχύει

                     -1,  // ref_offset: Δεν ισχύει
                     NULL // ref_sym_ptr: Δεν ισχύει
    );
}

// Αναζήτηση συμβόλου με όνομα 'name' σε όλα τα επίπεδα φώλιασης (nesting levels)
// Αν βρεθεί, επιστρέφει δείκτη στο σύμβολο και ενημερώνει, αν δοθούν, τις διευθύνσεις found_level_ptr και found_offset_ptr
Symbol *findSymbol(char *name, int *found_level_ptr, int *found_offset_ptr)
{
    // Ξεκινάμε από το τρέχον επίπεδο φώλιασης και πάμε προς τα έξω (προς 0)
    for (int level = current_nesting_level; level >= 0; level--)
    {
        // Ελέγχουμε όλα τα σύμβολα στο συγκεκριμένο επίπεδο
        for (int i = 0; i < symbolCountStack[level]; i++)

        {
            // Αν το όνομα του συμβόλου δεν είναι κενό και ταιριάζει με το ζητούμενο
            if (symbolTableStack[level][i].name != NULL && strcmp(symbolTableStack[level][i].name, name) == 0)
            {
                // Αν δόθηκε διεύθυνση για αποθήκευση επιπέδου, την ενημερώνουμε

                if (found_level_ptr)
                    *found_level_ptr = level;
                // Αν δόθηκε διεύθυνση για αποθήκευση θέσης (offset), την ενημερώνουμε
                if (found_offset_ptr)
                    *found_offset_ptr = i;
                // Επιστρέφουμε δείκτη στο βρεθέν σύμβολο
                return &symbolTableStack[level][i];
            }
        }
    }
    // Αν δεν βρέθηκε, ενημερώνουμε τις διευθύνσεις με -1 αν δόθηκαν
    if (found_level_ptr)
        *found_level_ptr = -1;
    if (found_offset_ptr)
        *found_offset_ptr = -1;
    // Επιστρέφουμε NULL για να δείξουμε ότι δεν βρέθηκε
    return NULL;
}

// Προσθήκη συμβόλου σταθεράς (constant) στον πίνακα συμβόλων
int addConstantSymbol(char *name, TypeDescriptor_Bison *type_desc, double value)
{
    // Μια σταθερά δεν είναι παράμετρος, οπότε περνάμε ουδέτερες τιμές στις παραμέτρους της addSymbol
    // Η SK_CONSTANT προσδιορίζει το είδος (kind) ενός συμβόλου στον πίνακα συμβόλων,σταθερες
    int idx = addSymbol(name, SK_CONSTANT, type_desc, NULL,
                        PASS_MODE_NOT_A_PARAMETER, // Δεν είναι παράμετρος

                        -1, // ref_level: δεν ισχύει
                        -1, // ref_offset: δεν ισχύει

                        NULL // ref_sym_ptr: δεν ισχύει
    );
    // Αν η προσθήκη ήταν επιτυχής και το επίπεδο φώλιασης είναι έγκυρο
    if (idx != -1 && current_nesting_level >= 0 && idx < symbolCountStack[current_nesting_level])
    {
        // Ορίζουμε την τιμή της σταθεράς στο πεδίο simple_value
        symbolTableStack[current_nesting_level][idx].details.simple_value = value;
        // Εμφανίζουμε ενημερωτικό μήνυμα για debug
        printf("DEBUG SymbolTable: Constant '%s' (L%d,O%d) set to value %f\n",
               name,
               symbolTableStack[current_nesting_level][idx].nesting_level,
               symbolTableStack[current_nesting_level][idx].offset,
               value);
    }
    return idx;
}

// Προσθήκη συμβόλου υποπρογράμματος (function ή procedure)
int addSubprogramSymbol(char *name, SymbolKind kind, SubprogramDetails *sub_details_ptr)
{
    // Έλεγχος για NULL sub_details_ptr ειδικά για συναρτήσεις/διαδικασίες
    if (!sub_details_ptr && (kind == SK_FUNCTION || kind == SK_PROCEDURE))
    {
        fprintf(stderr, "Προειδοποίηση: Η addSubprogramSymbol κλήθηκε για '%s' χωρίς λεπτομέρειες υποπρογράμματος.\n", name);
    }

    // Το υποπρόγραμμα δεν είναι παράμετρος και δεν χρησιμοποιεί μηχανισμούς αναφοράς
    return addSymbol(name, // Όνομα
                     kind, // Είδος (function ή procedure)

                     NULL,                      // Περιγραφή τύπου (δεν το χρειαζόμαστε εδώ)
                     (void *)sub_details_ptr,   // Λεπτομέρειες υποπρογράμματος
                     PASS_MODE_NOT_A_PARAMETER, // Δεν είναι παράμετρος

                     -1, // ref_level: δεν ισχύει
                     -1, // ref_offset: δεν ισχύει

                     NULL // ref_sym_ptr: δεν ισχύει
                          // Τα τρία αυτά πεδία: ref_level, ref_offset και ref_sym_ptr είναι μηχανισμοί αναφοράς
                          // σε άλλο σύμβολο, και χρησιμοποιούνται μόνο όταν ένα σύμβολο αναπαριστά
                          // παράμετρο που περνάει με αναφορά (pass-by-reference) — π.χ. procedure f(var x: integer).
                          // Εμείς έχουμε βάλει -1 γιατί δεν δείχνει κάπου τώρα
    );
}

// Ενημέρωση της τιμής ενός συμβόλου μεταβλητής
void updateSymbolValue(char *name, double value)
{
    // Ψάχνουμε από το τρέχον επίπεδο φώλιασης προς τα έξω
    for (int search_level = current_nesting_level; search_level >= 0; search_level--)
    {
        for (int i = 0; i < symbolCountStack[search_level]; i++)
        {
            // Αν βρούμε το σύμβολο με το ζητούμενο όνομα
            if (symbolTableStack[search_level][i].name != NULL &&
                strcmp(symbolTableStack[search_level][i].name, name) == 0)
            {
                Symbol *sym = &symbolTableStack[search_level][i];
                // Έλεγχος εσωτερικής συνέπειας των δεδομένων
                if (sym->nesting_level != search_level || sym->offset != i)
                {
                    fprintf(stderr, "ΚΡΙΣΙΜΟ: Ασυνέπεια στα δεδομένα του συμβόλου '%s' κατά την ενημέρωση.\n", name);
                }

                // Έλεγχος αν το σύμβολο είναι μεταβλητή, γιατί μόνο αυτές μπορούν να πάρουν νέα τιμή
                if (sym->kind != SK_VARIABLE)
                {
                    fprintf(stderr, "%s:%d: Σφάλμα: Το σύμβολο '%s' δεν είναι μεταβλητή, δεν μπορεί να ανατεθεί τιμή.\n",

                            input_filename, yylineno, name);
                    return;
                }

                // Δεν επιτρέπεται η απευθείας ανάθεση σε πίνακες ή ζεύγη με αυτή τη συνάρτηση
                if (sym->type_tag_general == TYPE_ARRAY || sym->type_tag_general == TYPE_COUPLE)
                {
                    fprintf(stderr, "%s:%d: Σφάλμα: Απαγορεύεται η ανάθεση τιμής σε πίνακα/ζεύγος '%s' με "
                                    "αυτή τη συνάρτηση.\n",
                            input_filename, yylineno, name);
                    return;
                }

                // Ορισμός της τιμής
                sym->details.simple_value = value;
                // Μήνυμα debug
                printf("DEBUG SymbolTable: Ανάθεση τιμής %.2f στο σύμβολο '%s' (επίπεδο %d, θέση %d).\n",
                       value, name, sym->nesting_level, sym->offset);
                return;
            }
        }
    }
    // Αν δεν βρέθηκε το σύμβολο, εμφανίζουμε μήνυμα λάθους
    fprintf(stderr, "%s:%d: Σφάλμα: Ανάθεση σε μη δηλωμένη μεταβλητή '%s'\n", input_filename, yylineno, name);
}

// Λήψη της τιμής ενός συμβόλου (μεταβλητής ή σταθεράς)
double getSymbolValue(char *name)
{
    // Ψάχνουμε από το τρέχον επίπεδο φώλιασης προς τα έξω
    for (int search_level = current_nesting_level; search_level >= 0; search_level--)
    {
        for (int i = 0; i < symbolCountStack[search_level]; i++)
        {
            // Βρίσκουμε το σύμβολο με το ζητούμενο όνομα
            if (symbolTableStack[search_level][i].name != NULL && strcmp(symbolTableStack[search_level][i].name,
                                                                         name) == 0)
            {
                Symbol *sym = &symbolTableStack[search_level][i];
                // Έλεγχος συνέπειας δεδομένων
                if (sym->nesting_level != search_level || sym->offset != i)
                {
                    fprintf(stderr, "ΚΡΙΣΙΜΟ: Ασυνέπεια στα δεδομένα του συμβόλου '%s'.\n", name);
                }

                // Ελέγχουμε ότι είναι μεταβλητή ή σταθερά για να επιστρέψουμε τιμή
                if (sym->kind != SK_VARIABLE && sym->kind != SK_CONSTANT)
                {
                    fprintf(stderr, "%s:%d: Σφάλμα: Το σύμβολο '%s' δεν είναι μεταβλητή ή σταθερά, δεν μπορεί να ληφθεί τιμή.\n",
                            input_filename,
                            yylineno, name);
                    return 0.0;
                }

                // Δεν επιτρέπεται η λήψη απλής τιμής από πίνακα ή ζεύγος με αυτή τη συνάρτηση
                if (sym->type_tag_general == TYPE_ARRAY || sym->type_tag_general == TYPE_COUPLE)
                {
                    fprintf(stderr, "%s:%d: Σφάλμα: Απαγορεύεται η λήψη απλής τιμής από πίνακα / ζεύγος '%s'.\n ",
                            input_filename,
                            yylineno, name);
                    return 0.0;
                }

                // Μήνυμα debug
                printf("DEBUG SymbolTable: Ανάκτηση τιμής %.2f για το σύμβολο '%s' (επίπεδο %d, θέση %d).\n",
                       sym->details.simple_value, name, sym->nesting_level, sym->offset);
                return sym->details.simple_value;
            }
        }
    }
    // Αν δεν βρέθηκε το σύμβολο, εμφανίζουμε σφάλμα και επιστρέφουμε 0.0
    fprintf(stderr, "%s:%d: Σφάλμα: Χρήση μη δηλωμένης μεταβλητής '%s'\n", input_filename, yylineno, name);
    return 0.0;
}

// Συνάρτηση για ανάκτηση τιμής στοιχείου πίνακα βάσει του ονόματος και των δεικτών που δίνει ο χρήστης
double getArrayElementValue(char *array_name, IndexList *user_indices)
{
    int found_level = -1;
    int sym_idx_in_level = -1;

    // Αναζήτηση πίνακα στη στοίβα πινάκων συμβόλων, από το τρέχον εσωτερικό επίπεδο
    // προς τα έξω
    for (int level = current_nesting_level; level >= 0; level--)
    {
        for (int i = 0; i < symbolCountStack[level]; i++)
        {
            if (symbolTableStack[level][i].name != NULL && strcmp(symbolTableStack[level][i].name, array_name) == 0)
            {

                sym_idx_in_level = i;
                found_level = level;
                goto found_array_for_get_md; // Πίνακας βρέθηκε, έξοδος από τους βρόχους
                                             // Βάλαμε go to για να βγούμε κατευθείαν από τα δυο for
            }
        }
    }
// Ο κώδικας ψάχνει σε όλα τα επίπεδα εμφωλευμένου scope (από το πιο εσωτερικό προς το
//
//  πιο εξωτερικό) για να βρει ένα σύμβολο πίνακα με όνομα array_name.
//  Όταν το βρει:
// Καταγράφει τη θέση του (δείκτης πίνακα και επίπεδο),
// Και κάνει goto found_array_for_get_md, δηλαδή πηδά κατευθείαν έξω από τα δύο for,
//  στο σημείο όπου θα γίνει ο περαιτέρω έλεγχος του πίνακα και υπολογισμός.
found_array_for_get_md:
    // Αν δεν βρέθηκε ο πίνακας, εμφάνιση σφάλματος
    if (sym_idx_in_level == -1)
    {
        fprintf(stderr, "%s:%d: Σφάλμα: Ο πίνακας '%s' δεν έχει δηλωθεί (στην ανάγνωση).\n", input_filename, yylineno, array_name);
        return 0.0;
    }

    Symbol *sym = &symbolTableStack[found_level][sym_idx_in_level];
    if (sym->kind != SK_VARIABLE || sym->type_tag_general != TYPE_ARRAY || !sym->details.array_details)
    {
        fprintf(stderr, "%s:%d: Σφάλμα: Το '%s' δεν είναι πίνακας ή λείπουν τα στοιχεία του πίνακα.\n", input_filename, yylineno, array_name);
        return 0.0;
    }

    ArrayDetails *details = sym->details.array_details;
    // Έλεγχος αν ο αριθμός των δεικτών του χρήστη είναι σωστός
    if (user_indices->count != details->num_dimensions)
    {
        fprintf(stderr, "%s:%d: Σφάλμα: Λάθος αριθμός δεικτών για τον πίνακα '%s'. Αναμένονταν %d, δόθηκαν %d.\n",
                input_filename, yylineno, array_name, details->num_dimensions, user_indices->count);
        return 0.0;
    }

    // Υπολογισμός της θέσης (offset) του στοιχείου στον πίνακα βάσει row-major
    // αποθήκευσης
    int calculated_offset = 0;
    int multiplier = 1;

    for (int d = details->num_dimensions - 1; d >= 0; d--)
    {
        int current_user_index = user_indices->indices[d];
        int dim_low = details->dim_ranges[d].low;
        int dim_high = details->dim_ranges[d].high;

        // Έλεγχος αν ο δείκτης είναι εντός ορίων
        if (current_user_index < dim_low || current_user_index > dim_high)
        {
            fprintf(stderr, "%s:%d: Σφάλμα: Ο δείκτης %d για τον πίνακα '%s' (διάσταση %d) είναι εκτός ορίων (%d..%d).\n",
                    input_filename, yylineno, current_user_index, array_name, d + 1, dim_low, dim_high);
            return 0.0;
        }

        int normalized_index = current_user_index - dim_low;
        calculated_offset += normalized_index * multiplier;
        multiplier *= (dim_high - dim_low + 1);
    }

    // Έλεγχος εγκυρότητας του offset
    if (calculated_offset < 0 || calculated_offset >= details->total_elements)
    {
        fprintf(stderr, "%s:%d: Σφάλμα: Το offset %d για τον πίνακα '%s' είναι εκτός επιτρεπτού εύρους [0..%d).\n",
                input_filename, yylineno, calculated_offset, array_name, details->total_elements);
        return 0.0;
    }

    // Ανάκτηση της τιμής του στοιχείου (υποθέτουμε τύπο double)
    double val = ((double *)details->data)[calculated_offset];
    printf("DEBUG ArrayAccess: Ανάγνωση τιμής %f από τον πίνακα '%s' (επίπεδο %d) στη θέση %d (Δείκτες χρήστη: [", val, array_name, found_level, calculated_offset);
    for (int k = 0; k < user_indices->count; ++k)
        printf("%d%s", user_indices->indices[k], (k == user_indices->count - 1) ? "" : ", ");
    printf("])\n");
    return val;
}

// Συνάρτηση για απελευθέρωση όλων των δεδομένων του πίνακα συμβόλων από όλες τις εμβελείες
void freeGlobalSymbolTableData()
{
    printf("DEBUG SymbolTable: Απελευθέρωση όλων των δεδομένων του πίνακα συμβόλων από όλες τις εμβελείες...\n");
    for (int level = 0; level < MAX_NESTING_DEPTH; ++level)
    {
        if (symbolCountStack[level] > 0)
        {
            printf("DEBUG SymbolTable: Απελευθέρωση επιπέδου εμβέλειας %d (Σύμβολα: %d)...\n", level, symbolCountStack[level]);
        }
        for (int i = 0; i < symbolCountStack[level]; i++)
        {
            Symbol *sym_to_free = &symbolTableStack[level][i];
            if (sym_to_free->name)
            {
                printf("  Απελευθέρωση ονόματος: %s\n", sym_to_free->name);
                free(sym_to_free->name);
                sym_to_free->name = NULL;
            }
            if (sym_to_free->kind == SK_VARIABLE)
            {
                if (sym_to_free->type_tag_general == TYPE_STRING && sym_to_free->details.string_value)
                {
                    printf("  Απελευθέρωση string_value για %s\n", sym_to_free->name ? sym_to_free->name : "ΑΓΝΩΣΤΟ");
                    free(sym_to_free->details.string_value);
                    sym_to_free->details.string_value = NULL;
                }
                if (sym_to_free->type_tag_general == TYPE_ARRAY && sym_to_free->details.array_details)
                {
                    printf("  Απελευθέρωση array_details για %s\n", sym_to_free->name ? sym_to_free->name : "ΑΓΝΩΣΤΟ");
                    if (sym_to_free->details.array_details->data)
                    {
                        free(sym_to_free->details.array_details->data);
                    }
                    free(sym_to_free->details.array_details);
                    sym_to_free->details.array_details = NULL;
                }
            }
            else if (sym_to_free->kind == SK_FUNCTION || sym_to_free->kind == SK_PROCEDURE)
            {
                if (sym_to_free->details.subprogram_details)
                {

                    printf("  Απελευθέρωση subprogram_details για %s\n", sym_to_free->name ? sym_to_free->name : "ΑΓΝΩΣΤΟ");
                    printf("  Κλήση freeParameterList για τις παραμέτρους του %s στη διεύθυνση %p\n", sym_to_free->name ? sym_to_free->name : "ΑΓΝΩΣΤΟ", (void *)sym_to_free->details.subprogram_details->parameters);
                    freeParameterList(sym_to_free->details.subprogram_details->parameters);
                    free(sym_to_free->details.subprogram_details);
                    sym_to_free->details.subprogram_details = NULL;
                }
            }
        }
        symbolCountStack[level] = 0;
    }
    printf("DEBUG SymbolTable: Όλα τα δεδομένα του πίνακα συμβόλων απελευθερώθηκαν.\n");
}

// Συνάρτηση για αποθήκευση τιμής σε στοιχείο πίνακα
void setArrayElementValue(char *array_name, IndexList *user_indices, double value)
{
    int found_level = -1;
    int sym_idx_in_level = -1;

    // Αναζήτηση πίνακα
    for (int level = current_nesting_level; level >= 0; level--)
    {
        for (int i = 0; i < symbolCountStack[level]; i++)
        {
            if (symbolTableStack[level][i].name != NULL && strcmp(symbolTableStack[level][i].name, array_name) == 0)
            {
                sym_idx_in_level = i;
                found_level = level;
                goto found_array_for_set_md;
            }
        }
    }

found_array_for_set_md:
    if (sym_idx_in_level == -1)
    {
        fprintf(stderr, "%s:%d: Σφάλμα: Ο πίνακας '%s' δεν έχει δηλωθεί (στην εγγραφή).\n", input_filename, yylineno, array_name);
        return;
    }

    Symbol *sym = &symbolTableStack[found_level][sym_idx_in_level];
    if (sym->kind != SK_VARIABLE || sym->type_tag_general != TYPE_ARRAY || !sym->details.array_details)
    {
        fprintf(stderr, "%s:%d: Σφάλμα: Το '%s' δεν είναι πίνακας ή λείπουν τα στοιχεία του πίνακα (στην εγγραφή).\n", input_filename, yylineno, array_name);
        return;
    }

    ArrayDetails *details = sym->details.array_details;

    if (user_indices->count != details->num_dimensions)
    {
        fprintf(stderr, "%s:%d: Σφάλμα: Λάθος αριθμός δεικτών για τον πίνακα '%s'. Αναμένονταν %d, δόθηκαν %d.\n",
                input_filename, yylineno, array_name, details->num_dimensions, user_indices->count);
        return;
    }

    int calculated_offset = 0;
    int multiplier = 1;
    for (int d = details->num_dimensions - 1; d >= 0; d--)
    {
        int current_user_index = user_indices->indices[d];
        int dim_low = details->dim_ranges[d].low;
        int dim_high = details->dim_ranges[d].high;

        if (current_user_index < dim_low || current_user_index > dim_high)
        {
            fprintf(stderr, "%s:%d: Σφάλμα: Ο δείκτης %d για τον πίνακα '%s' (διάσταση %d) είναι εκτός ορίων (%d..%d).\n",
                    input_filename, yylineno, current_user_index, array_name, d + 1, dim_low, dim_high);
            return;
        }
        int normalized_index = current_user_index - dim_low;
        calculated_offset += normalized_index * multiplier;
        multiplier *= (dim_high - dim_low + 1);
    }

    if (calculated_offset < 0 || calculated_offset >= details->total_elements)
    {
        fprintf(stderr, "%s:%d: Σφάλμα: Το offset %d για τον πίνακα '%s' είναι εκτός επιτρεπτού εύρους [0..%d).\n",
                input_filename, yylineno, calculated_offset, array_name, details->total_elements);
        return;
    }

    ((double *)details->data)[calculated_offset] = value;
    printf("DEBUG ArrayAccess: Εγγραφή τιμής %f στον πίνακα '%s' (επίπεδο %d) στη θέση %d (Δείκτες χρήστη: [", value, array_name, found_level, calculated_offset);
    for (int k = 0; k < user_indices->count; ++k)
        printf("%d%s", user_indices->indices[k], (k == user_indices->count - 1) ? "" : ", ");
    printf("])\n");
}

// Συντόμευση για την απελευθέρωση όλων των πινάκων συμβόλων
void freeSymbolTableData()
{
    freeGlobalSymbolTableData();
}
