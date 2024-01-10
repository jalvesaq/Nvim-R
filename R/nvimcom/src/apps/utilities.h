#ifndef UTILITIES_H
#define UTILITIES_H

char *str_cat(char *dest, const char *src);
char *grow_buffer(char **b, unsigned long *sz, unsigned long inc);
void fix_x13(char *s);
void fix_single_quote(char *s);
int str_here(const char *o, const char *b);
int ascii_ic_cmp(const char *a, const char *b);

#endif // UTILITIES_H
