CC ?= gcc
CFLAGS = -pthread -std=gnu99 -O2 -Wall

all: nvimrserver

nvimrserver: nvimrserver.c utilities.c data_structures.c logging.c
	$(CC) $(CFLAGS) nvimrserver.c utilities.c data_structures.c logging.c -o nvimrserver

clean:

