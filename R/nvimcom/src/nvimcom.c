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
#include <sys/time.h>
#endif

static char nvimcom_version[32];

static pid_t R_PID;

static int nvimcom_initialized = 0;
static int verbose = 0;
static int opendf = 1;
static int openls = 0;
static int allnames = 0;
static int labelerr = 1;
static int nvimcom_is_utf8;
static int nvimcom_failure = 0;
static int nlibs = 0;
static int needsfillmsg = 0;
static int openclosel = 0;
static char edsrvr[128];
static char nvimsecr[128];
static char liblist[512];
static char globenv[512];
static char *obbrbuf1;
static char *obbrbuf2;
static int obbrbufzise = 4096;
static char strL[16];
static char strT[16];
static char tmpdir[512];
static char nvimcom_home[1024];
static char search_list[1024];
static char R_version[16];
static int objbr_auto = 0; // 0 = Nothing; 1 = .GlobalEnv; 2 = Libraries

#ifdef WIN32
static int r_is_busy = 1;
static int tcltkerr = 0;
#else
static int fired = 0;
static char flag_eval[512];
static int flag_lsenv = 0;
static int flag_lslibs = 0;
static int ifd, ofd;
static InputHandler *ih;
#endif

typedef struct liststatus_ {
    char *key;
    int status;
    struct liststatus_ *next;
} ListStatus;

static int nvimcom_checklibs();

static ListStatus *firstList = NULL;

static char *loadedlibs[64];
static char *builtlibs[64];

#ifdef WIN32
SOCKET sfd;
static int tid;
extern void Rconsolecmd(char *cmd); // Defined in R: src/gnuwin32/rui.c
#else
static int sfd = -1;
static pthread_t tid;
#endif

char *nvimcom_strcat(char* dest, const char* src)
{
    while(*dest) dest++;
    while((*dest++ = *src++));
    return --dest;
}

char *nvimcom_grow_obbrbuf()
{
    obbrbufzise += 4096;
    char *tmp = (char*)calloc(obbrbufzise, sizeof(char));
    strcpy(tmp, obbrbuf1);
    free(obbrbuf1);
    obbrbuf1 = tmp;
    tmp = (char*)calloc(obbrbufzise, sizeof(char));
    strcpy(tmp, obbrbuf2);
    free(obbrbuf2);
    obbrbuf2 = tmp;
    return(obbrbuf2 + strlen(obbrbuf2));
}

static void nvimcom_del_newline(char *buf)
{
    for(int i = 0; i < strlen(buf); i++)
        if(buf[i] == '\n'){
            buf[i] = 0;
            break;
        }
}

#ifndef WIN32
static void nvimcom_nvimclient(const char *msg, char *port)
{
    struct addrinfo hints;
    struct addrinfo *result, *rp;
    char portstr[16];
    int s, a;
    size_t len;
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
        objbr_auto = 0;
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
        objbr_auto = 0;
        return;
    }

    freeaddrinfo(result);	   /* No longer needed */

    /* Prefix NVIMR_SECRET to msg to increase security.
     * The nvimclient does not need this because it is protect by the X server. */
    char finalmsg[256];
    strncpy(finalmsg, nvimsecr, 255);
    strncat(finalmsg, "call ", 255);
    strncat(finalmsg, msg, 255);
    len = strlen(finalmsg);
    if (write(s, finalmsg, len) != len) {
        REprintf("Error: partial/failed write\n");
        objbr_auto = 0;
        return;
    }
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

    /* Prefix NVIMR_SECRET to msg to increase security.
     * The nvimclient does not need this because it is protect by the X server. */
    char finalmsg[256];
    strncpy(finalmsg, nvimsecr, 255);
    strncat(finalmsg, "call ", 255);
    strncat(finalmsg, msg, 255);
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

void nvimcom_msg_to_nvim(char **cmd)
{
    nvimcom_nvimclient(*cmd, edsrvr);
}

static void nvimcom_toggle_list_status(const char *x)
{
    ListStatus *tmp = firstList;
    while(tmp){
        if(strcmp(tmp->key, x) == 0){
            tmp->status = !tmp->status;
            break;
        }
        tmp = tmp->next;
    }
}

static void nvimcom_add_list(const char *x, int s)
{
    ListStatus *tmp = firstList;
    while(tmp->next)
        tmp = tmp->next;
    tmp->next = (ListStatus*)calloc(1, sizeof(ListStatus));
    tmp->next->key = (char*)malloc((strlen(x) + 1) * sizeof(char));
    strcpy(tmp->next->key, x);
    tmp->next->status = s;
}

static int nvimcom_get_list_status(const char *x, const char *xclass)
{
    ListStatus *tmp = firstList;
    while(tmp){
        if(strcmp(tmp->key, x) == 0)
            return(tmp->status);
        tmp = tmp->next;
    }
    if(strcmp(xclass, "data.frame") == 0){
        nvimcom_add_list(x, opendf);
        return(opendf);
    } else if(strcmp(xclass, "list") == 0){
        nvimcom_add_list(x, openls);
        return(openls);
    } else {
        nvimcom_add_list(x, 0);
        return(0);
    }
}

char *nvimcom_browser_line(SEXP *x, const char *xname, const char *curenv, const char *prefix, char *p)
{
    char xclass[64];
    char newenv[512];
    char curenvB[512];
    char ebuf[64];
    char pre[128];
    char newpre[128];
    int len;
    const char *ename;
    SEXP listNames, label, lablab, eexp, elmt = R_NilValue;
    SEXP cmdSexp, cmdexpr, ans, cmdSexp2, cmdexpr2;
    ParseStatus status, status2;
    int er = 0;
    char buf[128];

    if(strlen(xname) > 64)
        return p;

    if(obbrbufzise < strlen(obbrbuf2) + 1024)
        p = nvimcom_grow_obbrbuf();

    p = nvimcom_strcat(p, prefix);
    if(Rf_isLogical(*x)){
        p = nvimcom_strcat(p, "%#");
        strcpy(xclass, "logical");
    } else if(Rf_isNumeric(*x)){
        p = nvimcom_strcat(p, "{#");
        strcpy(xclass, "numeric");
    } else if(Rf_isFactor(*x)){
        p = nvimcom_strcat(p, "'#");
        strcpy(xclass, "factor");
    } else if(Rf_isValidString(*x)){
        p = nvimcom_strcat(p, "\"#");
        strcpy(xclass, "character");
    } else if(Rf_isFunction(*x)){
        p = nvimcom_strcat(p, "(#");
        strcpy(xclass, "function");
    } else if(Rf_isFrame(*x)){
        p = nvimcom_strcat(p, "[#");
        strcpy(xclass, "data.frame");
    } else if(Rf_isNewList(*x)){
        p = nvimcom_strcat(p, "[#");
        strcpy(xclass, "list");
    } else if(Rf_isS4(*x)){
        p = nvimcom_strcat(p, "<#");
        strcpy(xclass, "s4");
    } else if(TYPEOF(*x) == PROMSXP){
        p = nvimcom_strcat(p, "&#");
        strcpy(xclass, "lazy");
    } else {
        p = nvimcom_strcat(p, "=#");
        strcpy(xclass, "other");
    }

    PROTECT(lablab = allocVector(STRSXP, 1));
    SET_STRING_ELT(lablab, 0, mkChar("label"));
    PROTECT(label = getAttrib(*x, lablab));
    p = nvimcom_strcat(p, xname);
    p = nvimcom_strcat(p, "\t");
    if(length(label) > 0){
        if(Rf_isValidString(label)){
            snprintf(buf, 127, "%s", CHAR(STRING_ELT(label, 0)));
            p = nvimcom_strcat(p, buf);
        } else {
            if(labelerr)
                p = nvimcom_strcat(p, "Error: label isn't \"character\".");
        }
    }
    p = nvimcom_strcat(p, "\n");
    UNPROTECT(2);

    if(strcmp(xclass, "list") == 0 || strcmp(xclass, "data.frame") == 0 || strcmp(xclass, "s4") == 0){
        strncpy(curenvB, curenv, 500);
        if(xname[0] == '[' && xname[1] == '['){
            curenvB[strlen(curenvB) - 1] = 0;
        }
        if(strcmp(xclass, "s4") == 0)
            snprintf(newenv, 500, "%s%s@", curenvB, xname);
        else
            snprintf(newenv, 500, "%s%s$", curenvB, xname);
        if((nvimcom_get_list_status(newenv, xclass) == 1)){
            len = strlen(prefix);
            if(nvimcom_is_utf8){
                int j = 0, i = 0;
                while(i < len){
                    if(prefix[i] == '\xe2'){
                        i += 3;
                        if(prefix[i-1] == '\x80' || prefix[i-1] == '\x94'){
                            pre[j] = ' '; j++;
                        } else {
                            pre[j] = '\xe2'; j++;
                            pre[j] = '\x94'; j++;
                            pre[j] = '\x82'; j++;
                        }
                    } else {
                        pre[j] = prefix[i];
                        i++, j++;
                    }
                }
                pre[j] = 0;
            } else {
                for(int i = 0; i < len; i++){
                    if(prefix[i] == '-' || prefix[i] == '`')
                        pre[i] = ' ';
                    else
                        pre[i] = prefix[i];
                }
                pre[len] = 0;
            }
            sprintf(newpre, "%s%s", pre, strT);

            if(strcmp(xclass, "s4") == 0){
                snprintf(buf, 127, "slotNames(%s%s)", curenvB, xname);
                PROTECT(cmdSexp = allocVector(STRSXP, 1));
                SET_STRING_ELT(cmdSexp, 0, mkChar(buf));
                PROTECT(cmdexpr = R_ParseVector(cmdSexp, -1, &status, R_NilValue));

                if (status != PARSE_OK) {
                    p = nvimcom_strcat(p, "nvimcom error: invalid value in slotNames(");
                    p = nvimcom_strcat(p, xname);
                    p = nvimcom_strcat(p, ")\n");
                } else {
                    PROTECT(ans = R_tryEval(VECTOR_ELT(cmdexpr, 0), R_GlobalEnv, &er));
                    if(er){
                        p = nvimcom_strcat(p, "nvimcom error: ");
                        p = nvimcom_strcat(p, xname);
                        p = nvimcom_strcat(p, "\n");
                    } else {
                        len = length(ans);
                        if(len > 0){
                            int len1 = len - 1;
                            for(int i = 0; i < len; i++){
                                ename = CHAR(STRING_ELT(ans, i));
                                snprintf(buf, 127, "%s%s@%s", curenvB, xname, ename);
                                PROTECT(cmdSexp2 = allocVector(STRSXP, 1));
                                SET_STRING_ELT(cmdSexp2, 0, mkChar(buf));
                                PROTECT(cmdexpr2 = R_ParseVector(cmdSexp2, -1, &status2, R_NilValue));
                                if (status2 != PARSE_OK) {
                                    p = nvimcom_strcat(p, "nvimcom error: invalid code \"");
                                    p = nvimcom_strcat(p, xname);
                                    p = nvimcom_strcat(p, "@");
                                    p = nvimcom_strcat(p, ename);
                                    p = nvimcom_strcat(p, "\"\n");
                                } else {
                                    PROTECT(elmt = R_tryEval(VECTOR_ELT(cmdexpr2, 0), R_GlobalEnv, &er));
                                    if(i == len1)
                                        sprintf(newpre, "%s%s", pre, strL);
                                    p = nvimcom_browser_line(&elmt, ename, newenv, newpre, p);
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
                        for(int i = 0; i < len1; i++){
                            sprintf(ebuf, "[[%d]]", i + 1);
                            elmt = VECTOR_ELT(*x, i);
                            p = nvimcom_browser_line(&elmt, ebuf, newenv, newpre, p);
                        }
                        sprintf(newpre, "%s%s", pre, strL);
                        sprintf(ebuf, "[[%d]]", len1 + 1);
                        PROTECT(elmt = VECTOR_ELT(*x, len));
                        p = nvimcom_browser_line(&elmt, ebuf, newenv, newpre, p);
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
                        p = nvimcom_browser_line(&elmt, ename, newenv, newpre, p);
                        UNPROTECT(1);
                    }
                    sprintf(newpre, "%s%s", pre, strL);
                    ename = CHAR(STRING_ELT(listNames, len));
                    if(ename[0] == 0){
                        sprintf(ebuf, "[[%d]]", len + 1);
                        ename = ebuf;
                    }
                    PROTECT(elmt = VECTOR_ELT(*x, len));
                    p = nvimcom_browser_line(&elmt, ename, newenv, newpre, p);
                    UNPROTECT(1);
                }
                UNPROTECT(1); /* listNames */
            }
        }
    }
    return p;
}

static void nvimcom_write_obbr()
{
    strcpy(obbrbuf1, obbrbuf2);
    FILE *f = fopen(globenv, "w");
    if(f == NULL){
        REprintf("Error: Could not write to '%s'. [nvimcom]\n", globenv);
        return;
    }
    fprintf(f, "%s", obbrbuf1);
    fclose(f);
    nvimcom_nvimclient("UpdateOB('GlobalEnv')", edsrvr);
}

static void nvimcom_list_env()
{
    const char *varName;
    SEXP envVarsSEXP, varSEXP;

    if(tmpdir[0] == 0)
        return;

    if(objbr_auto != 1)
        return;

#ifndef WIN32
    struct timeval begin, middle, end, tdiff1, tdiff2;
    if(verbose > 1)
        gettimeofday(&begin, NULL);
#endif

    memset(obbrbuf2, 0, obbrbufzise);
    char *p = nvimcom_strcat(obbrbuf2, ".GlobalEnv | Libraries\n\n");

    PROTECT(envVarsSEXP = R_lsInternal(R_GlobalEnv, allnames));
    for(int i = 0; i < Rf_length(envVarsSEXP); i++){
        varName = CHAR(STRING_ELT(envVarsSEXP, i));
        PROTECT(varSEXP = Rf_findVar(Rf_install(varName), R_GlobalEnv));
        if (varSEXP != R_UnboundValue) // should never be unbound
        {
            p = nvimcom_browser_line(&varSEXP, varName, "", "   ", p);
        } else {
            REprintf("Unexpected R_UnboundValue returned from R_lsInternal.\n");
        }
        UNPROTECT(1);
    }
    UNPROTECT(1);

#ifndef WIN32
    if(verbose > 1)
        gettimeofday(&middle, NULL);
#endif

    int len1 = strlen(obbrbuf1);
    int len2 = strlen(obbrbuf2);
    if(len1 != len2){
        nvimcom_write_obbr();
    } else {
        for(int i = 0; i < len1; i++){
            if(obbrbuf1[i] != obbrbuf2[i]){
                nvimcom_write_obbr();
                break;
            }
        }
    }
#ifndef WIN32
    if(verbose > 1){
        gettimeofday(&end, NULL);
        timersub(&middle, &begin, &tdiff1);
        timersub(&end, &middle, &tdiff2);
        Rprintf("Time to Update the Object Browser: %ld.%06ld + %ld.%06ld\n",
                (long int)tdiff1.tv_sec, (long int)tdiff1.tv_usec,
                (long int)tdiff2.tv_sec, (long int)tdiff2.tv_usec);
    }
#endif
}

static void nvimcom_char_eval_char(const char *buf, char *rep, int size)
{
    SEXP cmdSexp, cmdexpr, ans;
    ParseStatus status;
    int er = 0;

    strcpy(rep, "Error");

    PROTECT(cmdSexp = allocVector(STRSXP, 1));
    SET_STRING_ELT(cmdSexp, 0, mkChar(buf));
    PROTECT(cmdexpr = R_ParseVector(cmdSexp, -1, &status, R_NilValue));

    if (status != PARSE_OK) {
        strcpy(rep, "INVALID");
    } else {
        /* Only the first command will be executed if the expression includes
         * a semicolon. */
        PROTECT(ans = R_tryEval(VECTOR_ELT(cmdexpr, 0), R_GlobalEnv, &er));
        if(er){
            strcpy(rep, "ERROR");
        } else {
            snprintf(rep, size, "%s", CHAR(STRING_ELT(ans, 0)));
        }
        UNPROTECT(1);
    }
    UNPROTECT(2);
}

static void nvimcom_eval_expr(const char *buf)
{
    char fn[512];
    snprintf(fn, 510, "%s/eval_reply", tmpdir);

    if(verbose > 3)
        Rprintf("nvimcom_eval_expr: '%s'\n", buf);

    FILE *rep = fopen(fn, "w");
    if(rep == NULL){
        REprintf("Error: Could not write to '%s'. [nvimcom]\n", fn);
        return;
    }

#ifdef WIN32
    if(tcltkerr){
        fprintf(rep, "Error: \"nvimcom\" and \"tcltk\" packages are incompatible!\n");
        fclose(rep);
        return;
    } else {
        if(objbr_auto == 0)
            nvimcom_checklibs();
        if(tcltkerr){
            fprintf(rep, "Error: \"nvimcom\" and \"tcltk\" packages are incompatible!\n");
            fclose(rep);
            return;
        }
    }
#endif

    SEXP cmdSexp, cmdexpr, ans;
    ParseStatus status;
    int er = 0;

    PROTECT(cmdSexp = allocVector(STRSXP, 1));
    SET_STRING_ELT(cmdSexp, 0, mkChar(buf));
    PROTECT(cmdexpr = R_ParseVector(cmdSexp, -1, &status, R_NilValue));

    if (status != PARSE_OK) {
        fprintf(rep, "INVALID\n");
    } else {
        /* Only the first command will be executed if the expression includes
         * a semicolon. */
        PROTECT(ans = R_tryEval(VECTOR_ELT(cmdexpr, 0), R_GlobalEnv, &er));
        if(er){
            fprintf(rep, "ERROR\n");
        } else {
            switch(TYPEOF(ans)) {
                case REALSXP:
                    fprintf(rep, "%f\n", REAL(ans)[0]);
                    break;
                case LGLSXP:
                case INTSXP:
                    fprintf(rep, "%d\n", INTEGER(ans)[0]);
                    break;
                case STRSXP:
                    if(length(ans) > 0)
                        fprintf(rep, "%s\n", CHAR(STRING_ELT(ans, 0)));
                    else
                        fprintf(rep, "EMPTY\n");
                    break;
                default:
                    fprintf(rep, "RTYPE\n");
            }
        }
        UNPROTECT(1);
    }
    UNPROTECT(2);
    fclose(rep);
}

static int nvimcom_checklibs()
{
    const char *libname;
    char buf[256];
    char *libn;
    SEXP a, l;

    PROTECT(a = eval(lang1(install("search")), R_GlobalEnv));

    int newnlibs = Rf_length(a);
    if(nlibs == newnlibs)
        return(nlibs);

    int k = 0;
    for(int i = 0; i < newnlibs; i++){
        if(i == 62)
            break;
        PROTECT(l = STRING_ELT(a, i));
        libname = CHAR(l);
        libn = strstr(libname, "package:");
        if(libn != NULL){
            strncpy(loadedlibs[k], libname, 63);
            loadedlibs[k+1][0] = 0;
#ifdef WIN32
            if(tcltkerr == 0){
                if(strstr(libn, "tcltk") != NULL){
                    REprintf("Error: \"nvimcom\" and \"tcltk\" packages are incompatible!\n");
                    tcltkerr = 1;
                }
            }
#endif
            k++;
        }
        UNPROTECT(1);
    }
    UNPROTECT(1);
    for(int i = 0; i < 64; i++){
        if(loadedlibs[i][0] == 0)
            break;
        for(int j = 0; j < 64; j++){
            libn = strstr(loadedlibs[i], ":");
            libn++;
            if(strcmp(builtlibs[j], libn) == 0)
                break;
            if(builtlibs[j][0] == 0){
                strcpy(builtlibs[j], libn);
                sprintf(buf, "nvimcom:::nvim.buildomnils('%s')", libn);
                nvimcom_eval_expr(buf);
                needsfillmsg = 1;
                break;
            }
        }
    }

    char fn[512];
    snprintf(fn, 510, "%s/libnames_%s", tmpdir, getenv("NVIMR_ID"));
    FILE *f = fopen(fn, "w");
    if(f == NULL){
        REprintf("Error: Could not write to '%s'. [nvimcom]\n", fn);
        return(newnlibs);
    }
    for(int i = 0; i < 64; i++){
        if(builtlibs[i][0] == 0)
            break;
        fprintf(f, "%s\n", builtlibs[i]);
    }
    fclose(f);

    return(newnlibs);
}

static void nvimcom_list_libs()
{
    int newnlibs;

    if(tmpdir[0] == 0)
        return;

    newnlibs = nvimcom_checklibs();

    if(newnlibs == nlibs && openclosel == 0)
        return;

    nlibs = newnlibs;
    openclosel = 0;

    if(objbr_auto != 2)
        return;

    int len, len1;
    char *libn;
    char prefixT[64];
    char prefixL[64];
    char libasenv[64];
    SEXP x, oblist, obj;

    memset(obbrbuf2, 0, obbrbufzise);
    char *p = nvimcom_strcat(obbrbuf2, "Libraries | .GlobalEnv\n\n");

    strcpy(prefixT, "   ");
    strcpy(prefixL, "   ");
    strcat(prefixT, strT);
    strcat(prefixL, strL);

    int save_opendf = opendf;
    int save_openls = openls;
    opendf = 0;
    openls = 0;
    int i = 0;
    char pkgtitle[128];
    char rcmd[128];
    while(loadedlibs[i][0] != 0){
        libn = loadedlibs[i] + 8;
        p = nvimcom_strcat(p, "   ##");
        p = nvimcom_strcat(p, libn);
        p = nvimcom_strcat(p, "\t");
        snprintf(rcmd, 127, "packageDescription('%s', fields='Title')", libn);
        nvimcom_char_eval_char(rcmd, pkgtitle, 127);
        for(int j = 0; j < 128; j++)
            if(pkgtitle[j] == '\n')
                pkgtitle[j] = ' ';
        p = nvimcom_strcat(p, pkgtitle);
        p = nvimcom_strcat(p, "\n");
        if(nvimcom_get_list_status(loadedlibs[i], "library") == 1){
#ifdef WIN32
            if(tcltkerr){
                REprintf("Error: Cannot open libraries due to conflict between \"nvimcom\" and \"tcltk\" packages.\n");
                i++;
                continue;
            }
#endif
            PROTECT(x = allocVector(STRSXP, 1));
            SET_STRING_ELT(x, 0, mkChar(loadedlibs[i]));
            PROTECT(oblist = eval(lang2(install("objects"), x), R_GlobalEnv));
            len = Rf_length(oblist);
            len1 = len - 1;
            for(int j = 0; j < len; j++){
                PROTECT(obj = eval(lang3(install("get"), ScalarString(STRING_ELT(oblist, j)), x), R_GlobalEnv));
                snprintf(libasenv, 63, "%s-", loadedlibs[i]);
                if(j == len1)
                    p = nvimcom_browser_line(&obj, CHAR(STRING_ELT(oblist, j)), libasenv, prefixL, p);
                else
                    p = nvimcom_browser_line(&obj, CHAR(STRING_ELT(oblist, j)), libasenv, prefixT, p);
                UNPROTECT(1);
            }
            UNPROTECT(2);
        }
        i++;
    }

    FILE *f = fopen(liblist, "w");
    if(f == NULL){
        REprintf("Error: Could not write to '%s'. [nvimcom]\n", liblist);
        return;
    }
    fprintf(f, "%s", obbrbuf2);
    fclose(f);
    opendf = save_opendf;
    openls = save_openls;
    nvimcom_nvimclient("UpdateOB('libraries')", edsrvr);
}

Rboolean nvimcom_task(SEXP expr, SEXP value, Rboolean succeeded,
        Rboolean visible, void *userData)
{
    nvimcom_list_libs();
    nvimcom_list_env();
#ifdef WIN32
    r_is_busy = 0;
#endif
    if(edsrvr[0] != 0 && needsfillmsg){
        needsfillmsg = 0;
        nvimcom_nvimclient("FillRLibList()", edsrvr);
    }
    return(TRUE);
}

#ifndef WIN32
static void nvimcom_exec(){
    if(*flag_eval){
        nvimcom_eval_expr(flag_eval);
        *flag_eval = 0;
    }
    if(flag_lsenv)
        nvimcom_list_env();
    if(flag_lslibs)
        nvimcom_list_libs();
    flag_lsenv = 0;
    flag_lslibs = 0;
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
#endif

static void nvimcom_save_running_info(int bindportn)
{
    char fn[512];
    snprintf(fn, 510, "%s/nvimcom_running_%s", tmpdir, getenv("NVIMR_ID"));
    FILE *f = fopen(fn, "w");
    if(f == NULL){
        REprintf("Error: Could not write to '%s'. [nvimcom]\n", fn);
    } else {
#ifdef WIN32
#ifdef _WIN64
        fprintf(f, "%s\n%s\n%d\n%" PRId64 "\n%" PRId64 "\n%s\n%s\n",
                nvimcom_version, nvimcom_home, bindportn, R_PID,
                (long long)GetForegroundWindow(), search_list, R_version);
#else
        fprintf(f, "%s\n%s\n%d\n%d\n%ld\n%s\n%s\n",
                nvimcom_version, nvimcom_home, bindportn, R_PID,
                (long)GetForegroundWindow(), search_list, R_version);
#endif
#else
        if(getenv("WINDOWID"))
            fprintf(f, "%s\n%s\n%d\n%d\n%s\n%s\n%s\n",
                    nvimcom_version, nvimcom_home, bindportn, R_PID,
                    getenv("WINDOWID"), search_list, R_version);
        else
            fprintf(f, "%s\n%s\n%d\n%d\n0\n%s\n%s\n",
                    nvimcom_version, nvimcom_home, bindportn, R_PID, search_list, R_version);
#endif
        if(getenv("R_IP_ADDRESS"))
            fprintf(f, "%s\n", getenv("R_IP_ADDRESS"));
        fclose(f);
    }
}

static void nvimcom_parse_received_msg(char *buf)
{
    int status;
    char *bbuf;

    if(verbose > 2){
        bbuf = buf;
        if(buf[0] < 30)
            bbuf++;
        REprintf("nvimcom Received: [%d] %s\n", buf[0], bbuf);
    }

    switch(buf[0]){
        case 1: // Set Editor server port number
            bbuf = buf;
            bbuf++;
            strcpy(edsrvr, bbuf);
            nvimcom_del_newline(edsrvr);
            break;
        case 2: // Start updating the Object Browser
            objbr_auto = 1;
#ifdef WIN32
            if(!r_is_busy)
                nvimcom_list_env();
#else
            flag_lsenv = 1;
            flag_lslibs = 1;
            nvimcom_fire();
#endif
            break;
        case 4: // Change value of objbr_auto
            if(buf[1] == 'G'){
                objbr_auto = 1;
                memset(obbrbuf1, 0, obbrbufzise);
            } else if(buf[1] == 'L'){
                nlibs = 0;
                objbr_auto = 2;
            } else {
                objbr_auto = 0;
            }
#ifdef WIN32
            if(!r_is_busy){
                if(objbr_auto == 1)
                    nvimcom_list_env();
                else
                    if(objbr_auto == 2)
                        nvimcom_list_libs();
            }
#else
            if(objbr_auto == 1)
                flag_lsenv = 1;
            else
                if(objbr_auto == 2)
                    flag_lslibs = 1;
            if(objbr_auto != 0)
                nvimcom_fire();
#endif
            break;
#ifdef WIN32
        case 5:
            bbuf = buf;
            bbuf++;
            if(strstr(bbuf, getenv("NVIMR_ID")) == bbuf){
                bbuf += strlen(getenv("NVIMR_ID"));
                r_is_busy = 1;
                Rconsolecmd(bbuf);
            }
            break;
#endif
        case 6: // Toggle list status
#ifdef WIN32
            if(r_is_busy)
                break;
#endif
            bbuf = buf;
            bbuf++;
            if(*bbuf == '&'){
                bbuf++;
#ifdef WIN32
                char flag_eval[512];
                snprintf(flag_eval, 510, "%s <- %s", bbuf, bbuf);
                nvimcom_eval_expr(flag_eval);
                *flag_eval = 0;
                nvimcom_list_env();
#else
                snprintf(flag_eval, 510, "%s <- %s", bbuf, bbuf);
                flag_lsenv = 1;
                nvimcom_fire();
#endif
                break;
            }
            nvimcom_toggle_list_status(bbuf);
            if(strstr(bbuf, "package:") == bbuf){
                openclosel = 1;
#ifdef WIN32
                nvimcom_list_libs();
#else
                flag_lslibs = 1;
#endif
            } else {
#ifdef WIN32
                nvimcom_list_env();
#else
                flag_lsenv = 1;
#endif
            }
#ifndef WIN32
            nvimcom_fire();
#endif
            break;
        case 7: // Close/open all lists
#ifdef WIN32
            if(r_is_busy)
                break;
#endif
            bbuf = buf;
            bbuf++;
            status = atoi(bbuf);
            ListStatus *tmp = firstList;
            if(status){
                while(tmp){
                    if(strstr(tmp->key, "package:") != tmp->key)
                        tmp->status = 1;
                    tmp = tmp->next;
                }
#ifdef WIN32
                nvimcom_list_env();
#else
                flag_lsenv = 1;
#endif
            } else {
                while(tmp){
                    tmp->status = 0;
                    tmp = tmp->next;
                }
                openclosel = 1;
#ifdef WIN32
                nvimcom_list_libs();
                nvimcom_list_env();
#else
                flag_lsenv = 1;
                flag_lslibs = 1;
#endif
            }
#ifndef WIN32
            nvimcom_fire();
#endif
            break;
        case 8: // eval expression
            bbuf = buf;
            bbuf++;
            if(strstr(bbuf, getenv("NVIMR_ID")) == bbuf){
                bbuf += strlen(getenv("NVIMR_ID"));
#ifdef WIN32
                if(!r_is_busy)
                    nvimcom_eval_expr(bbuf);
#else
                strncpy(flag_eval, bbuf, 510);
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

    if(verbose > 1)
        REprintf("nvimcom port: %d\n", bindportn);

    flag_lslibs = 1;
    nvimcom_fire();

    // Save a file to indicate that nvimcom is running
    nvimcom_save_running_info(bindportn);

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
    nvimcom_save_running_info(bindportn);

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

void nvimcom_Start(int *vrb, int *odf, int *ols, int *anm, int *lbe, char **pth, char **vcv, char **srchls, char **rvs)
{
    verbose = *vrb;
    opendf = *odf;
    openls = *ols;
    allnames = *anm;
    labelerr = *lbe;

    R_PID = getpid();
    strncpy(nvimcom_version, *vcv, 31);

    if(getenv("NVIMR_TMPDIR")){
        strncpy(nvimcom_home, *pth, 1023);
        strncpy(search_list, *srchls, 1023);
        strncpy(R_version, *rvs, 15);
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

    snprintf(liblist, 510, "%s/liblist_%s", tmpdir, getenv("NVIMR_ID"));
    snprintf(globenv, 510, "%s/globenv_%s", tmpdir, getenv("NVIMR_ID"));

    char envstr[1024];
    envstr[0] = 0;
    if(getenv("LC_MESSAGES"))
        strcat(envstr, getenv("LC_MESSAGES"));
    if(getenv("LC_ALL"))
        strcat(envstr, getenv("LC_ALL"));
    if(getenv("LANG"))
        strcat(envstr, getenv("LANG"));
    int len = strlen(envstr);
    for(int i = 0; i < len; i++)
        envstr[i] = toupper(envstr[i]);
    if(strstr(envstr, "UTF-8") != NULL || strstr(envstr, "UTF8") != NULL){
        nvimcom_is_utf8 = 1;
        strcpy(strL, "\xe2\x94\x94\xe2\x94\x80 ");
        strcpy(strT, "\xe2\x94\x9c\xe2\x94\x80 ");
    } else {
        nvimcom_is_utf8 = 0;
        strcpy(strL, "`- ");
        strcpy(strT, "|- ");
    }

#ifndef WIN32
    *flag_eval = 0;
    int fds[2];
    if(pipe(fds) == 0){
        ifd = fds[0];
        ofd = fds[1];
        ih = addInputHandler(R_InputHandlers, ifd, &nvimcom_uih, 32);
    } else {
        REprintf("setwidth error: pipe != 0\n");
        ih = NULL;
    }
#endif

#ifdef WIN32
    tid = _beginthread(nvimcom_server_thread, 0, NULL);
#else
    pthread_create(&tid, NULL, nvimcom_server_thread, NULL);
#endif

    if(nvimcom_failure == 0){
        // Linked list sentinel
        firstList = calloc(1, sizeof(ListStatus));
        firstList->key = (char*)malloc(13 * sizeof(char));
        strcpy(firstList->key, "package:base");

        for(int i = 0; i < 64; i++){
            loadedlibs[i] = (char*)malloc(64 * sizeof(char));
            loadedlibs[i][0] = 0;
        }
        for(int i = 0; i < 64; i++){
            builtlibs[i] = (char*)malloc(64 * sizeof(char));
            builtlibs[i][0] = 0;
        }

        obbrbuf1 = (char*)calloc(obbrbufzise, sizeof(char));
        obbrbuf2 = (char*)calloc(obbrbufzise, sizeof(char));
        if(!obbrbuf1 || !obbrbuf2)
            REprintf("nvimcom: Error allocating memory.\n");

        Rf_addTaskCallback(nvimcom_task, NULL, free, "NVimComHandler", NULL);

        nvimcom_initialized = 1;
        if(verbose > 0)
            // TODO: use packageStartupMessage()
            REprintf("nvimcom %s loaded\n", nvimcom_version);
        if(verbose > 1){
            REprintf("    NVIMR_TMPDIR = %s\n    NVIMR_ID = %s\n",
                    tmpdir, getenv("NVIMR_ID"));
            if(getenv("R_IP_ADDRESS"))
                REprintf("R_IP_ADDRESS: %s\n", getenv("R_IP_ADDRESS"));
        }
#ifdef WIN32
        r_is_busy = 0;
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
        close(sfd);
        pthread_cancel(tid);
        pthread_join(tid, NULL);
#endif
        ListStatus *tmp = firstList;
        while(tmp){
            firstList = tmp->next;
            free(tmp->key);
            free(tmp);
            tmp = firstList;
        }
        for(int i = 0; i < 64; i++){
            free(loadedlibs[i]);
            loadedlibs[i] = NULL;
        }
        if(obbrbuf1)
            free(obbrbuf1);
        if(obbrbuf2)
            free(obbrbuf2);
        if(verbose)
            REprintf("nvimcom stopped\n");
    }
    nvimcom_initialized = 0;
}
