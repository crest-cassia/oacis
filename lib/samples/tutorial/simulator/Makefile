#This file is written in CASSIYA Project since 2013.

CC=g++
CFLAGS=-c -Wall
SRC=simulator.cpp
OBJ=$(SRC:.cpp=.o)
PROGRAM=simulator.out

all: $(PROGRAM)
	
$(PROGRAM): $(OBJ) 
	$(CC) $(OBJ) -o $@

.cpp.o:
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f $(OBJ) $(PROGRAM)