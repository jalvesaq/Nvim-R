#include <R.h> /* to include Rconfig.h */
#include <R_ext/Callbacks.h>
#include <R_ext/Parse.h>
#include <Rinternals.h>
#ifndef WIN32
#define HAVE_SYS_SELECT_H
#include <R_ext/eventloop.h>
#endif

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#ifdef WIN32
#include <process.h>
#include <winsock2.h>
#ifdef _WIN64
#include <inttypes.h>
#endif
#else
#include <arpa/inet.h> // inet_addr()
#include <netdb.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <sys/socket.h>
#endif

#ifndef WIN32
// Needed to know what is the prompt
#include <Rinterface.h>
#define R_INTERFACE_PTRS 1
extern int (*ptr_R_ReadConsole)(const char *, unsigned char *, int, int);
static int (*save_ptr_R_ReadConsole)(const char *, unsigned char *, int, int);
static int debugging;           // Is debugging a function now?
LibExtern SEXP R_SrcfileSymbol; // R internal variable defined in Defn.h.
static void SrcrefInfo(void);
#endif
static int debug_r; // Should detect when `browser()` is running and start
                    // debugging mode?

static int initialized = 0; // TCP client successfully connected to the server.

static int verbose = 0;  // 1: version number; 2: initial information; 3: TCP in
                         // and out; 4: more verbose; 5: really verbose.
static int allnames = 0; // Show hidden objects in omni completion and
                         // Object Browser?
static int nlibs = 0;    // Number of loaded libraries.
static int needs_lib_msg = 0;    // Did the number of libraries change?
static int needs_glbenv_msg = 0; // Did .GlobalEnv change?

static char nrs_port[16]; // nvimrserver port.
static char nvimsecr[32]; // Random string used to increase the safety of TCP
                          // communication.

static char *glbnvbuf1;   // Temporary buffer used to store the list of
                          // .GlobalEnv objects.
static char *glbnvbuf2;   // Temporary buffer used to store the list of
                          // .GlobalEnv objects.
static char *send_ge_buf; // Temporary buffer used to store the list of
                          // .GlobalEnv objects.

static unsigned long lastglbnvbsz;         // Previous size of glbnvbuf2.
static unsigned long glbnvbufsize = 32768; // Current size of glbnvbuf2.

static unsigned long tcp_header_len; // Lenght of nvimsecr + 9. Stored in a
                                     // variable to avoid repeatedly calling
                                     // strlen().

static int maxdepth = 6; // How many levels to parse in lists and S4 objects
// when building list of objects for omni-completion. The value decreases if
// the listing is too slow and increases if there are more levels to be parsed
// and the listing is fast enough.
static int curdepth = 0; // Current level of the list or S4 object being parsed
                         // for omni-completion.
static int autoglbenv = 0; // Should the list of objects in .GlobalEnv be
// automatically updated after each top level command is executed? It will
// always be 1 if cmp-nvim-r is installed or the Object Browser is open.
static clock_t tm; // Time when the listing of objects from .GlobalEnv started.

static char tmpdir[512]; // The environment variable NVIMR_TMPDIR.
static int setwidth = 0; // Set the option width after each command is executed
static int oldcolwd = 0; // Last set width.

#ifdef WIN32
static int r_is_busy = 1; // Is R executing a top level command? R memory will
// become corrupted and R will crash afterwards if we execute a function that
// creates R objects while R is busy.
#else
static int fired = 0; // Do we have commands waiting to be executed?
static int ifd;       // input file descriptor
static int ofd;       // output file descriptor
static InputHandler *ih;
static char flag_eval[512]; // Do we have an R expression to evaluate?
static int flag_glbenv = 0; // Do we have to list objects from .GlobalEnv?
static int flag_debug = 0;  // Do we need to get file name and line information
                            // of debugging function?
#endif

/**
 * @typedef lib_info_
 * @brief Structure with name and version number of a library.
 *
 * The complete information of libraries is stored in its `omnils_`, `fun_` and
 * `args_` files in the Nvim-R cache directory. The nvimrserver only needs the
 * name and version number of the library to read the corresponding files.
 *
 */
typedef struct lib_info_ {
    char *name;
    char *version;
    unsigned long strlen;
    struct lib_info_ *next;
} LibInfo;

static LibInfo *libList; // Linked list of loaded libraries information (names
                         // and version numbers).

static void nvimcom_checklibs(void);
static void send_to_nvim(char *msg);
static void nvimcom_eval_expr(const char *buf);

#ifdef WIN32
SOCKET sfd; // File descriptor of socket used in the TCP connection with the
            // nvimrserver.
static HANDLE tid; // Identifier of thread running TCP connection loop.
extern void Rconsolecmd(char *cmd); // Defined in R: src/gnuwin32/rui.c.
#else
static int sfd = -1;  // File descriptor of socket used in the TCP connection
                      // with the nvimrserver.
static pthread_t tid; // Identifier of thread running TCP connection loop.
#endif

/**
 * @brief Concatenate two strings.
 *
 * @param dest Destination buffer.
 * @param src String to be appended to `dest`.
 * @return Pointer to the new NULL terminating byte of `dest`.
 */
static char *nvimcom_strcat(char *dest, const char *src) {
    while (*dest)
        dest++;
    while ((*dest++ = *src++))
        ;
    return --dest;
}

/**
 * @brief Replace buffers used to store omni-completion information with
 * bigger ones.
 *
 * @return Pointer to the NULL terminating byte of glbnvbuf2.
 */
static char *nvimcom_grow_buffers(void) {
    lastglbnvbsz = glbnvbufsize;
    glbnvbufsize += 32768;

    char *tmp = (char *)calloc(glbnvbufsize, sizeof(char));
    strcpy(tmp, glbnvbuf1);
    free(glbnvbuf1);
    glbnvbuf1 = tmp;

    tmp = (char *)calloc(glbnvbufsize, sizeof(char));
    strcpy(tmp, glbnvbuf2);
    free(glbnvbuf2);
    glbnvbuf2 = tmp;

    tmp = (char *)calloc(glbnvbufsize + 64, sizeof(char));
    free(send_ge_buf);
    send_ge_buf = tmp;

    return (glbnvbuf2 + strlen(glbnvbuf2));
}

/**
 * @brief Send string to nvimrserver.
 *
 * The function sends a string to nvimrserver through the TCP connection
 * established at `nvimcom_Start()`.
 *
 * @param msg The message to be sent.
 */
static void send_to_nvim(char *msg) {
    if (sfd == -1)
        return;

    size_t sent;
    char b[64];
    size_t len;

    if (verbose > 2) {
        if (strlen(msg) < 128)
            REprintf("send_to_nvim [%d] {%s}: %s\n", sfd, nvimsecr, msg);
    }

    len = strlen(msg);

    /*
       TCP message format:
         NVIMR_SECRET : Prefix NVIMR_SECRET to msg to increase security
         000000000    : Size of message in 9 digits
         msg          : The message
         \x11         : Final byte

       Notes:

       - The string is terminated by a final \x11 byte which hopefully is never
         used in any R code. It would be slower to escape special characters.

       - The time to save the file at /dev/shm is bigger than the time to send
         the buffer through a TCP connection.

       - When the msg is very big, it's faster to send the final message in
         three pieces than to call snprintf() to assemble everything in a
         single string.
    */

    // Send the header
    snprintf(b, 63, "%s%09zu", nvimsecr, len);
    sent = send(sfd, b, tcp_header_len, 0);
    if (sent != tcp_header_len) {
        if (sent == -1)
            REprintf("Error sending message header to Nvim-R: -1\n");
        else
            REprintf("Error sending message header to Nvim-R: %zu x %zu\n",
                     tcp_header_len, sent);
#ifdef WIN32
        closesocket(sfd);
        WSACleanup();
#else
        close(sfd);
#endif
        sfd = -1;
        strcpy(nrs_port, "0");
        return;
    }

    // based on code found on php source
    // Send the message
    char *pCur = msg;
    char *pEnd = msg + len;
    int loop = 0;
    while (pCur < pEnd) {
        sent = send(sfd, pCur, pEnd - pCur, 0);
        if (sent >= 0) {
            pCur += sent;
        } else if (sent == -1) {
            REprintf("Error sending message to Nvim-R: %zu x %zu\n", len,
                     pCur - msg);
            return;
        }
        loop++;
        if (loop == 100) {
            // The goal here is to avoid infinite loop.
            // TODO: Maybe delete this check because php code does not have
            // something similar
            REprintf("Too many attempts to send message to Nvim-R: %zu x %zu\n",
                     len, sent);
            return;
        }
    }

    // End the message with \x11
    sent = send(sfd, "\x11", 1, 0);
    if (sent != 1)
        REprintf("Error sending final byte to Nvim-R: 1 x %zu\n", sent);
}

/**
 * @brief Function called by R code to send message to nvimrserver.
 *
 * @param cmd The message to be sent.
 */
void nvimcom_msg_to_nvim(char **cmd) { send_to_nvim(*cmd); }

/**
 * @brief Duplicate single quotes.
 *
 * We use single quote to define field names and values of Vim dictionaries.
 * Single quotes within such strings must be duplicated to avoid Vim errors
 * when evaluating the string as a dictionary.
 *
 * @param buf Original string.
 * @param buf2 Destination buffer of the new string with duplicated quotes.
 * @param bsize Size limit of destination buffer.
 */
static void nvimcom_squo(const char *buf, char *buf2, int bsize) {
    int i = 0, j = 0;
    while (j < bsize) {
        if (buf[i] == '\'') {
            buf2[j] = '\'';
            j++;
            buf2[j] = '\'';
        } else if (buf[i] == 0) {
            buf2[j] = 0;
            break;
        } else {
            buf2[j] = buf[i];
        }
        i++;
        j++;
    }
}

/**
 * @brief Quote strings with backticks.
 *
 * The names of R objects that are invalid to be inserted directly in the
 * console must be quoted with backticks.
 *
 * @param b1 Name to be quoted.
 * @param b2 Destination buffer to the quoted name.
 */
static void nvimcom_backtick(const char *b1, char *b2) {
    int i = 0, j = 0;
    while (i < 511 && b1[i] != '$' && b1[i] != '@' && b1[i] != 0) {
        if (b1[i] == '[' && b1[i + 1] == '[') {
            b2[j] = '[';
            i++;
            j++;
            b2[j] = '[';
            i++;
            j++;
        } else {
            b2[j] = '`';
            j++;
        }
        while (i < 511 && b1[i] != '$' && b1[i] != '@' && b1[i] != '[' &&
               b1[i] != 0) {
            b2[j] = b1[i];
            i++;
            j++;
        }
        if (b1[i - 1] != ']') {
            b2[j] = '`';
            j++;
        }
        if (b1[i] == 0)
            break;
        if (b1[i] != '[') {
            b2[j] = b1[i];
            i++;
            j++;
        }
    }
    b2[j] = 0;
}

/**
 * @brief Creates a new LibInfo structure to store the name and version
 * number of a library
 *
 * @param nm Name of the library.
 * @param vrsn Version number of the library.
 * @return Pointer to the new LibInfo structure.
 */
static LibInfo *nvimcom_lib_info_new(const char *nm, const char *vrsn) {
    LibInfo *pi = calloc(1, sizeof(LibInfo));
    pi->name = malloc((strlen(nm) + 1) * sizeof(char));
    strcpy(pi->name, nm);
    pi->version = malloc((strlen(vrsn) + 1) * sizeof(char));
    strcpy(pi->version, vrsn);
    pi->strlen = strlen(pi->name) + strlen(pi->version) + 2;
    return pi;
}

/**
 * @brief Adds a new LibInfo structure to libList, the linked list of loaded
 * libraries.
 *
 * @param nm The name of the library
 * @param vrsn The version number of the library
 */
static void nvimcom_lib_info_add(const char *nm, const char *vrsn) {
    LibInfo *pi = nvimcom_lib_info_new(nm, vrsn);
    if (libList) {
        pi->next = libList;
        libList = pi;
    } else {
        libList = pi;
    }
}

/**
 * @brief Returns a pointer to information on an library.
 *
 * @param nm Name of the library.
 * @return Pointer to a LibInfo structure with information on the library
 * `nm`.
 */
static LibInfo *nvimcom_get_lib(const char *nm) {
    if (!libList)
        return NULL;

    LibInfo *pi = libList;
    do {
        if (strcmp(pi->name, nm) == 0)
            return pi;
        pi = pi->next;
    } while (pi);

    return NULL;
}

/**
 * @brief This function adds a line with information for
 * omni-completion.
 *
 * @param x Object whose information is to be generated.
 *
 * @param xname The name of the object.
 *
 * @param curenv Current "environment" of object x. If x is an element of a list
 * or S4 object, `curenv` will be the representation of the parent structure.
 * Example: for `x` in `alist$aS4obj@x`, `curenv` will be `alist$aS4obj@`.
 *
 * @param p A pointer to the current NULL byte terminating the glbnvbuf2
 * buffer.
 *
 * @param depth Current number of levels in lists and S4 objects.
 *
 * @return The pointer p updated after the insertion of the new line.
 */
static char *nvimcom_glbnv_line(SEXP *x, const char *xname, const char *curenv,
                                char *p, int depth) {
    if (depth > maxdepth)
        return p;

    if (depth > curdepth)
        curdepth = depth;

    int xgroup = 0; // 1 = function, 2 = data.frame, 3 = list, 4 = s4
    char ebuf[64];
    int len = 0;
    SEXP txt, lablab;
    SEXP sn = R_NilValue;
    char buf[576];
    char bbuf[512];

    if ((strlen(glbnvbuf2 + lastglbnvbsz)) > 31744)
        p = nvimcom_grow_buffers();

    p = nvimcom_strcat(p, curenv);
    snprintf(ebuf, 63, "%s", xname);
    p = nvimcom_strcat(p, ebuf);

    if (Rf_isLogical(*x)) {
        p = nvimcom_strcat(p, "\006%\006");
    } else if (Rf_isNumeric(*x)) {
        p = nvimcom_strcat(p, "\006{\006");
    } else if (Rf_isFactor(*x)) {
        p = nvimcom_strcat(p, "\006!\006");
    } else if (Rf_isValidString(*x)) {
        p = nvimcom_strcat(p, "\006~\006");
    } else if (Rf_isFunction(*x)) {
        p = nvimcom_strcat(p, "\006\003\006");
        xgroup = 1;
    } else if (Rf_isFrame(*x)) {
        p = nvimcom_strcat(p, "\006$\006");
        xgroup = 2;
    } else if (Rf_isNewList(*x)) {
        p = nvimcom_strcat(p, "\006[\006");
        xgroup = 3;
    } else if (Rf_isS4(*x)) {
        p = nvimcom_strcat(p, "\006<\006");
        xgroup = 4;
    } else if (Rf_isEnvironment(*x)) {
        p = nvimcom_strcat(p, "\006:\006");
    } else if (TYPEOF(*x) == PROMSXP) {
        p = nvimcom_strcat(p, "\006&\006");
    } else {
        p = nvimcom_strcat(p, "\006*\006");
    }

    // Specific class of object, if any
    PROTECT(txt = getAttrib(*x, R_ClassSymbol));
    if (!isNull(txt)) {
        p = nvimcom_strcat(p, CHAR(STRING_ELT(txt, 0)));
    }
    UNPROTECT(1);

    p = nvimcom_strcat(p, "\006.GlobalEnv\006");

    if (xgroup == 1) {
        /* It would be necessary to port args2buff() from src/main/deparse.c to
           here but it's too big. So, it's better to call nvimcom:::nvim.args()
           during omni completion. FORMALS() may return an object that will
           later crash R:
           https://github.com/jalvesaq/Nvim-R/issues/543#issuecomment-748981771
         */
        p = nvimcom_strcat(p, "[\x12not_checked\x12]");
    }

    // Add label
    PROTECT(lablab = allocVector(STRSXP, 1));
    SET_STRING_ELT(lablab, 0, mkChar("label"));
    PROTECT(txt = getAttrib(*x, lablab));
    if (length(txt) > 0) {
        if (Rf_isValidString(txt)) {
            char *ptr;
            snprintf(buf, 159, "\006\006%s", CHAR(STRING_ELT(txt, 0)));
            ptr = buf;
            while (*ptr) {
                if (*ptr == '\n') // A new line will make nvimrserver crash
                    *ptr = ' ';
                ptr++;
            }
            p = nvimcom_strcat(p, buf);
        } else {
            p = nvimcom_strcat(p,
                               "\006\006Error: label is not a valid string.");
        }
    } else {
        p = nvimcom_strcat(p, "\006\006");
    }
    UNPROTECT(2);

    // Add the object length
    if (xgroup == 2) {
        snprintf(buf, 127, " [%d, %d]", length(Rf_GetRowNames(*x)), length(*x));
        p = nvimcom_strcat(p, buf);
    } else if (xgroup == 3) {
        snprintf(buf, 127, " [%d]", length(*x));
        p = nvimcom_strcat(p, buf);
    } else if (xgroup == 4) {
        SEXP cmdSexp, cmdexpr;
        ParseStatus status;
        snprintf(buf, 575, "%s%s", curenv, xname);
        nvimcom_backtick(buf, bbuf);
        snprintf(buf, 575, "slotNames(%s)", bbuf);
        PROTECT(cmdSexp = allocVector(STRSXP, 1));
        SET_STRING_ELT(cmdSexp, 0, mkChar(buf));
        PROTECT(cmdexpr = R_ParseVector(cmdSexp, -1, &status, R_NilValue));
        if (status == PARSE_OK) {
            int er = 0;
            PROTECT(sn = R_tryEval(VECTOR_ELT(cmdexpr, 0), R_GlobalEnv, &er));
            if (er)
                REprintf("nvimcom error executing command: slotNames(%s%s)\n",
                         curenv, xname);
            else
                len = length(sn);
            UNPROTECT(1);
        } else {
            REprintf("nvimcom error: invalid value in slotNames(%s%s)\n",
                     curenv, xname);
        }
        UNPROTECT(2);
        snprintf(buf, 127, " [%d]", len);
        p = nvimcom_strcat(p, buf);
    }

    // finish the line
    p = nvimcom_strcat(p, "\006\n");

    if (xgroup > 1) {
        char newenv[576];
        SEXP elmt = R_NilValue;
        const char *ename;
        double tmdiff = 1000 * ((double)clock() - tm) / CLOCKS_PER_SEC;
        if (tmdiff > 300.0) {
            maxdepth = curdepth;
            if (verbose > 3)
                REprintf("nvimcom: slow at building list of objects (%g ms); "
                         "maxdepth = %d\n",
                         tmdiff, maxdepth);
            return p;
        } else if (tmdiff < 100.0 && maxdepth <= curdepth) {
            maxdepth++;
            if (verbose > 3)
                REprintf("nvimcom: increased maxdepth to %d (time to build "
                         "completion data = %g)\n",
                         maxdepth, tmdiff);
        }

        if (xgroup == 4) {
            snprintf(newenv, 575, "%s%s@", curenv, xname);
            if (len > 0) {
                for (int i = 0; i < len; i++) {
                    ename = CHAR(STRING_ELT(sn, i));
                    PROTECT(elmt = R_do_slot(*x, Rf_install(ename)));
                    p = nvimcom_glbnv_line(&elmt, ename, newenv, p, depth + 1);
                    UNPROTECT(1);
                }
            }
        } else {
            SEXP listNames;
            snprintf(newenv, 575, "%s%s$", curenv, xname);
            PROTECT(listNames = getAttrib(*x, R_NamesSymbol));
            len = length(listNames);
            if (len == 0) { /* Empty list? */
                int len1 = length(*x);
                if (len1 > 0) { /* List without names */
                    len1 -= 1;
                    if (newenv[strlen(newenv) - 1] == '$')
                        newenv[strlen(newenv) - 1] = 0; // Delete trailing '$'
                    for (int i = 0; i < len1; i++) {
                        sprintf(ebuf, "[[%d]]", i + 1);
                        elmt = VECTOR_ELT(*x, i);
                        p = nvimcom_glbnv_line(&elmt, ebuf, newenv, p,
                                               depth + 1);
                    }
                    sprintf(ebuf, "[[%d]]", len1 + 1);
                    PROTECT(elmt = VECTOR_ELT(*x, len));
                    p = nvimcom_glbnv_line(&elmt, ebuf, newenv, p, depth + 1);
                    UNPROTECT(1);
                }
            } else { /* Named list */
                SEXP eexp;
                len -= 1;
                for (int i = 0; i < len; i++) {
                    PROTECT(eexp = STRING_ELT(listNames, i));
                    ename = CHAR(eexp);
                    UNPROTECT(1);
                    if (ename[0] == 0) {
                        sprintf(ebuf, "[[%d]]", i + 1);
                        ename = ebuf;
                    }
                    PROTECT(elmt = VECTOR_ELT(*x, i));
                    p = nvimcom_glbnv_line(&elmt, ename, newenv, p, depth + 1);
                    UNPROTECT(1);
                }
                ename = CHAR(STRING_ELT(listNames, len));
                if (ename[0] == 0) {
                    sprintf(ebuf, "[[%d]]", len + 1);
                    ename = ebuf;
                }
                PROTECT(elmt = VECTOR_ELT(*x, len));
                p = nvimcom_glbnv_line(&elmt, ename, newenv, p, depth + 1);
                UNPROTECT(1);
            }
            UNPROTECT(1); /* listNames */
        }
    }
    return p;
}

/**
 * @brief Generate a list of objects in .GlobalEnv and store it in the
 * glbnvbuf2 buffer. The string stored in glbnvbuf2 represents a file with the
 * same format of the `omnils_` files in Nvim-R's cache directory.
 */
static void nvimcom_globalenv_list(void) {
    if (verbose > 4)
        REprintf("nvimcom_globalenv_list()\n");
    const char *varName;
    SEXP envVarsSEXP, varSEXP;

    if (tmpdir[0] == 0)
        return;

    tm = clock();

    memset(glbnvbuf2, 0, glbnvbufsize);
    char *p = glbnvbuf2;

    curdepth = 0;

    PROTECT(envVarsSEXP = R_lsInternal(R_GlobalEnv, allnames));
    for (int i = 0; i < Rf_length(envVarsSEXP); i++) {
        varName = CHAR(STRING_ELT(envVarsSEXP, i));
        if (R_BindingIsActive(Rf_install(varName), R_GlobalEnv)) {
            // See: https://github.com/jalvesaq/Nvim-R/issues/686
            PROTECT(varSEXP = R_ActiveBindingFunction(Rf_install(varName),
                                                      R_GlobalEnv));
        } else {
            PROTECT(varSEXP = Rf_findVar(Rf_install(varName), R_GlobalEnv));
        }
        if (varSEXP != R_UnboundValue) {
            // should never be unbound
            p = nvimcom_glbnv_line(&varSEXP, varName, "", p, 0);
        } else {
            REprintf("nvimcom_globalenv_list: Unexpected R_UnboundValue.\n");
        }
        UNPROTECT(1);
    }
    UNPROTECT(1);

    size_t len1 = strlen(glbnvbuf1);
    size_t len2 = strlen(glbnvbuf2);
    int changed = len1 != len2;
    if (verbose > 4)
        REprintf("globalenv_list(0) len1 = %zu, len2 = %zu\n", len1, len2);
    if (!changed) {
        for (int i = 0; i < len1; i++) {
            if (glbnvbuf1[i] != glbnvbuf2[i]) {
                changed = 1;
                break;
            }
        }
    }

    if (changed)
        needs_glbenv_msg = 1;

    double tmdiff = 1000 * ((double)clock() - tm) / CLOCKS_PER_SEC;
    if (verbose && tmdiff > 500.0)
        REprintf("Time to build GlobalEnv omnils [%lu bytes]: %f ms\n",
                 strlen(glbnvbuf2), tmdiff);
}

/**
 * @brief Send to Nvim-R the string containing the list of objects in
 * .GlobalEnv.
 */
static void send_glb_env(void) {
    clock_t t1;

    t1 = clock();

    strcpy(send_ge_buf, "+G");
    strcat(send_ge_buf, glbnvbuf2);
    send_to_nvim(send_ge_buf);

    if (verbose > 3)
        REprintf("Time to send message to Nvim-R: %f\n",
                 1000 * ((double)clock() - t1) / CLOCKS_PER_SEC);

    char *tmp = glbnvbuf1;
    glbnvbuf1 = glbnvbuf2;
    glbnvbuf2 = tmp;
}

/**
 * @brief Evaluate an R expression.
 *
 * @param buf The expression to be evaluated.
 */
static void nvimcom_eval_expr(const char *buf) {
    if (verbose > 3)
        Rprintf("nvimcom_eval_expr: '%s'\n", buf);

    char rep[128];

    SEXP cmdSexp, cmdexpr, ans;
    ParseStatus status;
    int er = 0;

    PROTECT(cmdSexp = allocVector(STRSXP, 1));
    SET_STRING_ELT(cmdSexp, 0, mkChar(buf));
    PROTECT(cmdexpr = R_ParseVector(cmdSexp, -1, &status, R_NilValue));

    char buf2[80];
    nvimcom_squo(buf, buf2, 80);
    if (status == PARSE_OK) {
        /* Only the first command will be executed if the expression includes
         * a semicolon. */
        PROTECT(ans = R_tryEval(VECTOR_ELT(cmdexpr, 0), R_GlobalEnv, &er));
        if (er && verbose > 1) {
            strcpy(rep, "call RWarningMsg('Error running: ");
            strncat(rep, buf2, 80);
            strcat(rep, "')");
            send_to_nvim(rep);
        }
        UNPROTECT(1);
    } else {
        if (verbose > 1) {
            strcpy(rep, "call RWarningMsg('Invalid command: ");
            strncat(rep, buf2, 80);
            strcat(rep, "')");
            send_to_nvim(rep);
        }
    }
    UNPROTECT(2);
}

/**
 * @brief Send the names and version numbers of currently loaded libraries to
 * Nvim-R.
 */
static void send_libnames(void) {
    LibInfo *lib;
    unsigned long totalsz = 9;
    char *libbuf;
    lib = libList;
    do {
        totalsz += lib->strlen;
        lib = lib->next;
    } while (lib);

    libbuf = malloc(totalsz + 1);

    libbuf[0] = 0;
    nvimcom_strcat(libbuf, "+L");
    lib = libList;
    do {
        nvimcom_strcat(libbuf, lib->name);
        nvimcom_strcat(libbuf, "\003");
        nvimcom_strcat(libbuf, lib->version);
        nvimcom_strcat(libbuf, "\004");
        lib = lib->next;
    } while (lib);
    libbuf[totalsz] = 0;
    send_to_nvim(libbuf);
    free(libbuf);
}

/**
 * @brief Count how many libraries are loaded in R's workspace. If the number
 * differs from the previous count, add new libraries to LibInfo structure.
 */
static void nvimcom_checklibs(void) {
    SEXP a;

    PROTECT(a = eval(lang1(install("search")), R_GlobalEnv));

    int newnlibs = Rf_length(a);
    if (nlibs == newnlibs)
        return;

    SEXP l, cmdSexp, cmdexpr, ans;
    const char *libname;
    char *libn;
    char buf[128];
    ParseStatus status;
    int er = 0;
    LibInfo *lib;

    nlibs = newnlibs;

    needs_lib_msg = 1;

    for (int i = 0; i < newnlibs; i++) {
        PROTECT(l = STRING_ELT(a, i));
        libname = CHAR(l);
        libn = strstr(libname, "package:");
        if (libn != NULL) {
            libn = strstr(libn, ":");
            libn++;
            lib = nvimcom_get_lib(libn);
            if (!lib) {
                snprintf(buf, 127, "utils::packageDescription('%s')$Version",
                         libn);
                PROTECT(cmdSexp = allocVector(STRSXP, 1));
                SET_STRING_ELT(cmdSexp, 0, mkChar(buf));
                PROTECT(cmdexpr =
                            R_ParseVector(cmdSexp, -1, &status, R_NilValue));
                if (status != PARSE_OK) {
                    REprintf("nvimcom error parsing: %s\n", buf);
                } else {
                    PROTECT(ans = R_tryEval(VECTOR_ELT(cmdexpr, 0), R_GlobalEnv,
                                            &er));
                    if (er) {
                        REprintf("nvimcom error executing: %s\n", buf);
                    } else {
                        nvimcom_lib_info_add(libn, CHAR(STRING_ELT(ans, 0)));
                    }
                    UNPROTECT(1);
                }
                UNPROTECT(2);
            }
        }
        UNPROTECT(1);
    }
    UNPROTECT(1);

    return;
}

/**
 * @brief Function registered to be called by R after completing each top-level
 * task. See R documentation on addTaskCallback.
 *
 * We don't use any of the parameters passed by R. We only use this task
 * callback to avoid doing anything while R is busy executing commands sent to
 * its console. R would crash if we executed any function that runs the PROTECT
 * macro while it was busy executing top level commands.
 *
 * @param unused Unused parameter.
 * @param unused Unused parameter.
 * @param unused Unused parameter.
 * @param unused Unused parameter.
 * @param unused Unused parameter.
 * @return Aways return TRUE.
 */
static Rboolean nvimcom_task(__attribute__((unused)) SEXP expr,
                             __attribute__((unused)) SEXP value,
                             __attribute__((unused)) Rboolean succeeded,
                             __attribute__((unused)) Rboolean visible,
                             __attribute__((unused)) void *userData) {
    if (verbose > 4)
        REprintf("nvimcom_task()\n");
#ifdef WIN32
    r_is_busy = 0;
#endif
    if (nrs_port[0] != 0) {
        nvimcom_checklibs();
        if (autoglbenv)
            nvimcom_globalenv_list();
        if (needs_lib_msg)
            send_libnames();
        if (needs_glbenv_msg)
            send_glb_env();
        needs_lib_msg = 0;
        needs_glbenv_msg = 0;
    }
    if (setwidth && getenv("COLUMNS")) {
        int columns = atoi(getenv("COLUMNS"));
        if (columns > 0 && columns != oldcolwd) {
            oldcolwd = columns;

            /* From R-exts: Evaluating R expressions from C */
            SEXP s, t;
            PROTECT(t = s = allocList(2));
            SET_TYPEOF(s, LANGSXP);
            SETCAR(t, install("options"));
            t = CDR(t);
            SETCAR(t, ScalarInteger((int)columns));
            SET_TAG(t, install("width"));
            eval(s, R_GlobalEnv);
            UNPROTECT(1);

            if (verbose > 2)
                Rprintf("nvimcom: width = %d columns\n", columns);
        }
    }
    return (TRUE);
}

#ifndef WIN32
/**
 * @brief Executed by R when idle.
 *
 * @param unused Unused parameter.
 */
static void nvimcom_exec(__attribute__((unused)) void *nothing) {
    if (*flag_eval) {
        nvimcom_eval_expr(flag_eval);
        *flag_eval = 0;
    }
    if (flag_glbenv) {
        nvimcom_globalenv_list();
        flag_glbenv = 0;
    }
    if (flag_debug) {
        SrcrefInfo();
        flag_debug = 0;
    }
}

/**
 * @brief Check if there is anything in the pipe that we use to register that
 * there are commands to be evaluated. R only executes this function when it
 * can safely execute our commands. This functionality is not available on
 * Windows.
 *
 * @param unused Unused parameter.
 */
static void nvimcom_uih(__attribute__((unused)) void *data) {
    /* Code adapted from CarbonEL.
     * Thanks to Simon Urbanek for the suggestion on r-devel mailing list. */
    if (verbose > 4)
        REprintf("nvimcom_uih()\n");
    char buf[16];
    if (read(ifd, buf, 1) < 1)
        REprintf("nvimcom error: read < 1\n");
    R_ToplevelExec(nvimcom_exec, NULL);
    fired = 0;
}

/**
 * @brief Put a single byte in a pipe to register that we have commands
 * waiting to be executed. R will crash if we execute commands while it is
 * busy with other tasks.
 */
static void nvimcom_fire(void) {
    if (verbose > 4)
        REprintf("nvimcom_fire()\n");
    if (fired)
        return;
    fired = 1;
    char buf[16];
    *buf = 0;
    if (write(ofd, buf, 1) <= 0)
        REprintf("nvimcom error: write <= 0\n");
}

/**
 * @brief Read an R's internal variable to get file name and line number of
 * function currently being debugged.
 */
static void SrcrefInfo(void) {
    // Adapted from SrcrefPrompt(), at src/main/eval.c
    if (debugging == 0) {
        send_to_nvim("call StopRDebugging()");
        return;
    }
    /* If we have a valid R_Srcref, use it */
    if (R_Srcref && R_Srcref != R_NilValue) {
        if (TYPEOF(R_Srcref) == VECSXP)
            R_Srcref = VECTOR_ELT(R_Srcref, 0);
        SEXP srcfile = getAttrib(R_Srcref, R_SrcfileSymbol);
        if (TYPEOF(srcfile) == ENVSXP) {
            SEXP filename = findVar(install("filename"), srcfile);
            if (isString(filename) && length(filename)) {
                size_t slen = strlen(CHAR(STRING_ELT(filename, 0)));
                char *buf = calloc(sizeof(char), (2 * slen + 32));
                char *buf2 = calloc(sizeof(char), (2 * slen + 32));
                snprintf(buf, 2 * slen + 1, "%s",
                         CHAR(STRING_ELT(filename, 0)));
                nvimcom_squo(buf, buf2, 2 * slen + 32);
                snprintf(buf, 2 * slen + 31, "call RDebugJump('%s', %d)", buf2,
                         asInteger(R_Srcref));
                send_to_nvim(buf);
                free(buf);
                free(buf2);
            }
        }
    }
}

/**
 * @brief This function is called by R to process user input. The function
 * monitor R input and checks if we are within the `browser()` function before
 * passing the data to the R function that really process the input.
 *
 * @param prompt R prompt
 * @param buf Command inserted in the R console
 * @param len Length of command in bytes
 * @param addtohistory Should the command be included in `.Rhistory`?
 * @return The return value is defined and used by R.
 */
static int nvimcom_read_console(const char *prompt, unsigned char *buf, int len,
                                int addtohistory) {
    if (debugging == 1) {
        if (prompt[0] != 'B')
            debugging = 0;
        flag_debug = 1;
        nvimcom_fire();
    } else {
        if (prompt[0] == 'B' && prompt[1] == 'r' && prompt[2] == 'o' &&
            prompt[3] == 'w' && prompt[4] == 's' && prompt[5] == 'e' &&
            prompt[6] == '[') {
            debugging = 1;
            flag_debug = 1;
            nvimcom_fire();
        }
    }
    return save_ptr_R_ReadConsole(prompt, buf, len, addtohistory);
}
#endif

/**
 * @brief This function is called after the TCP connection with the nvimrserver
 * is established. Its goal is to pass to Nvim-R information on the running R
 * instance.
 *
 * @param r_info Information on R (see `.onAttach()` at R/nvimcom.R)
 */
static void nvimcom_send_running_info(const char *r_info, const char *nvv) {
    char msg[2176];
    pid_t R_PID = getpid();

#ifdef WIN32
#ifdef _WIN64
    snprintf(msg, 2175,
             "call SetNvimcomInfo('%s', %" PRId64 ", '%" PRId64 "', '%s')", nvv,
             R_PID, (long long)GetForegroundWindow(), r_info);
#else
    snprintf(msg, 2175, "call SetNvimcomInfo('%s', %d, '%ld', '%s')", nvv,
             R_PID, (long)GetForegroundWindow(), r_info);
#endif
#else
    if (getenv("WINDOWID"))
        snprintf(msg, 2175, "call SetNvimcomInfo('%s', %d, '%s', '%s')", nvv,
                 R_PID, getenv("WINDOWID"), r_info);
    else
        snprintf(msg, 2175, "call SetNvimcomInfo('%s', %d, '0', '%s')", nvv,
                 R_PID, r_info);
#endif
    send_to_nvim(msg);
}

/**
 * @brief Parse messages received from nvimrserver
 *
 * @param buf The message though the TCP connection
 */
static void nvimcom_parse_received_msg(char *buf) {
    char *p;

    if (verbose > 3) {
        REprintf("nvimcom received: %s\n", buf);
    } else if (verbose > 2) {
        p = buf + strlen(getenv("NVIMR_ID")) + 1;
        REprintf("nvimcom Received: [%c] %s\n", buf[0], p);
    }

    switch (buf[0]) {
    case 'A':
        autoglbenv = 1;
        break;
    case 'N':
        autoglbenv = 0;
        break;
    case 'G':
#ifdef WIN32
        if (!r_is_busy)
            nvimcom_globalenv_list();
#else
        flag_glbenv = 1;
        nvimcom_fire();
#endif
        break;
#ifdef WIN32
    case 'C': // Send command to Rgui Console
        p = buf;
        p++;
        if (strstr(p, getenv("NVIMR_ID")) == p) {
            p += strlen(getenv("NVIMR_ID"));
            r_is_busy = 1;
            Rconsolecmd(p);
        }
        break;
#endif
    case 'L': // Evaluate lazy object
#ifdef WIN32
        if (r_is_busy)
            break;
#endif
        p = buf;
        p++;
        if (strstr(p, getenv("NVIMR_ID")) == p) {
            p += strlen(getenv("NVIMR_ID"));
#ifdef WIN32
            char flag_eval[512];
            snprintf(flag_eval, 510, "%s <- %s", p, p);
            nvimcom_eval_expr(flag_eval);
            *flag_eval = 0;
            nvimcom_globalenv_list();
#else
            snprintf(flag_eval, 510, "%s <- %s", p, p);
            flag_glbenv = 1;
            nvimcom_fire();
#endif
        }
        break;
    case 'E': // eval expression
        p = buf;
        p++;
        if (strstr(p, getenv("NVIMR_ID")) == p) {
            p += strlen(getenv("NVIMR_ID"));
#ifdef WIN32
            if (!r_is_busy)
                nvimcom_eval_expr(p);
#else
            strncpy(flag_eval, p, 510);
            nvimcom_fire();
#endif
        } else {
            REprintf("\nvimcom: received invalid NVIMR_ID.\n");
        }
        break;
    default: // do nothing
        REprintf("\nError [nvimcom]: Invalid message received: %s\n", buf);
        break;
    }
}

#ifdef WIN32
/**
 * @brief Loop to receive TCP messages from nvimrserver
 *
 * @param unused Unused parameter.
 */
static DWORD WINAPI client_loop_thread(__attribute__((unused)) void *arg)
#else
/**
 * @brief Loop to receive TCP messages from nvimrserver
 *
 * @param unused Unused parameter.
 */
static void *client_loop_thread(__attribute__((unused)) void *arg)
#endif
{
    size_t len;
    for (;;) {
        char buff[1024];
        memset(buff, '\0', sizeof(buff));
        len = recv(sfd, buff, sizeof(buff), 0);
#ifdef WIN32
        if (len == 0 || buff[0] == 0 || buff[0] == EOF ||
            strstr(buff, "QuitNow") == buff)
#else
        if (len == 0 || buff[0] == 0 || buff[0] == EOF)
#endif
        {
            if (len == 0)
                REprintf("Connection with nvimrserver was lost\n");
            if (buff[0] == EOF)
                REprintf("client_loop_thread: buff[0] == EOF\n");
#ifdef WIN32
            closesocket(sfd);
            WSACleanup();
#else
            close(sfd);
#endif
            break;
        }
        nvimcom_parse_received_msg(buff);
    }
#ifdef WIN32
    return 0;
#else
    return NULL;
#endif
}

/**
 * @brief Set variables that will control nvimcom behavior and establish a TCP
 * connection with nvimrserver in a new thread. This function is called when
 * nvimcom package is attached (See `.onAttach()` at R/nvimcom.R).
 *
 * @param vrb Verbosity level (`nvimcom.verbose` in ~/.Rprofile).
 *
 * @param anm Should names with starting with a dot be included in completion
 * lists? (`R_objbr_allnames` in init.vim).
 *
 * @param swd Should nvimcom set the option "width" after the execution of
 * each command? (`R_setwidth` in init.vim).
 *
 * @param age Should the list of objects in .GlobalEnv be automatically
 * updated? (`R_objbr_allnames` in init.vim)
 *
 * @param dbg Should detect when `broser()` is running and start debugging
 * mode? (`R_debug` in init.vim)
 *
 * @param nvv nvimcom version
 *
 * @param rinfo Information on R to be passed to nvim.
 */
void nvimcom_Start(int *vrb, int *anm, int *swd, int *age, int *dbg, char **nvv,
                   char **rinfo) {
    verbose = *vrb;
    allnames = *anm;
    setwidth = *swd;
    autoglbenv = *age;
    debug_r = *dbg;

    if (getenv("NVIMR_TMPDIR")) {
        strncpy(tmpdir, getenv("NVIMR_TMPDIR"), 500);
        if (getenv("NVIMR_SECRET"))
            strncpy(nvimsecr, getenv("NVIMR_SECRET"), 31);
        else
            REprintf(
                "nvimcom: Environment variable NVIMR_SECRET is missing.\n");
    } else {
        if (verbose)
            REprintf("nvimcom: It seems that R was not started by Neovim. The "
                     "communication with Nvim-R will not work.\n");
        tmpdir[0] = 0;
        return;
    }

    if (getenv("NVIMR_PORT"))
        strncpy(nrs_port, getenv("NVIMR_PORT"), 15);

    if (verbose > 0)
        REprintf("nvimcom %s loaded\n", *nvv);
    if (verbose > 1) {
        if (getenv("NVIM_IP_ADDRESS")) {
            REprintf("  NVIM_IP_ADDRESS: %s\n", getenv("NVIM_IP_ADDRESS"));
        }
        REprintf("  NVIMR_PORT: %s\n", nrs_port);
        REprintf("  NVIMR_ID: %s\n", getenv("NVIMR_ID"));
        REprintf("  NVIMR_TMPDIR: %s\n", tmpdir);
        REprintf("  NVIMR_COMPLDIR: %s\n", getenv("NVIMR_COMPLDIR"));
        REprintf("  R info: %s\n\n", *rinfo);
    }

    tcp_header_len = strlen(nvimsecr) + 9;
    glbnvbuf1 = (char *)calloc(glbnvbufsize, sizeof(char));
    glbnvbuf2 = (char *)calloc(glbnvbufsize, sizeof(char));
    send_ge_buf = (char *)calloc(glbnvbufsize + 64, sizeof(char));
    if (!glbnvbuf1 || !glbnvbuf2 || !send_ge_buf)
        REprintf("nvimcom: Error allocating memory.\n");

#ifndef WIN32
    *flag_eval = 0;
    int fds[2];
    if (pipe(fds) == 0) {
        ifd = fds[0];
        ofd = fds[1];
        ih = addInputHandler(R_InputHandlers, ifd, &nvimcom_uih, 32);
    } else {
        REprintf("nvimcom error: pipe != 0\n");
        ih = NULL;
    }
#endif

    static int failure = 0;

    if (atoi(nrs_port) > 0) {
        struct sockaddr_in servaddr;
#ifdef WIN32
        WSADATA d;
        int wr = WSAStartup(MAKEWORD(2, 2), &d);
        if (wr != 0) {
            REprintf("WSAStartup failed: %d\n", wr);
        }
#endif
        // socket create and verification
        sfd = socket(AF_INET, SOCK_STREAM, 0);
        if (sfd != -1) {
            memset(&servaddr, '\0', sizeof(servaddr));

            // assign IP, PORT
            servaddr.sin_family = AF_INET;
            if (getenv("NVIM_IP_ADDRESS"))
                servaddr.sin_addr.s_addr = inet_addr(getenv("NVIM_IP_ADDRESS"));
            else
                servaddr.sin_addr.s_addr = inet_addr("127.0.0.1");
            servaddr.sin_port = htons(atoi(nrs_port));

            // connect the client socket to server socket
            if (connect(sfd, (struct sockaddr *)&servaddr, sizeof(servaddr)) ==
                0) {
#ifdef WIN32
                DWORD ti;
                tid = CreateThread(NULL, 0, client_loop_thread, NULL, 0, &ti);
#else
                pthread_create(&tid, NULL, client_loop_thread, NULL);
#endif
                nvimcom_send_running_info(*rinfo, *nvv);
            } else {
                REprintf("nvimcom: connection with the server failed (%s)\n",
                         nrs_port);
                failure = 1;
            }
        } else {
            REprintf("nvimcom: socket creation failed (%d)\n", atoi(nrs_port));
            failure = 1;
        }
    }

    if (failure == 0) {
        Rf_addTaskCallback(nvimcom_task, NULL, free, "NVimComHandler", NULL);

        initialized = 1;

#ifdef WIN32
        r_is_busy = 0;
#else
        if (debug_r) {
            save_ptr_R_ReadConsole = ptr_R_ReadConsole;
            ptr_R_ReadConsole = nvimcom_read_console;
        }
#endif
        nvimcom_checklibs();
        needs_lib_msg = 0;
        send_libnames();
    }
}

/**
 * @brief Close the TCP connection with nvimrserver and do other cleanup.
 * This function is called by `.onUnload()` at R/nvimcom.R.
 */
void nvimcom_Stop(void) {
#ifndef WIN32
    if (ih) {
        removeInputHandler(&R_InputHandlers, ih);
        close(ifd);
        close(ofd);
    }
#endif

    if (initialized) {
        Rf_removeTaskCallbackByName("NVimComHandler");
#ifdef WIN32
        closesocket(sfd);
        WSACleanup();
        TerminateThread(tid, 0);
        CloseHandle(tid);
#else
        if (debug_r)
            ptr_R_ReadConsole = save_ptr_R_ReadConsole;
        close(sfd);
        pthread_cancel(tid);
        pthread_join(tid, NULL);
#endif

        LibInfo *lib = libList;
        LibInfo *tmp;
        while (lib) {
            tmp = lib->next;
            free(lib->name);
            free(lib);
            lib = tmp;
        }

        if (glbnvbuf1)
            free(glbnvbuf1);
        if (glbnvbuf2)
            free(glbnvbuf2);
        if (send_ge_buf)
            free(send_ge_buf);
        if (verbose)
            REprintf("nvimcom stopped\n");
    }
    initialized = 0;
}
