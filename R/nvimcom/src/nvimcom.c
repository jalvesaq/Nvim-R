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
#else
#include <stdint.h>
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
static int debug_r;
static int debugging;
LibExtern SEXP  R_SrcfileSymbol; // Defn.h
static void SrcrefInfo();
#endif

static char nvimcom_version[32];

static pid_t R_PID;

static int nvimcom_initialized = 0;
static int verbose = 0;
static int allnames = 0;
static int nvimcom_failure = 0;
static int nlibs = 0;
static int needsfillmsg = 0;
static char edsrvr[128];
static char nvimsecr[128];

static char glbnvls[576];

static char *glbnvbuf1;
static char *glbnvbuf2;
static unsigned long lastglbnvbsz;
static unsigned long glbnvbufsize = 32768;
static int maxdepth = 6;
static int curdepth = 0;
static int autoglbenv = 0;
static clock_t tm;

static char tmpdir[512];
static char nvimcom_home[1024];
static char r_info[1024];
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
static char myport[128];
#endif

typedef struct pkg_info_ {
    char *name;
    char *version;
    struct pkg_info_ *next;
} PkgInfo;

PkgInfo *pkgList;


static int nvimcom_checklibs();
static void nvimcom_nvimclient(const char *msg, char *port);
static void nvimcom_eval_expr(const char *buf);

#ifdef WIN32
SOCKET sfd;
static int tid;
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

static char *nvimcom_grow_buffers()
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
    return(glbnvbuf2 + strlen(glbnvbuf2));
}

static void nvimcom_set_finalmsg(const char *msg, char *finalmsg)
{
    // Prefix NVIMR_SECRET to msg to increase security
    strncpy(finalmsg, nvimsecr, 1023);
    if (*msg != '+')
        strncat(finalmsg, "call ", 1023);
    if(strlen(msg) < 980){
        strncat(finalmsg, msg, 1023);
    } else {
        char fn[576];
        snprintf(fn, 575, "%s/nvimcom_msg", tmpdir);
        FILE *f = fopen(fn, "w");
        if(f == NULL){
            REprintf("Error: Could not write to '%s'. [nvimcom]\n", fn);
            return;
        }
        fprintf(f, "%s\n", msg);
        fclose(f);
        strncat(finalmsg, "ReadRMsg()", 1023);
    }
}

#ifndef WIN32
static void nvimcom_nvimclient(const char *msg, char *port)
{
    struct addrinfo hints;
    struct addrinfo *result, *rp;
    char portstr[16];
    int s, a;
    ssize_t len;
    int srvport = atoi(port);

    if(verbose > 2)
        Rprintf("nvimcom_nvimclient(%s): '%s' (%d)\n", msg, port, srvport);
    if(port[0] == 0){
        if(verbose > 3)
            REprintf("nvimcom_nvimclient() called although Neovim server port is undefined\n");
        return;
    }

    /* Obtain address(es) matching host/port */

    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_flags = 0;
    hints.ai_protocol = 0;

    sprintf(portstr, "%d", srvport);
    if(getenv("NVIM_IP_ADDRESS"))
        a = getaddrinfo(getenv("NVIM_IP_ADDRESS"), portstr, &hints, &result);
    else
        a = getaddrinfo("127.0.0.1", portstr, &hints, &result);
    if (a != 0) {
        REprintf("Error: getaddrinfo: %s\n", gai_strerror(a));
        return;
    }

    for (rp = result; rp != NULL; rp = rp->ai_next) {
        s = socket(rp->ai_family, rp->ai_socktype,
                rp->ai_protocol);
        if (s == -1)
            continue;

        if (connect(s, rp->ai_addr, rp->ai_addrlen) != -1)
            break;		   /* Success */

        close(s);
    }

    if (rp == NULL) {		   /* No address succeeded */
        REprintf("Error: Could not connect\n");
        return;
    }

    freeaddrinfo(result);	   /* No longer needed */

    char finalmsg[1024];
    nvimcom_set_finalmsg(msg, finalmsg);
    len = (ssize_t)strlen(finalmsg);
    if (write(s, finalmsg, len) != len) {
        REprintf("Error: partial/failed write\n");
        return;
    }
    close(s);
}
#endif

#ifdef WIN32
static void nvimcom_nvimclient(const char *msg, char *port)
{
    WSADATA wsaData;
    struct sockaddr_in peer_addr;
    SOCKET sfd;

    if(verbose > 2)
        Rprintf("nvimcom_nvimclient(%s): '%s'\n", msg, port);
    if(port[0] == 0){
        if(verbose > 3)
            REprintf("nvimcom_nvimclient() called although Neovim server port is undefined\n");
        return;
    }

    WSAStartup(MAKEWORD(2, 2), &wsaData);
    sfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);

    if(sfd < 0){
        REprintf("nvimcom_nvimclient socket failed.\n");
        return;
    }

    peer_addr.sin_family = AF_INET;
    peer_addr.sin_port = htons(atoi(port));
    peer_addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if(connect(sfd, (struct sockaddr *)&peer_addr, sizeof(peer_addr)) < 0){
        REprintf("nvimcom_nvimclient could not connect.\n");
        return;
    }

    char finalmsg[1024];
    nvimcom_set_finalmsg(msg, finalmsg);
    int len = strlen(finalmsg);
    if (send(sfd, finalmsg, len+1, 0) < 0) {
        REprintf("nvimcom_nvimclient failed sending message.\n");
        return;
    }

    if(closesocket(sfd) < 0)
        REprintf("nvimcom_nvimclient error closing socket.\n");
    return;
}
#endif

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

void nvimcom_msg_to_nvim(char **cmd)
{
    nvimcom_nvimclient(*cmd, edsrvr);
}

static PkgInfo *nvimcom_pkg_info_new(const char *nm, const char *vrsn)
{
    PkgInfo *pi = calloc(1, sizeof(PkgInfo));
    pi->name = malloc((strlen(nm)+1) * sizeof(char));
    strcpy(pi->name, nm);
    pi->version = malloc((strlen(vrsn)+1) * sizeof(char));
    strcpy(pi->version, vrsn);
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

static void nvimcom_write_file(char *b, const char *fn)
{
    FILE *f = fopen(fn, "w");
    if(f == NULL){
        REprintf("Error: Could not write to '%s'. [nvimcom]\n", fn);
        return;
    }
    fprintf(f, "%s", b);
    fclose(f);
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

static void nvimcom_globalenv_list()
{
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
        PROTECT(varSEXP = Rf_findVar(Rf_install(varName), R_GlobalEnv));
        if (varSEXP != R_UnboundValue) // should never be unbound
        {
            p = nvimcom_glbnv_line(&varSEXP, varName, "", p, 0);
        } else {
            REprintf("nvimcom_globalenv_list: Unexpected R_UnboundValue returned from R_lsInternal.\n");
        }
        UNPROTECT(1);
    }
    UNPROTECT(1);

    int len1 = strlen(glbnvbuf1);
    int len2 = strlen(glbnvbuf2);
    int changed = len1 != len2;
    if(!changed){
        for(int i = 0; i < len1; i++){
            if(glbnvbuf1[i] != glbnvbuf2[i]){
                changed = 1;
                break;
            }
        }
    }

    if(changed){
        nvimcom_write_file(glbnvbuf2, glbnvls);
        strcpy(glbnvbuf1, glbnvbuf2);
        double tmdiff = 1000 * ((double)clock() - tm) / CLOCKS_PER_SEC;
        if(verbose && tmdiff > 1000.0)
            REprintf("Time to build GlobalEnv omnils [%lu bytes]: %f ms\n", strlen(glbnvbuf2), tmdiff);
        if(tmdiff > 300.0){
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
        nvimcom_nvimclient("GlblEnvUpdated(1)", edsrvr);
    } else {
        nvimcom_nvimclient("GlblEnvUpdated(0)", edsrvr);
    }
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
    if (status != PARSE_OK && verbose > 1) {
        strcpy(rep, "RWarningMsg('Invalid command: ");
        strncat(rep, buf2, 80);
        strcat(rep, "')");
        nvimcom_nvimclient(rep, edsrvr);
    } else {
        /* Only the first command will be executed if the expression includes
         * a semicolon. */
        PROTECT(ans = R_tryEval(VECTOR_ELT(cmdexpr, 0), R_GlobalEnv, &er));
        if(er && verbose > 1){
            strcpy(rep, "RWarningMsg('Error running: ");
            strncat(rep, buf2, 80);
            strcat(rep, "')");
            nvimcom_nvimclient(rep, edsrvr);
        }
        UNPROTECT(1);
    }
    UNPROTECT(2);
}

static int nvimcom_checklibs()
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

    needsfillmsg = 1;

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

    char fn[576];
    snprintf(fn, 575, "%s/libnames_%s", tmpdir, getenv("NVIMR_ID"));
    FILE *f = fopen(fn, "w");
    if(f == NULL){
        REprintf("Error: Could not write to '%s'. [nvimcom]\n", fn);
        return(newnlibs);
    }
    pkg = pkgList;
    do {
        fprintf(f, "%s_%s\n", pkg->name, pkg->version);
        pkg = pkg->next;
    } while (pkg);
    fclose(f);

    return(newnlibs);
}

static Rboolean nvimcom_task(SEXP expr, SEXP value, Rboolean succeeded,
        Rboolean visible, void *userData)
{
#ifdef WIN32
    r_is_busy = 0;
#endif
    nvimcom_checklibs();
    if(edsrvr[0] != 0 && needsfillmsg){
        needsfillmsg = 0;
        nvimcom_nvimclient("+BuildOmnils", edsrvr);
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
    if(autoglbenv){
        nvimcom_globalenv_list();
    } else {
        nvimcom_nvimclient("RTaskCompleted()", edsrvr);
    }
    return(TRUE);
}

#ifndef WIN32
static void nvimcom_exec(void *nothing){
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
static void nvimcom_uih(void *data) {
    char buf[16];
    if(read(ifd, buf, 1) < 1)
        REprintf("nvimcom error: read < 1\n");
    R_ToplevelExec(nvimcom_exec, NULL);
    fired = 0;
}

static void nvimcom_fire()
{
    if(fired)
        return;
    fired = 1;
    char buf[16];
    *buf = 0;
    if(write(ofd, buf, 1) <= 0)
        REprintf("nvimcom error: write <= 0\n");
}

// Adapted from SrcrefPrompt(), at src/main/eval.c
static void SrcrefInfo()
{
    if(debugging == 0){
        nvimcom_nvimclient("StopRDebugging()", edsrvr);
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
                snprintf(buf, 2 * slen + 31, "RDebugJump('%s', %d)", buf2, asInteger(R_Srcref));
                nvimcom_nvimclient(buf, edsrvr);
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

static void nvimcom_send_running_info(int bindportn)
{
    char msg[2176];
#ifdef WIN32
#ifdef _WIN64
    snprintf(msg, 2175, "SetNvimcomInfo('%s', '%s', '%d', '%" PRId64 "', '%" PRId64 "', '%s')",
            nvimcom_version, nvimcom_home, bindportn, R_PID,
            (long long)GetForegroundWindow(), r_info);
#else
    snprintf(msg, 2175, "SetNvimcomInfo('%s', '%s', '%d', '%d', '%ld', '%s')",
            nvimcom_version, nvimcom_home, bindportn, R_PID,
            (long)GetForegroundWindow(), r_info);
#endif
#else
    if(getenv("WINDOWID"))
        snprintf(msg, 2175, "SetNvimcomInfo('%s', '%s', '%d', '%d', '%s', '%s')",
                nvimcom_version, nvimcom_home, bindportn, R_PID,
                getenv("WINDOWID"), r_info);
    else
        snprintf(msg, 2175, "SetNvimcomInfo('%s', '%s', '%d', '%d', '0', '%s')",
                nvimcom_version, nvimcom_home, bindportn, R_PID, r_info);
#endif
    nvimcom_nvimclient(msg, edsrvr);
}

static void nvimcom_parse_received_msg(char *buf)
{
    char *p;

    if(verbose > 2){
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
        case 'G': // Write GlobalEnvList_
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

#ifndef WIN32
static void *nvimcom_server_thread(void *arg)
{
    unsigned short bindportn = 10000;
    ssize_t nread;
    int bsize = 5012;
    char buf[bsize];
    int result;

    struct addrinfo hints;
    struct addrinfo *rp;
    struct addrinfo *res;
    struct sockaddr_storage peer_addr;
    char bindport[16];
    socklen_t peer_addr_len = sizeof(struct sockaddr_storage);

#ifndef __APPLE__
    // block SIGINT
    {
        sigset_t set;
        sigemptyset(&set);
        sigaddset(&set, SIGINT);
        sigprocmask(SIG_BLOCK, &set, NULL);
    }
#endif

    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_family = AF_INET;    /* Allow IPv4 or IPv6 */
    hints.ai_socktype = SOCK_DGRAM; /* Datagram socket */
    hints.ai_flags = AI_PASSIVE;    /* For wildcard IP address */
    hints.ai_protocol = 0;          /* Any protocol */
    hints.ai_canonname = NULL;
    hints.ai_addr = NULL;
    hints.ai_next = NULL;
    rp = NULL;
    result = 1;
    while(rp == NULL && bindportn < 10049){
        bindportn++;
        sprintf(bindport, "%d", bindportn);
        if(getenv("NVIM_IP_ADDRESS"))
            result = getaddrinfo(NULL, bindport, &hints, &res);
        else
            result = getaddrinfo("127.0.0.1", bindport, &hints, &res);
        if(result != 0){
            REprintf("Error at getaddrinfo: %s [nvimcom]\n", gai_strerror(result));
            nvimcom_failure = 1;
            return(NULL);
        }

        for (rp = res; rp != NULL; rp = rp->ai_next) {
            sfd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
            if (sfd == -1)
                continue;
            if (bind(sfd, rp->ai_addr, rp->ai_addrlen) == 0)
                break;       /* Success */
            close(sfd);
        }
        freeaddrinfo(res);   /* No longer needed */
    }

    if (rp == NULL) {        /* No address succeeded */
        REprintf("Error: Could not bind. [nvimcom]\n");
        nvimcom_failure = 1;
        return(NULL);
    }

    snprintf(myport, 127, "%d", bindportn);

    if(verbose > 1)
        REprintf("nvimcom port: %d\n", bindportn);

    // Save a file to indicate that nvimcom is running
    nvimcom_send_running_info(bindportn);

    char endmsg[128];
    snprintf(endmsg, 127, "%scall STOP >>> Now <<< !!!", getenv("NVIMR_SECRET"));

    /* Read datagrams and reply to sender */
    for (;;) {
        memset(buf, 0, bsize);

        nread = recvfrom(sfd, buf, bsize, 0,
                (struct sockaddr *) &peer_addr, &peer_addr_len);
        if (nread == -1){
            if(verbose > 1)
                REprintf("nvimcom: recvfrom failed\n");
            continue;     /* Ignore failed request */
        }
        if(strncmp(endmsg, buf, 28) == 0)
            break;
        nvimcom_parse_received_msg(buf);
    }
    return(NULL);
}
#endif

#ifdef WIN32
static void nvimcom_server_thread(void *arg)
{
    unsigned short bindportn = 10000;
    ssize_t nread;
    int bsize = 5012;
    char buf[bsize];
    int result;

    WSADATA wsaData;
    SOCKADDR_IN RecvAddr;
    SOCKADDR_IN peer_addr;
    int peer_addr_len = sizeof (peer_addr);
    int nattp = 0;
    int nfail = 0;
    int lastfail = 0;

    result = WSAStartup(MAKEWORD(2, 2), &wsaData);
    if (result != NO_ERROR) {
        REprintf("WSAStartup failed with error %d\n", result);
        return;
    }

    while(bindportn < 10049){
        bindportn++;
        sfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if (sfd == INVALID_SOCKET) {
            REprintf("Error: socket failed with error %d [nvimcom]\n", WSAGetLastError());
            return;
        }

        RecvAddr.sin_family = AF_INET;
        RecvAddr.sin_port = htons(bindportn);
        RecvAddr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

        nattp++;
        if(bind(sfd, (SOCKADDR *) & RecvAddr, sizeof (RecvAddr)) == 0)
            break;
        lastfail = WSAGetLastError();
        nfail++;
        if(verbose > 1)
            REprintf("nvimcom: Could not bind to port %d [error  %d].\n", bindportn, lastfail);
    }
    if(nfail > 0 && verbose > 1){
        if(nattp > nfail)
            REprintf("nvimcom: finally, bind to port %d was successful.\n", bindportn);
    }
    if(nattp == nfail){
        if(nfail == 1)
            REprintf("nvimcom: bind failed once with error %d.\n", lastfail);
        else
            REprintf("nvimcom: bind failed %d times and the last error was \"%d\".\n", nfail, lastfail);
        nvimcom_failure = 1;
        return;
    }

    if(verbose > 1)
        REprintf("nvimcom port: %d\n", bindportn);

    // Save a file to indicate that nvimcom is running
    nvimcom_send_running_info(bindportn);

    /* Read datagrams and reply to sender */
    for (;;) {
        memset(buf, 0, bsize);

        nread = recvfrom(sfd, buf, bsize, 0, (SOCKADDR *) &peer_addr, &peer_addr_len);
        if (nread == SOCKET_ERROR) {
            REprintf("nvimcom: recvfrom failed with error %d\n", WSAGetLastError());
            return;
        }
        nvimcom_parse_received_msg(buf);
    }

    REprintf("nvimcom: Finished receiving. Closing socket.\n");
    result = closesocket(sfd);
    if (result == SOCKET_ERROR) {
        REprintf("closesocket failed with error %d\n", WSAGetLastError());
        return;
    }
    WSACleanup();
    return;
}
#endif


void nvimcom_Start(int *vrb, int *anm, int *swd, int *age, int *dbg, char **vcv, char **pth, char **rinfo)
{
    verbose = *vrb;
    allnames = *anm;
    setwidth = *swd;
    autoglbenv = *age;
    debug_r = *dbg;

    R_PID = getpid();
    strncpy(nvimcom_version, *vcv, 31);

    if(getenv("NVIMR_TMPDIR")){
        strncpy(nvimcom_home, *pth, 1023);
        strncpy(r_info, *rinfo, 1023);
        strncpy(tmpdir, getenv("NVIMR_TMPDIR"), 500);
        if(getenv("NVIMR_SECRET"))
            strncpy(nvimsecr, getenv("NVIMR_SECRET"), 127);
        else
            REprintf("nvimcom: Environment variable NVIMR_SECRET is missing.\n");
    } else {
        if(verbose)
            REprintf("nvimcom: It seems that R was not started by Neovim. The communication with Nvim-R will not work.\n");
        tmpdir[0] = 0;
        return;
    }

    if(getenv("NVIMR_PORT"))
        strncpy(edsrvr, getenv("NVIMR_PORT"), 127);
    if(verbose > 1)
        REprintf("nclientserver port: %s\n", edsrvr);

    snprintf(glbnvls, 575, "%s/GlobalEnvList_%s", tmpdir, getenv("NVIMR_ID"));

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

#ifdef WIN32
    tid = _beginthread(nvimcom_server_thread, 0, NULL);
#else
    strcpy(myport, "0");
    pthread_create(&tid, NULL, nvimcom_server_thread, NULL);
#endif

    if(nvimcom_failure == 0){
        glbnvbuf1 = (char*)calloc(glbnvbufsize, sizeof(char));
        glbnvbuf2 = (char*)calloc(glbnvbufsize, sizeof(char));
        if(!glbnvbuf1 || !glbnvbuf2)
            REprintf("nvimcom: Error allocating memory.\n");

        Rf_addTaskCallback(nvimcom_task, NULL, free, "NVimComHandler", NULL);

        nvimcom_initialized = 1;
        if(verbose > 0)
            REprintf("nvimcom %s loaded\n", nvimcom_version);
        if(verbose > 1){
            REprintf("    NVIMR_TMPDIR = %s\n    NVIMR_ID = %s\n",
                    tmpdir, getenv("NVIMR_ID"));
            if(getenv("R_IP_ADDRESS"))
                REprintf("R_IP_ADDRESS: %s\n", getenv("R_IP_ADDRESS"));
        }
#ifdef WIN32
        r_is_busy = 0;
#else
        if (debug_r) {
            save_ptr_R_ReadConsole = ptr_R_ReadConsole;
            ptr_R_ReadConsole = nvimcom_read_console;
        }
#endif

    }
}

void nvimcom_Stop()
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
#else
        if (debug_r)
            ptr_R_ReadConsole = save_ptr_R_ReadConsole;
        close(sfd);
        nvimcom_nvimclient("STOP >>> Now <<< !!!", myport);
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
        if(verbose)
            REprintf("nvimcom stopped\n");
    }
    nvimcom_initialized = 0;
}
