#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <sys/time.h>

int main(__attribute__((unused))int argc, __attribute__((unused))char **argv){
    time_t t;
    srand((unsigned) time(&t));
    printf("%d%d %d%d", rand(), rand(), rand(), rand());
    return 0;
}
