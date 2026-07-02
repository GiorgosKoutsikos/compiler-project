# Simple Makefile for Bison/Flex project with helpers

CC=gcc
CFLAGS=-Wall -g -Wno-unused-function # Add other flags like -std=c11 if needed
LDFLAGS=-lfl -lm # Flex library, Math library

# Source files
BISON_SRC=pasc.y
FLEX_SRC=pasc.l
HELPER_SRC=helpers.c

# Generated files
BISON_GEN_C=pasc.tab.c
BISON_GEN_H=pasc.tab.h
FLEX_GEN_C=lex.yy.c

# Object files
BISON_OBJ=$(BISON_GEN_C:.c=.o) # pasc.tab.o
FLEX_OBJ=$(FLEX_GEN_C:.c=.o)   # lex.yy.o
HELPER_OBJ=$(HELPER_SRC:.c=.o) # helpers.o

# Executable name
TARGET=pasc

# Default target
all: $(TARGET)

# Link the executable
$(TARGET): $(BISON_OBJ) $(FLEX_OBJ) $(HELPER_OBJ)
	$(CC) $(CFLAGS) -o $(TARGET) $(BISON_OBJ) $(FLEX_OBJ) $(HELPER_OBJ) $(LDFLAGS)

# Compile helper code
$(HELPER_OBJ): $(HELPER_SRC) helpers.h
	$(CC) $(CFLAGS) -c $(HELPER_SRC)

# Compile Bison-generated code
$(BISON_OBJ): $(BISON_GEN_C) $(BISON_GEN_H) helpers.h
	$(CC) $(CFLAGS) -c $(BISON_GEN_C)

# Compile Flex-generated code
$(FLEX_OBJ): $(FLEX_GEN_C) $(BISON_GEN_H) helpers.h
	$(CC) $(CFLAGS) -c $(FLEX_GEN_C)

# Generate files from Bison
$(BISON_GEN_C) $(BISON_GEN_H): $(BISON_SRC)
	bison -d $(BISON_SRC)

# Generate file from Flex
$(FLEX_GEN_C): $(FLEX_SRC) $(BISON_GEN_H)
	flex -o $(FLEX_GEN_C) $(FLEX_SRC) # Use -o to specify output filename

# Clean up generated files
clean:
	rm -f $(TARGET) $(BISON_OBJ) $(FLEX_OBJ) $(HELPER_OBJ) $(BISON_GEN_C) $(BISON_GEN_H) $(FLEX_GEN_C) *.output

.PHONY: all clean
