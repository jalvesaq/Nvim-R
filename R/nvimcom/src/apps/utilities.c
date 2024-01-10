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
 * Compares two ASCII strings in a case-insensitive manner.
 * @param a First string.
 * @param b Second string.
 * @return An integer less than, equal to, or greater than zero if a is found,
 *         respectively, to be less than, to match, or be greater than b.
 */
int ascii_ic_cmp(const char *a, const char *b) {
    int d;
    unsigned x, y;
    while (*a && *b) {
        x = (unsigned char)*a;
        y = (unsigned char)*b;
        if (x <= 'Z')
            x += 32;
        if (y <= 'Z')
            y += 32;
        d = x - y;
        if (d != 0)
            return d;
        a++;
        b++;
    }
    return 0;
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

/**
 * Replaces all instances of '\x13' in a string with a single quote.
 * @param s The string to be modified.
 */
void fix_x13(char *s) {
    while (*s != '\0') {
        if (*s == '\x13')
            *s = '\'';
        s++;
    }
}

/**
 * Replaces all instances of a single quote in a string with '\x13'.
 * @param s The string to be modified.
 */
void fix_single_quote(char *s) {
    while (*s != '\0') {
        if (*s == '\'')
            *s = '\x13';
        s++;
    }
}

/**
 * Checks if the string `b` is at the start of string `o`.
 * @param o The string to be checked.
 * @param b The substring to look for at the start of `o`.
 * @return 1 if `b` is at the start of `o`, 0 otherwise.
 */
int str_here(const char *o, const char *b) {
    while (*b && *o) {
        if (*o != *b)
            return 0;
        o++;
        b++;
    }
    return *b == '\0';
}
