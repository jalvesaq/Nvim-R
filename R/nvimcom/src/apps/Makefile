CC ?= gcc
CFLAGS = -pthread -std=gnu99 -O2 -Wall -Iinclude

all: bin/nvimrserver

bin/nvimrserver: nvimrserver.c src/utilities.c src/data_structures.c
	$(CC) $(CFLAGS) nvimrserver.c src/utilities.c src/data_structures.c -o bin/nvimrserver

clean:

