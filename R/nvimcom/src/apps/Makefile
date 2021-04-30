CC ?= gcc
CFLAGS = -pthread -std=gnu99 -O2 -Wall

all: nclientserver randint2

nclientserver: nclientserver.c
	$(CC) $(CFLAGS) nclientserver.c -o nclientserver

randint2: randint2.c
	$(CC) $(CFLAGS) randint2.c -o randint2

clean:

