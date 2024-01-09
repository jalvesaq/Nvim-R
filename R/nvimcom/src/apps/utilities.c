#include "utilities.h"
#include <stdlib.h>
#include <string.h>

/**
 * Concatenates strings.
 * @param dest Destination string.
 * @param src Source string.
 * @return Pointer to the end of the destination string.
 */
char *str_cat(char *dest, const char *src) {
    while (*dest)
        dest++;
    while ((*dest++ = *src++))
        ;
    return --dest;
}

/**
 * Grows a buffer to a new size.
 * @param b Pointer to the buffer.
 * @param sz Size of the buffer.
 * @param inc Amount to increase.
 * @return Pointer to the resized buffer.
 */
char *grow_buffer(char **b, unsigned long *sz, unsigned long inc) {
    // The following line is commented out because Log is not modularized yet.
    // I should remember to revert this after implementing a logging.c file.
    // Log("grow_buffer(%lu, %lu) [%lu, %lu]", *sz, inc, compl_buffer_size,
    // fb_size);

    *sz += inc;
    char *tmp = calloc(*sz, sizeof(char));
    strcpy(tmp, *b);
    free(*b);
    *b = tmp;
    return tmp;
}
