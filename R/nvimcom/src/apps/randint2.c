#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sys/time.h>

int main(int argc, char **argv){

    time_t t;
    srand((unsigned) time(&t));
    printf("%d%d %d%d", rand(), rand(), rand(), rand());
    return 0;

    return 1;
}
