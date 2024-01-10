#include "data_structures.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static ListStatus *listTree = NULL; // Root node of the list status tree
ListStatus *search(const char *s) {
    ListStatus *node = listTree;
    int cmp = strcmp(node->key, s);
    while (node && cmp != 0) {
        if (cmp > 0)
            node = node->right;
        else
            node = node->left;
        if (node)
            cmp = strcmp(node->key, s);
    }
    if (cmp == 0)
        return node;
    else
        return NULL;
}

ListStatus *new_ListStatus(const char *s, int stt) {
    ListStatus *p;
    p = calloc(1, sizeof(ListStatus));
    p->key = malloc((strlen(s) + 1) * sizeof(char));
    strcpy(p->key, s);
    p->status = stt;
    return p;
}

ListStatus *insert(ListStatus *root, const char *s, int stt) {
    if (!root)
        return new_ListStatus(s, stt);
    int cmp = strcmp(root->key, s);
    if (cmp > 0)
        root->right = insert(root->right, s, stt);
    else
        root->left = insert(root->left, s, stt);
    return root;
}
