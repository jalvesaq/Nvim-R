#ifndef DATA_STRUCTURES_H
#define DATA_STRUCTURES_H

// Structure for paths to libraries
typedef struct libpaths_ {
    char *path;             // Path to library
    struct libpaths_ *next; // Next path
} LibPath;

// Structure for installed libraries
typedef struct instlibs_ {
    char *name;             // Library name
    char *title;            // Library title
    char *descr;            // Library description
    int si;                 // Still installed flag
    struct instlibs_ *next; // Next installed library
} InstLibs;

// Structure for list or library open/close status in the Object Browser
typedef struct liststatus_ {
    char *key; // Name of the object or library. Library names are prefixed with
               // "package:"
    int status;                // 0: closed; 1: open
    struct liststatus_ *left;  // Left node
    struct liststatus_ *right; // Right node
} ListStatus;
ListStatus *search(const char *s);
ListStatus *new_ListStatus(const char *s, int stt);
ListStatus *insert(ListStatus *root, const char *s, int stt);

// Structure for package data
typedef struct pkg_data_ {
    char *name;    // The package name
    char *version; // The package version number
    char *fname;   // Omnils_ file name in the compldir
    char *descr;   // The package short description
    char *omnils;  // A copy of the omnils_ file
    char *args;    // A copy of the args file
    int nobjs;     // Number of objects in the omnils
    int loaded;    // Loaded flag in libnames_
    int to_build;  // Flag to indicate if the name is sent to build list
    int built;     // Flag to indicate if omnils_ found
    struct pkg_data_ *next; // Pointer to next package data
} PkgData;

#endif // !DATA_STRUCTURES_H
