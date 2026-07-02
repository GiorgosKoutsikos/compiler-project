PROGRAM TestNestingAndOffsets;

VAR
    globalVar : INTEGER; // Αναμένεται: level 0, offset (π.χ., 0 αν είναι η πρώτη)

PROCEDURE OuterProc; // Η ίδια η OuterProc δηλώνεται στο level 0. Το σώμα της είναι level 1.
    VAR
        outerVar1 : INTEGER; // Αναμένεται: level 1, offset (π.χ., 0 σε αυτό το scope)
        outerVar2 : INTEGER; // Αναμένεται: level 1, offset (π.χ., 1 σε αυτό το scope)

    PROCEDURE InnerProc (innerParam : INTEGER); // Η InnerProc δηλώνεται στο level 1. Το σώμα της είναι level 2.
                                            // innerParam: Αναμένεται: level 2, offset (π.χ., 0)
        VAR
            innerVar : INTEGER; // Αναμένεται: level 2, offset (π.χ., 1, μετά την παράμετρο)
    BEGIN // InnerProc
        WRITE("--- Inside InnerProc ---\n");
        innerVar := innerParam + 1000;
        outerVar1 := innerVar + innerParam;   // Πρόσβαση σε μεταβλητή της OuterProc
        globalVar := outerVar1 + outerVar2; // Πρόσβαση σε global και μεταβλητή της OuterProc

        WRITE("InnerProc: innerParam = ", innerParam, "\n");
        WRITE("InnerProc: innerVar = ", innerVar, "\n");
        WRITE("InnerProc: ->  outerVar1 (accessed from Inner) set to = ", outerVar1, "\n");
        WRITE("InnerProc: ->  globalVar (accessed from Inner) set to = ", globalVar, "\n");
    END; // InnerProc

BEGIN // OuterProc Body
    WRITE("--- Inside OuterProc ---\n");
    globalVar := 10;
    outerVar1 := 20;
    outerVar2 := 30;

    WRITE("OuterProc: globalVar (initial) = ", globalVar, "\n");
    WRITE("OuterProc: outerVar1 (initial) = ", outerVar1, "\n");
    WRITE("OuterProc: outerVar2 (initial) = ", outerVar2, "\n");

    InnerProc(200); // Κλήση της InnerProc με innerParam = 200

    WRITE("--- Back in OuterProc (after InnerProc call) ---\n");
    WRITE("OuterProc: globalVar (after InnerProc) = ", globalVar, "\n"); // Θα πρέπει να έχει αλλάξει από την InnerProc
    WRITE("OuterProc: outerVar1 (after InnerProc) = ", outerVar1, "\n"); // Θα πρέπει να έχει αλλάξει από την InnerProc
    WRITE("OuterProc: outerVar2 (remains) = ", outerVar2, "\n");     // Δεν αλλάζει από την InnerProc
END; // OuterProc

BEGIN // Main Program Body
    WRITE("--- Inside Main Program ---\n");
    globalVar := 1; // Αρχική τιμή
    WRITE("Main: globalVar (initial) = ", globalVar, "\n");

    // Έλεγχος της αρχικής τιμής
    IF globalVar = 1 THEN
        WRITE("Main: globalVar is correctly initialized to 1\n")
    ELSE
        WRITE("Main: ERROR - globalVar is not 1!\n");

    // Έλεγχος αν η globalVar είναι θετική
    IF globalVar > 0 THEN
    BEGIN
        WRITE("Main: globalVar is positive, calling OuterProc\n");
        OuterProc; // Κλήση της OuterProc
    END
    ELSE
        WRITE("Main: globalVar is not positive, skipping OuterProc\n");

    WRITE("--- Back in Main Program (after OuterProc call) ---\n");
    WRITE("Main: globalVar (after OuterProc) = ", globalVar, "\n"); // Θα πρέπει να έχει αλλάξει

    // Έλεγχος της τελικής τιμής
    IF globalVar > 100 THEN
        WRITE("Main: Final globalVar is greater than 100\n")
    ELSE IF globalVar > 50 THEN
        WRITE("Main: Final globalVar is between 50 and 100\n")
    ELSE IF globalVar > 0 THEN
        WRITE("Main: Final globalVar is between 1 and 50\n")
    ELSE
        WRITE("Main: Final globalVar is zero or negative\n");

    // Τελικός έλεγχος
    IF globalVar <> 1 THEN
        WRITE("Main: globalVar has been modified successfully!\n")
    ELSE
        WRITE("Main: globalVar was not modified\n");
END.
