#ifndef UTILITIES_H
#define UTILITIES_H

char *str_cat(char *dest, const char *src);
char *grow_buffer(char **b, unsigned long *sz, unsigned long inc);
void replace_char(char *s, char find, char replace);
int str_here(const char *o, const char *b);
int ascii_ic_cmp(const char *a, const char *b);

#endif // UTILITIES_H
