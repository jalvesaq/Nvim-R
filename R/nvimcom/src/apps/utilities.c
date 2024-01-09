#include "utilities.h"

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
