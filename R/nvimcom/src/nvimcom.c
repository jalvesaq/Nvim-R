#include <R.h>  /* to include Rconfig.h */
#include <Rinternals.h>
#include <R_ext/Parse.h>
#include <R_ext/Callbacks.h>
#ifndef WIN32
#define HAVE_SYS_SELECT_H
#include <R_ext/eventloop.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <sys/types.h>
#include <time.h>

#ifdef WIN32
#include <winsock2.h>
#include <process.h>
#ifdef _WIN64
#include <inttypes.h>
#endif
#define bzero(b,len) (memset((b), '\0', (len)), (void) 0)
#else
#include <stdint.h>
#include <arpa/inet.h> // inet_addr()
#include <sys/socket.h>
#include <netdb.h>
#include <pthread.h>
#include <signal.h>
#endif

#ifndef WIN32
// Needed to know what is the prompt
#include <Rinterface.h>
#define R_INTERFACE_PTRS 1
extern int (*ptr_R_ReadConsole)(const char *, unsigned char *, int, int);
static int (*save_ptr_R_ReadConsole)(const char *, unsigned char *, int, int);
static int debugging;
LibExtern SEXP  R_SrcfileSymbol; // Defn.h
static void SrcrefInfo(void);
#endif
static int debug_r;

static char nvimcom_version[32];

static pid_t R_PID;

static int nvimcom_initialized = 0;
static int verbose = 0; // 1: version number; 2: initial information; 3: TCP in and out; 4: realy verbose
static int allnames = 0;
static int nvimcom_failure = 0;
static int nlibs = 0;
static int needs_lib_msg = 0;
static int needs_glbenv_msg = 0;
static char nrs_port[16];
static char nvimsecr[32];

static char *glbnvbuf1;
static char *glbnvbuf2;
static char *send_ge_buf;
static unsigned long lastglbnvbsz;
static unsigned long glbnvbufsize = 32768;

static unsigned long tcp_header_len;

static int maxdepth = 6;
static int curdepth = 0;
static int autoglbenv = 0;
static clock_t tm;

static char tmpdir[512];
static int setwidth = 0;   // Set the option width after each command is executed
static int oldcolwd = 0;   // Last set width

#ifdef WIN32
static int r_is_busy = 1;
#else
static int fired = 0;
static char flag_eval[512];
static int flag_glbenv = 0;
static int flag_debug = 0;
static int ifd, ofd;
static InputHandler *ih;
#endif

typedef struct pkg_info_ {
    char *name;
    char *version;
    unsigned long strlen;
    struct pkg_info_ *next;
} PkgInfo;

PkgInfo *pkgList;


static int nvimcom_checklibs(void);
static void send_to_nvim(char *msg);
static void nvimcom_eval_expr(const char *buf);

#ifdef WIN32
SOCKET sfd;
static HANDLE tid;
extern void Rconsolecmd(char *cmd); // Defined in R: src/gnuwin32/rui.c
#else
static int sfd = -1;
static pthread_t tid;
#endif

static char *nvimcom_strcat(char* dest, const char* src)
{
    while(*dest) dest++;
    while((*dest++ = *src++));
    return --dest;
}

static char *nvimcom_grow_buffers(void)
{
    lastglbnvbsz = glbnvbufsize;
    glbnvbufsize += 32768;

    char *tmp = (char*)calloc(glbnvbufsize, sizeof(char));
    strcpy(tmp, glbnvbuf1);
    free(glbnvbuf1);
    glbnvbuf1 = tmp;

    tmp = (char*)calloc(glbnvbufsize, sizeof(char));
    strcpy(tmp, glbnvbuf2);
    free(glbnvbuf2);
    glbnvbuf2 = tmp;

    tmp = (char*)calloc(glbnvbufsize + 64, sizeof(char));
    free(send_ge_buf);
    send_ge_buf = tmp;

    return(glbnvbuf2 + strlen(glbnvbuf2));
}

static void send_to_nvim(char *msg)
{
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
       Note: the time of saving the file at /dev/shm is bigger than the time of
       sending the buffer through a TCP connection.

       TCP message format:
         NVIMR_SECRET : Prefix NVIMR_SECRET to msg to increase security
         000000000    : Size of message in 9 digits
         msg          : The message
         \001         : Final byte

       Note: when the msg is very big, it's faster to send the final message in
       three pieces than to call snprintf() to assemble everything in a single
       message.
    */

    snprintf(b, 63, "%s%09zu", nvimsecr, len);
    //sent = write(sfd, b, tcp_header_len);
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
        return;
    }

    // based on code found on php source
    char *pCur = msg;
    char *pEnd = msg + len;
    int loop = 0;
    while (pCur < pEnd) {
        sent = send(sfd, pCur, pEnd - pCur, 0);
        if (sent >= 0) {
            pCur += sent;
            if (pCur > pEnd) {
                // TODO: delete this check because it's supposed to be impossible to happen
                REprintf("Impossible error sending message to Nvim-R: %zu x %zu\n",
                        len, pCur - msg);
                return;
            }
        } else if (sent == -1) {
            REprintf("Error sending message to Nvim-R: %zu x %zu\n",
                    len, pCur - msg);
            return;
        }
        loop++;
        if (loop == 100) {
            // The goal here is to avoid infinite loop.
            // TODO: Maybe delete this check because php code does not have something similar
            REprintf("Too many attempts to send message to Nvim-R: %zu x %zu\n",
                    len, sent);
            return;
        }
    }

    // End the message with \001
    sent = send(sfd, "\001", 1, 0);
    if (sent != 1)
        REprintf("Error sending final byte to Nvim-R: 1 x %zu\n", sent);
}

void nvimcom_msg_to_nvim(char **cmd)
{
    send_to_nvim(*cmd);
}

static void nvimcom_squo(const char *buf, char *buf2, int bsize)
{
    int i = 0, j = 0;
    while(j < bsize){
        if(buf[i] == '\''){
            buf2[j] = '\'';
            j++;
            buf2[j] = '\'';
        } else if(buf[i] == 0) {
            buf2[j] = 0;
            break;
        } else {
            buf2[j] = buf[i];
        }
        i++;
        j++;
    }
}

static void nvimcom_backtick(const char *b1, char *b2)
{
    int i = 0, j = 0;
    while (i < 511 && b1[i] != '$' && b1[i] != '@' && b1[i] != 0) {
        if (b1[i] == '[' && b1[i+1] == '[') {
            b2[j] = '[';
            i++; j++;
            b2[j] = '[';
            i++; j++;
        } else {
            b2[j] = '`';
            j++;
        }
        while (i < 511 && b1[i] != '$' && b1[i] != '@' && b1[i] != '[' && b1[i] != 0) {
            b2[j] = b1[i];
            i++; j++;
        }
        if (b1[i-1] != ']') {
            b2[j] = '`';
            j++;
        }
        if (b1[i] == 0)
            break;
        if (b1[i] != '[') {
            b2[j] = b1[i];
            i++; j++;
        }
    }
    b2[j] = 0;
}

static PkgInfo *nvimcom_pkg_info_new(const char *nm, const char *vrsn)
{
    PkgInfo *pi = calloc(1, sizeof(PkgInfo));
    pi->name = malloc((strlen(nm)+1) * sizeof(char));
    strcpy(pi->name, nm);
    pi->version = malloc((strlen(vrsn)+1) * sizeof(char));
    strcpy(pi->version, vrsn);
    pi->strlen = strlen(pi->name) + strlen(pi->version) + 2;
    return pi;
}

static void nvimcom_pkg_info_add(const char *nm, const char *vrsn)
{
    PkgInfo *pi = nvimcom_pkg_info_new(nm, vrsn);
    if(pkgList){
        pi->next = pkgList;
        pkgList = pi;
    } else {
        pkgList = pi;
    }
}

PkgInfo *nvimcom_get_pkg(const char *nm)
{
    if(!pkgList)
        return NULL;

    PkgInfo *pi = pkgList;
    do{
        if(strcmp(pi->name, nm) == 0)
            return pi;
        pi = pi->next;
    } while(pi);

    return NULL;
}

static char *nvimcom_glbnv_line(SEXP *x, const char *xname, const char *curenv, char *p, int depth)
{
    if(depth > maxdepth)
        return p;

    if(depth > curdepth)
        curdepth = depth;

    int xgroup = 0; // 1 = function, 2 = data.frame, 3 = list, 4 = s4
    char newenv[576];
    char curenvB[512];
    char ebuf[64];
    int len;
    const char *ename;
    SEXP listNames, label, lablab, eexp, elmt = R_NilValue;
    SEXP cmdSexp, cmdexpr, ans, cmdSexp2, cmdexpr2;
    ParseStatus status, status2;
    int er = 0;
    char buf[576];
    char bbuf[512];
    char *ptr;

    if((strlen(glbnvbuf2 + lastglbnvbsz)) > 31744)
        p = nvimcom_grow_buffers();

    p = nvimcom_strcat(p, curenv);
    snprintf(ebuf, 63, "%s", xname);
    p = nvimcom_strcat(p, ebuf);

    if(Rf_isLogical(*x)){
        p = nvimcom_strcat(p, "\006%\006");
    } else if(Rf_isNumeric(*x)){
        p = nvimcom_strcat(p, "\006{\006");
    } else if(Rf_isFactor(*x)){
        p = nvimcom_strcat(p, "\006!\006");
    } else if(Rf_isValidString(*x)){
        p = nvimcom_strcat(p, "\006~\006");
    } else if(Rf_isFunction(*x)){
        p = nvimcom_strcat(p, "\006\003\006");
        xgroup = 1;
    } else if(Rf_isFrame(*x)){
        p = nvimcom_strcat(p, "\006$\006");
        xgroup = 2;
    } else if(Rf_isNewList(*x)){
        p = nvimcom_strcat(p, "\006[\006");
        xgroup = 3;
    } else if(Rf_isS4(*x)){
        p = nvimcom_strcat(p, "\006<\006");
        xgroup = 4;
    } else if(Rf_isEnvironment(*x)){
        p = nvimcom_strcat(p, "\006:\006");
    } else if(TYPEOF(*x) == PROMSXP){
        p = nvimcom_strcat(p, "\006&\006");
    } else {
        p = nvimcom_strcat(p, "\006*\006");
    }

    // Specific class of object, if any
    PROTECT(label = getAttrib(*x, R_ClassSymbol));
    if(!isNull(label)){
        p = nvimcom_strcat(p, CHAR(STRING_ELT(label, 0)));
    }
    UNPROTECT(1);

    p = nvimcom_strcat(p, "\006.GlobalEnv\006");

    if(xgroup == 2){
        snprintf(buf, 127, "\006\006 [%d, %d]\006\n", length(Rf_GetRowNames(*x)), length(*x));
        p = nvimcom_strcat(p, buf);
    } else if(xgroup == 3){
        snprintf(buf, 127, "\006\006 [%d]\006\n", length(*x));
        p = nvimcom_strcat(p, buf);
    } else if(xgroup == 1){
        /* It would be necessary to port args2buff() from src/main/deparse.c to here but it's too big.
           So, it's better to call nvimcom:::nvim.args() during omni completion.
           FORMALS() may return an object that will later crash R:
           https://github.com/jalvesaq/Nvim-R/issues/543#issuecomment-748981771 */
        p = nvimcom_strcat(p, "['not_checked']\006\006\006\n");
    } else {
        PROTECT(lablab = allocVector(STRSXP, 1));
        SET_STRING_ELT(lablab, 0, mkChar("label"));
        PROTECT(label = getAttrib(*x, lablab));
        if(length(label) > 0){
            if(Rf_isValidString(label)){
                snprintf(buf, 159, "\006\006%s", CHAR(STRING_ELT(label, 0)));
                ptr = buf;
                while (*ptr) {
                    if (*ptr == '\n') // A new line will make nvimrserver crash
                        *ptr = ' ';
                    ptr++;
                }
                p = nvimcom_strcat(p, buf);
                p = nvimcom_strcat(p, "\006\n"); // The new line must be added here because the label will be truncated if too long.
            } else {
                p = nvimcom_strcat(p, "\006\006Error: label is not a valid string.\006\n");
            }
        } else {
            p = nvimcom_strcat(p, "\006\006\006\n");
        }
        UNPROTECT(2);
    }

    if(xgroup > 1){
        if(1000 * ((double)clock() - tm) / CLOCKS_PER_SEC > 300.0){
            maxdepth = curdepth;
            return p;
        }

        strncpy(curenvB, curenv, 500);
        if(xgroup == 4) // S4 object
            snprintf(newenv, 575, "%s%s@", curenvB, xname);
        else
            snprintf(newenv, 575, "%s%s$", curenvB, xname);

        if(xgroup == 4){
            snprintf(buf, 575, "%s%s", curenvB, xname);
            nvimcom_backtick(buf, bbuf);
            snprintf(buf, 575, "slotNames(%s)", bbuf);
            PROTECT(cmdSexp = allocVector(STRSXP, 1));
            SET_STRING_ELT(cmdSexp, 0, mkChar(buf));
            PROTECT(cmdexpr = R_ParseVector(cmdSexp, -1, &status, R_NilValue));

            if (status != PARSE_OK) {
                REprintf("nvimcom error: invalid value in slotNames(%s%s)\n", curenvB, xname);
            } else {
                PROTECT(ans = R_tryEval(VECTOR_ELT(cmdexpr, 0), R_GlobalEnv, &er));
                if(er){
                    REprintf("nvimcom error executing command: slotNames(%s%s)\n", curenvB, xname);
                } else {
                    len = length(ans);
                    // Remove the newline and the \006 delimiters and add the S4 object length
                    p--; p--; p--; p--;
                    *p = 0;
                    snprintf(buf, 127, "\006\006 [%d]\006\n", len);
                    p = nvimcom_strcat(p, buf);
                    if(len > 0){
                        for(int i = 0; i < len; i++){
                            ename = CHAR(STRING_ELT(ans, i));
                            snprintf(buf, 575, "%s%s@%s", curenvB, xname, ename);
                            nvimcom_backtick(buf, bbuf);
                            PROTECT(cmdSexp2 = allocVector(STRSXP, 1));
                            SET_STRING_ELT(cmdSexp2, 0, mkChar(bbuf));
                            PROTECT(cmdexpr2 = R_ParseVector(cmdSexp2, -1, &status2, R_NilValue));
                            if (status2 != PARSE_OK) {
                                REprintf("nvimcom error: invalid code \"%s@%s\"\n", xname, ename);
                            } else {
                                PROTECT(elmt = R_tryEvalSilent(VECTOR_ELT(cmdexpr2, 0), R_GlobalEnv, &er));
                                if(!er)
                                    p = nvimcom_glbnv_line(&elmt, ename, newenv, p, depth + 1);
                                UNPROTECT(1);
                            }
                            UNPROTECT(2);
                        }
                    }
                }
                UNPROTECT(1);
            }
            UNPROTECT(2);
        } else {
            PROTECT(listNames = getAttrib(*x, R_NamesSymbol));
            len = length(listNames);
            if(len == 0){ /* Empty list? */
                int len1 = length(*x);
                if(len1 > 0){ /* List without names */
                    len1 -= 1;
                    if(newenv[strlen(newenv)-1] == '$')
                        newenv[strlen(newenv)-1] = 0; // Delete trailing '$'
                    for(int i = 0; i < len1; i++){
                        sprintf(ebuf, "[[%d]]", i + 1);
                        elmt = VECTOR_ELT(*x, i);
                        p = nvimcom_glbnv_line(&elmt, ebuf, newenv, p, depth + 1);
                    }
                    sprintf(ebuf, "[[%d]]", len1 + 1);
                    PROTECT(elmt = VECTOR_ELT(*x, len));
                    p = nvimcom_glbnv_line(&elmt, ebuf, newenv, p, depth + 1);
                    UNPROTECT(1);
                }
            } else { /* Named list */
                len -= 1;
                for(int i = 0; i < len; i++){
                    PROTECT(eexp = STRING_ELT(listNames, i));
                    ename = CHAR(eexp);
                    UNPROTECT(1);
                    if(ename[0] == 0){
                        sprintf(ebuf, "[[%d]]", i + 1);
                        ename = ebuf;
                    }
                    PROTECT(elmt = VECTOR_ELT(*x, i));
                    p = nvimcom_glbnv_line(&elmt, ename, newenv, p, depth + 1);
                    UNPROTECT(1);
                }
                ename = CHAR(STRING_ELT(listNames, len));
                if(ename[0] == 0){
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

static void nvimcom_globalenv_list(void)
{
    if (verbose > 4)
        REprintf("nvimcom_globalenv_list()\n");
    const char *varName;
    SEXP envVarsSEXP, varSEXP;

    if(tmpdir[0] == 0)
        return;

    tm = clock();

    memset(glbnvbuf2, 0, glbnvbufsize);
    char *p = glbnvbuf2;

    curdepth = 0;

    PROTECT(envVarsSEXP = R_lsInternal(R_GlobalEnv, allnames));
    for(int i = 0; i < Rf_length(envVarsSEXP); i++){
        varName = CHAR(STRING_ELT(envVarsSEXP, i));
        if (R_BindingIsActive(Rf_install(varName), R_GlobalEnv)) {
            // See: https://github.com/jalvesaq/Nvim-R/issues/686
            PROTECT(varSEXP = R_ActiveBindingFunction(Rf_install(varName), R_GlobalEnv));
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

    int len1 = strlen(glbnvbuf1);
    int len2 = strlen(glbnvbuf2);
    int changed = len1 != len2;
    if (verbose > 4)
        REprintf("globalenv_list(0) len1 = %zu, len2 = %zu\n", len1, len2);
    if(!changed){
        for(int i = 0; i < len1; i++){
            if(glbnvbuf1[i] != glbnvbuf2[i]){
                changed = 1;
                break;
            }
        }
    }

    if (changed)
        needs_glbenv_msg = 1;

    double tmdiff = 1000 * ((double)clock() - tm) / CLOCKS_PER_SEC;
    if (verbose && tmdiff > 1000.0)
        REprintf("Time to build GlobalEnv omnils [%lu bytes]: %f ms\n", strlen(glbnvbuf2), tmdiff);
    if (tmdiff > 300.0){
        maxdepth = curdepth - 1;
    } else {
        // NOTE: There is a high risk of zig zag effect. It would be
        // better to have a smarter algorithm to decide when to
        // increase maxdepth, but this is not feasible with the current
        // nvimcom_glbnv_line() function.
        if(tmdiff < 30.0 && maxdepth <= curdepth){
            maxdepth = curdepth + 1;
        }
    }
}

static void send_glb_env(void)
{
    clock_t t1;

    t1 = clock();

    strcpy(send_ge_buf, "+G");
    strcat(send_ge_buf, glbnvbuf2);
    send_to_nvim(send_ge_buf);

    if (verbose > 3)
        REprintf("Time to send message to Nvim-R: %f\n", 1000 * ((double)clock() - t1) / CLOCKS_PER_SEC);

    char *tmp = glbnvbuf1;
    glbnvbuf1 = glbnvbuf2;
    glbnvbuf2 = tmp;
}

static void nvimcom_eval_expr(const char *buf)
{
    if(verbose > 3)
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
        if(er && verbose > 1){
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

static void send_libnames(void)
{
    PkgInfo *pkg;
    unsigned long totalsz = 9;
    char *libbuf;
    pkg = pkgList;
    do {
        totalsz += pkg->strlen;
        pkg = pkg->next;
    } while (pkg);

    libbuf = malloc(totalsz + 1);

    libbuf[0] = 0;
    nvimcom_strcat(libbuf, "+L");
    pkg = pkgList;
    do {
        nvimcom_strcat(libbuf, pkg->name);
        nvimcom_strcat(libbuf, "\003");
        nvimcom_strcat(libbuf, pkg->version);
        nvimcom_strcat(libbuf, "\004");
        pkg = pkg->next;
    } while (pkg);
    libbuf[totalsz] = 0;
    send_to_nvim(libbuf);
    free(libbuf);
}

static int nvimcom_checklibs(void)
{
    const char *libname;
    char *libn;
    char buf[128];
    ParseStatus status;
    int er = 0;
    SEXP a, l;
    SEXP cmdSexp, cmdexpr, ans;

    PkgInfo *pkg;

    PROTECT(a = eval(lang1(install("search")), R_GlobalEnv));

    int newnlibs = Rf_length(a);
    if(nlibs == newnlibs)
        return(nlibs);

    nlibs = newnlibs;

    needs_lib_msg = 1;

    for(int i = 0; i < newnlibs; i++){
        PROTECT(l = STRING_ELT(a, i));
        libname = CHAR(l);
        libn = strstr(libname, "package:");
        if(libn != NULL){
            libn = strstr(libn, ":");
            libn++;
            pkg = nvimcom_get_pkg(libn);
            if(!pkg){
                snprintf(buf, 127, "utils::packageDescription('%s')$Version", libn);
                PROTECT(cmdSexp = allocVector(STRSXP, 1));
                SET_STRING_ELT(cmdSexp, 0, mkChar(buf));
                PROTECT(cmdexpr = R_ParseVector(cmdSexp, -1, &status, R_NilValue));
                if (status != PARSE_OK) {
                    REprintf("nvimcom error parsing: %s\n", buf);
                } else {
                    PROTECT(ans = R_tryEval(VECTOR_ELT(cmdexpr, 0), R_GlobalEnv, &er));
                    if(er){
                        REprintf("nvimcom error executing: %s\n", buf);
                    } else {
                        nvimcom_pkg_info_add(libn, CHAR(STRING_ELT(ans, 0)));
                    }
                    UNPROTECT(1);
                }
                UNPROTECT(2);
            }
        }
        UNPROTECT(1);
    }
    UNPROTECT(1);

    return(newnlibs);
}

static Rboolean nvimcom_task(__attribute__((unused))SEXP expr,
        __attribute__((unused))SEXP value,
        __attribute__((unused))Rboolean succeeded,
        __attribute__((unused))Rboolean visible,
        __attribute__((unused))void *userData)
{
    if (verbose > 4)
        REprintf("nvimcom_task()\n");
#ifdef WIN32
    r_is_busy = 0;
#endif
    if (nrs_port[0] != 0) {
        nvimcom_checklibs();
        if(autoglbenv)
            nvimcom_globalenv_list();
        if (needs_lib_msg)
            send_libnames();
        if (needs_glbenv_msg)
            send_glb_env();
        needs_lib_msg = 0;
        needs_glbenv_msg = 0;
    }
    if(setwidth && getenv("COLUMNS")){
        int columns = atoi(getenv("COLUMNS"));
        if(columns > 0 && columns != oldcolwd){
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

            if(verbose > 2)
                Rprintf("nvimcom: width = %d columns\n", columns);
        }
    }
    /* send_to_nvim("call RTaskCompleted()"); */
    return(TRUE);
}

#ifndef WIN32
static void nvimcom_exec(__attribute__((unused))void *nothing){
    if(*flag_eval){
        nvimcom_eval_expr(flag_eval);
        *flag_eval = 0;
    }
    if(flag_glbenv){
        nvimcom_globalenv_list();
        flag_glbenv = 0;
    }
    if(flag_debug){
        SrcrefInfo();
        flag_debug = 0;
    }
}

/* Code adapted from CarbonEL.
 * Thanks to Simon Urbanek for the suggestion on r-devel mailing list. */
static void nvimcom_uih(__attribute__((unused))void *data) {
    if (verbose > 4)
        REprintf("nvimcom_uih()\n");
    char buf[16];
    if(read(ifd, buf, 1) < 1)
        REprintf("nvimcom error: read < 1\n");
    R_ToplevelExec(nvimcom_exec, NULL);
    fired = 0;
}

static void nvimcom_fire(void)
{
    if (verbose > 4)
        REprintf("nvimcom_fire()\n");
    if(fired)
        return;
    fired = 1;
    char buf[16];
    *buf = 0;
    if(write(ofd, buf, 1) <= 0)
        REprintf("nvimcom error: write <= 0\n");
}

// Adapted from SrcrefPrompt(), at src/main/eval.c
static void SrcrefInfo(void)
{
    if(debugging == 0){
        send_to_nvim("call StopRDebugging()");
        return;
    }
    /* If we have a valid R_Srcref, use it */
    if (R_Srcref && R_Srcref != R_NilValue) {
        if (TYPEOF(R_Srcref) == VECSXP) R_Srcref = VECTOR_ELT(R_Srcref, 0);
        SEXP srcfile = getAttrib(R_Srcref, R_SrcfileSymbol);
        if (TYPEOF(srcfile) == ENVSXP) {
            SEXP filename = findVar(install("filename"), srcfile);
            if (isString(filename) && length(filename)) {
                size_t slen = strlen(CHAR(STRING_ELT(filename, 0)));
                char *buf = calloc(sizeof(char), (2 * slen + 32));
                char *buf2 = calloc(sizeof(char), (2 * slen + 32));
                snprintf(buf, 2 * slen + 1, "%s", CHAR(STRING_ELT(filename, 0)));
                nvimcom_squo(buf, buf2, 2 * slen + 32);
                snprintf(buf, 2 * slen + 31, "call RDebugJump('%s', %d)", buf2, asInteger(R_Srcref));
                send_to_nvim(buf);
                free(buf);
                free(buf2);
            }
        }
    }
}

static int nvimcom_read_console(const char *prompt,
        unsigned char *buf, int len, int addtohistory)
{
    if(debugging == 1){
        if(prompt[0] != 'B')
            debugging = 0;
        flag_debug = 1;
        nvimcom_fire();
    } else {
        if(prompt[0] == 'B' && prompt[1] == 'r' && prompt[2] == 'o' && prompt[3] == 'w' &&
                prompt[4] == 's' && prompt[5] == 'e' && prompt[6] == '['){
            debugging = 1;
            flag_debug = 1;
            nvimcom_fire();
        }
    }
    return save_ptr_R_ReadConsole(prompt, buf, len, addtohistory);
}
#endif

static void nvimcom_send_running_info(const char *r_info)
{
    char msg[2176];
#ifdef WIN32
#ifdef _WIN64
    snprintf(msg, 2175, "call SetNvimcomInfo('%s', %" PRId64 ", '%" PRId64 "', '%s')",
            nvimcom_version, R_PID,
            (long long)GetForegroundWindow(), r_info);
#else
    snprintf(msg, 2175, "call SetNvimcomInfo('%s', %d, '%ld', '%s')",
            nvimcom_version, R_PID,
            (long)GetForegroundWindow(), r_info);
#endif
#else
    if(getenv("WINDOWID"))
        snprintf(msg, 2175, "call SetNvimcomInfo('%s', %d, '%s', '%s')",
                nvimcom_version, R_PID,
                getenv("WINDOWID"), r_info);
    else
        snprintf(msg, 2175, "call SetNvimcomInfo('%s', %d, '0', '%s')",
                nvimcom_version, R_PID, r_info);
#endif
    send_to_nvim(msg);
}

static void nvimcom_parse_received_msg(char *buf)
{
    char *p;

    if(verbose > 3){
        REprintf("nvimcom received: %s\n", buf);
    } else if(verbose > 2){
        p = buf + strlen(getenv("NVIMR_ID")) + 1;
        REprintf("nvimcom Received: [%c] %s\n", buf[0], p);
    }

    switch(buf[0]){
        case 'A':
            autoglbenv = 1;
            break;
        case 'N':
            autoglbenv = 0;
            break;
        case 'G':
#ifdef WIN32
            if(!r_is_busy)
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
            if(strstr(p, getenv("NVIMR_ID")) == p){
                p += strlen(getenv("NVIMR_ID"));
                r_is_busy = 1;
                Rconsolecmd(p);
            }
            break;
#endif
        case 'L': // Evaluate lazy object
#ifdef WIN32
            if(r_is_busy)
                break;
#endif
            p = buf;
            p++;
            if(strstr(p, getenv("NVIMR_ID")) == p){
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
            if(strstr(p, getenv("NVIMR_ID")) == p){
                p += strlen(getenv("NVIMR_ID"));
#ifdef WIN32
                if(!r_is_busy)
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
static DWORD WINAPI server_thread(__attribute__((unused))void *arg)
#else
static void *server_thread(__attribute__((unused))void *arg)
#endif
{
    size_t len;
    for (;;) {
        char buff[1024];
        bzero(buff, sizeof(buff));
        len = recv(sfd, buff, sizeof(buff), 0);
#ifdef WIN32
        if (len == 0 || buff[0] == 0 || buff[0] == EOF || strstr(buff, "QuitNow") == buff)
#else
        if (len == 0 || buff[0] == 0 || buff[0] == EOF)
#endif
        {
            if (len == 0)
                REprintf("Connection with nvimrserver was lost\n");
            if (buff[0] == EOF)
                REprintf("server_thread: buff[0] == EOF\n");
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

void nvimcom_Start(int *vrb, int *anm, int *swd, int *age, int *dbg, char **vcv, char **rinfo)
{
    verbose = *vrb;
    allnames = *anm;
    setwidth = *swd;
    autoglbenv = *age;
    debug_r = *dbg;

    R_PID = getpid();
    strncpy(nvimcom_version, *vcv, 31);

    if(getenv("NVIMR_TMPDIR")){
        strncpy(tmpdir, getenv("NVIMR_TMPDIR"), 500);
        if(getenv("NVIMR_SECRET"))
            strncpy(nvimsecr, getenv("NVIMR_SECRET"), 31);
        else
            REprintf("nvimcom: Environment variable NVIMR_SECRET is missing.\n");
    } else {
        if(verbose)
            REprintf("nvimcom: It seems that R was not started by Neovim. The communication with Nvim-R will not work.\n");
        tmpdir[0] = 0;
        return;
    }

    if(getenv("NVIMR_PORT"))
        strncpy(nrs_port, getenv("NVIMR_PORT"), 15);

    if(verbose > 0)
        REprintf("nvimcom %s loaded\n", nvimcom_version);
    if(verbose > 1){
        if(getenv("NVIM_IP_ADDRESS")) {
            REprintf("  NVIM_IP_ADDRESS: %s\n", getenv("NVIM_IP_ADDRESS"));
        }
        REprintf("  NVIMR_PORT: %s\n", nrs_port);
        REprintf("  NVIMR_ID: %s\n", getenv("NVIMR_ID"));
        REprintf("  NVIMR_TMPDIR: %s\n", tmpdir);
        REprintf("  NVIMR_COMPLDIR: %s\n", getenv("NVIMR_COMPLDIR"));
        REprintf("  R info: %s\n\n", *rinfo);
    }

    tcp_header_len = strlen(nvimsecr) + 9;
    glbnvbuf1 = (char*)calloc(glbnvbufsize, sizeof(char));
    glbnvbuf2 = (char*)calloc(glbnvbufsize, sizeof(char));
    send_ge_buf = (char*)calloc(glbnvbufsize + 64, sizeof(char));
    if(!glbnvbuf1 || !glbnvbuf2 || !send_ge_buf)
        REprintf("nvimcom: Error allocating memory.\n");

#ifndef WIN32
    *flag_eval = 0;
    int fds[2];
    if(pipe(fds) == 0){
        ifd = fds[0];
        ofd = fds[1];
        ih = addInputHandler(R_InputHandlers, ifd, &nvimcom_uih, 32);
    } else {
        REprintf("nvimcom error: pipe != 0\n");
        ih = NULL;
    }
#endif

    if (atoi(nrs_port) > 0) {
        struct sockaddr_in servaddr;
#ifdef WIN32
        WSADATA d;
        int wr = WSAStartup(MAKEWORD(2, 2), &d);
        if (wr != 0) {
            fprintf(stderr, "WSAStartup failed: %d\n", wr);
            fflush(stderr);
        }
#endif
        // socket create and verification
        sfd = socket(AF_INET, SOCK_STREAM, 0);
        if (sfd != -1) {
            bzero(&servaddr, sizeof(servaddr));

            // assign IP, PORT
            servaddr.sin_family = AF_INET;
            if (getenv("NVIM_IP_ADDRESS"))
                servaddr.sin_addr.s_addr = inet_addr(getenv("NVIM_IP_ADDRESS"));
            else
                servaddr.sin_addr.s_addr = inet_addr("127.0.0.1");
            servaddr.sin_port = htons(atoi(nrs_port));

            // connect the client socket to server socket
            if (connect(sfd, (struct sockaddr*)&servaddr, sizeof(servaddr)) == 0) {
#ifdef WIN32
                DWORD ti;
                tid = CreateThread(NULL, 0, server_thread, NULL, 0, &ti);
#else
                pthread_create(&tid, NULL, server_thread, NULL);
#endif
                nvimcom_send_running_info(*rinfo);
            } else {
                REprintf(NULL, "nvimcom: connection with the server failed (%s)\n",
                        nrs_port);
                nvimcom_failure = 1;
            }
        } else {
            REprintf("nvimcom: socket creation failed (%u:%d)\n",
                    servaddr.sin_addr.s_addr, atoi(nrs_port));
            nvimcom_failure = 1;
        }
    }

    if(nvimcom_failure == 0){
        Rf_addTaskCallback(nvimcom_task, NULL, free, "NVimComHandler", NULL);

        nvimcom_initialized = 1;

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

void nvimcom_Stop(void)
{
#ifndef WIN32
    if(ih){
        removeInputHandler(&R_InputHandlers, ih);
        close(ifd);
        close(ofd);
    }
#endif

    if(nvimcom_initialized){
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

        PkgInfo *pkg = pkgList;
        PkgInfo *tmp;
        while(pkg){
            tmp = pkg->next;
            free(pkg->name);
            free(pkg);
            pkg = tmp;
        }

        if(glbnvbuf1)
            free(glbnvbuf1);
        if(glbnvbuf2)
            free(glbnvbuf2);
        if (send_ge_buf)
            free(send_ge_buf);
        if(verbose)
            REprintf("nvimcom stopped\n");
    }
    nvimcom_initialized = 0;
}
