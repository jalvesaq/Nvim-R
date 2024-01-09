#ifndef UTILITIES_H
#define UTILITIES_H

char *str_cat(char *dest, const char *src);
char *grow_buffer(char **b, unsigned long *sz, unsigned long inc);

#endif // UTILITIES_H
