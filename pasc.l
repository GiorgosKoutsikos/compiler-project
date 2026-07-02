%{
#include "pasc.tab.h"
#include <stdlib.h>
#include <string.h>
extern int yylineno;
%}

%option noyywrap
%option caseless
%option yylineno

%%
"program"            { return PROGRAM; }
"const"              { return CONST; }
"type"               { return TYPE; }
"couple"             { return COUPLE; }
"array"              { return ARRAY; }
"of"                 { return OF; }
"var"                { return VAR; }
"forward"            { return FORWARD; }
"function"           { return FUNCTION; }
"procedure"          { return PROCEDURE; }
"begin"              { return PASC_BEGIN; }
"end"                { return PASC_END; }
"if"                 { return IF; }
"then"               { return THEN; }
"else"               { return ELSE; }
"while"              { return WHILE; }
"do"                 { return DO; }
"for"                { return FOR; }
"to"                 { return TO; }
"downto"             { return DOWNTO; }
"read"               { return READ; }
"write"              { return WRITE; }
"length"             { return LENGTH; }
"integer"            { return INTEGER; }
"real"               { return REAL; }
"boolean"            { return BOOLEAN; }
"char"               { return CHAR; }
"string"             { return STRING; }
"true"               { yylval.num = 1; return BOOLCONST; }
"false"              { yylval.num = 0; return BOOLCONST; }

 /* Προσθήκη τελεστή για OR */
"or"                  { return OROP; }

 /* Προσθήκη τελεστών για div, mod και and */
"div"                 { return DIV; }
"mod"                 { return MOD; }
"and"                 { return AND; }

 /* Προσθήκη τελεστή για NOT */
"not"                 { return NOTOP; }

 /* Προσθήκη τελεστών για στοιχεία ζεύγους: head και tail */
"head"                { return HEAD; }
"tail"                { return TAIL; }

 /* Προσθήκη για τα σύμβολα αγκύλων */
"["                   { return LBRACK; }
"]"                   { return RBRACK; }

\{[^}]*\}            { } /* Σχόλια με {} */
\/\/[^\n]*           { } /* Σχόλια με // */

(_?[a-zA-Z]([a-zA-Z0-9_]*[a-zA-Z0-9])?) { yylval.str = strdup(yytext); return ID; }

    /* Μη προσημασμένες ακέραιες σταθερές */
"0"                          { yylval.num = 0; return ICONST; }
[1-9][0-9]*                  { yylval.num = atoi(yytext); return ICONST; }
0[xX][1-9A-Fa-f][0-9A-Fa-f]*   { yylval.num = (int)strtol(yytext, NULL, 16); return ICONST; }

    /* Μη προσημασμένες πραγματικές σταθερές (χωρίς τελεία αλλά με πεδίο εκθέτη) */
(([1-9][0-9]*|0)[eE][+-]?[0-9]+)    { yylval.real = atof(yytext); return RCONST; }

    /* Μη προσημασμένες πραγματικές σταθερές (δεκαδικές) */
(([1-9][0-9]*|0)\.[0-9]+([eE][+-]?[0-9]+)?)    { yylval.real = atof(yytext); return RCONST; }
(\.[0-9]+([eE][+-]?[0-9]+)?)                    { yylval.real = atof(yytext); return RCONST; }

    /* Μη προσημασμένες πραγματικές σταθερές (δεκαεξαδικές) */
0[xX](([1-9A-Fa-f][0-9A-Fa-f]*)|0)?\.[0-9A-Fa-f]+([eE][+-]?[0-9]+)?  { yylval.real = strtod(yytext, NULL); return RCONST; }

 /*Χαρακτήρες: Επεξεργάζεται χαρακτήρες όπως 'a', '\\', '\n','\''*/
 /*Αναγνωρίζει δηλαδή λεκτικές μονάδες τύπου CCONST*/
\'(\\.|[^'\\])\' { 
                    /*  \' αρχίζει με ένα ' ,μετά ακολουθείτε με ένα από τα δύο */
                    /*είτε αυτό (\\.|[^'  είτε \\.: δηλαδή backslash ακολουθούμενο από ΟΠΟΙΟΔΗΠΟΤΕ χαρακτήρα (π.χ. \n, \t, \')*/
                    /*και \'   τελειώνει με ένα '*/
                   
                   if (yytext[1] == '\\') { /* Ελέγχουμε αν είναι ένας escape sequence όπως '\n' */
                   /*Αφού ισχύει η if, τότε ελέγχεται το τρίτο γράμμα yytext[2],δηλαδή το γράμμα με το \*/
                   /*Η switch αναγνωρίζει γνωστές escape ακολουθίες: */
                       switch (yytext[2]) {
                           case 'n':  yylval.ch = '\n'; break;
                           case 't':  yylval.ch = '\t'; break; /* Tab */
                           case '\\': yylval.ch = '\\'; break; /* Backslash */
                           case '\'': yylval.ch = '\''; break; /* Single quote */
                           
                           default: yylval.ch = yytext[2]; break; 
                       }
                   } else { /*Σε αυτή την περίπτωση δεν έχουμε escape character,έχουμε έναν απλό χαρακτήρα όπως 'a' */
                       yylval.ch = yytext[1];
                   }
                   return CCONST;
                }

 /*Υποστηρίζει string literals με escape χαρακτήρες.Έλεγχος για μέγιστο μήκος 255 χαρακτήρων.*/
\"((\\\n)|(\\.)|[^\\\n"])*\" {
    int len = strlen(yytext);
    if(len - 2 > 255) {
        fprintf(stderr, "Error: String literal exceeds maximum length of 255 characters\n");
        exit(1);
    }
    /* yytext: είναι η συμβολοσειρά που αναγνωρίστηκε από τον Flex (π.χ. "hello") */
    /* yytext + 1: δείχνει στον δεύτερο χαρακτήρα, δηλαδή αφαιρεί το αρχικό εισαγωγικό " */
    /* len - 2: αφαιρεί 1 χαρακτήρα από την αρχή και 1 από το τέλος (δηλαδή το ζεύγος " ") */
    /* strndup(): δημιουργεί αντίγραφο του εσωτερικού string, με μήκος len - 2, και το επιστρέφει. */
    yylval.str = strndup(yytext + 1, len - 2);
    return SCONST;
}

 /* Επιστρέφουν tokens για τελεστές και σημεία στίξης */
"("                 { return LPAREN; }
")"                 { return RPAREN; }
";"                 { return SEMI; }
"."                 { return DOT; }
","                 { return COMMA; }
":="                { return ASSIGN; }
":"                 { return COLON; }
".."                { return DOTDOT; }
"="                 { return EQU; }
"<>"                { return NEQ; }
"<="                { return LE; }
">="                { return GE; }
"<"                 { return LT; }
">"                 { return GT; }
"+"                 { return T_PLUS; }
"-"                 { return T_MINUS; }
"*"                 { return MULOP; }
"/"                 { return DIVOP; }

[ \t\n]+ { }  /* Αγνοεί κενά */
.       { return yytext[0]; }  /* Ό,τι άλλο δεν ταιριάζει, επιστρέφεται ως απλός χαρακτήρας */


%%
