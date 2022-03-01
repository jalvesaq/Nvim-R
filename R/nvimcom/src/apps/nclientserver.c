#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <ctype.h>
#include <unistd.h>
#include <sys/types.h>
#include <signal.h>
#include <dirent.h>
#ifdef WIN32
#include <winsock2.h>
#include <process.h>
#include <windows.h>
#include <time.h>
#include <inttypes.h>
HWND NvimHwnd = NULL;
HWND RConsole = NULL;
#ifdef _WIN64
#define PRI_SIZET PRIu64
#else
#define PRI_SIZET PRIu32
#endif
#else
#include <stdint.h>
#include <sys/socket.h>
#include <netdb.h>
#include <pthread.h>
#include <signal.h>
#define PRI_SIZET "zu"
#endif

static char strL[8];
static char strT[8];
static int OpenDF;
static int OpenLS;
static int nvimcom_is_utf8;
static int allnames;

static char compldir[256];
static char tmpdir[256];
static char liblist[576];
static char globenv[576];
static char glbnvls[576];
static int glbnv_size;
static int auto_obbr;
static char *glbnv_buffer;
static char *compl_buffer;
static int compl_buffer_size = 32768;
static int building_omnils;
static int more_to_build;
void omni2ob();
void lib2ob();
void update_pkg_list();
void update_glblenv_buffer();
static void build_omnils();
void complete(const char *id, const char *base, const char *funcnm);

// Is a list or library open or closed in the Object Browser?
typedef struct liststatus_ {
    char *key;  // Name of the object or library. Library names are prefixed with "package:"
    int status; // 0: closed; 1: open
    struct liststatus_ *left;
    struct liststatus_ *right;
} ListStatus;

static ListStatus *listTree = NULL;

// Store information from an R library
typedef struct pkg_data_ {
    char *name;      // the package name
    char *version;   // the package version number
    char *fname;     // omnils_ file name in the compldir
    char *descr;     // the package short description
    char *omnils;    // a copy of the omnils_ file
    int nobjs;       // number of objects in the omnils_
    int loaded;      // in libnames_
    int to_build;    // name sent to build list
    int built;       // omnils_ found
    struct pkg_data_ *next;
} PkgData;

PkgData *pkgList;
static int nLibObjs;

int nGlbEnvFun;

static char NvimcomPort[16];
static char VimSecret[128];
static int VimSecretLen;

#ifdef WIN32
static SOCKET Sfd;
static int Tid;
#else
static int Sfd = -1;
static pthread_t Tid;
static char myport[128];
#endif

/*
static void Log(const char *fmt, ...)
{
    va_list argptr;
    FILE *f = fopen("/dev/shm/nclientserver_log", "a");
    va_start(argptr, fmt);
    vfprintf(f, fmt, argptr);
    fprintf(f, "\n");
    va_end(argptr);
    fclose(f);
}*/

static char *str_cat(char* dest, const char* src)
{
    while(*dest) dest++;
    while((*dest++ = *src++));
    return --dest;
}

static char *grow_buffer(char **b, int *sz)
{
    *sz += 32768;
    char *tmp = calloc(*sz, sizeof(char));
    strcpy(tmp, *b);
    free(*b);
    *b = tmp;
    return tmp;
}

int str_here(const char *o, const char *b)
{
    while(*b && *o){
        if(*o != *b)
            return 0;
        o++;
        b++;
    }
    if(*b)
        return 0;
    return 1;
}

static void HandleSigTerm(int s)
{
    exit(0);
}

static void RegisterPort(int bindportn)
{
    // Register the port:
    printf("call RSetMyPort('%d')\n", bindportn);
    fflush(stdout);
}

static void ParseMsg(char *buf)
{
    char *b = buf;
    if(strstr(b, VimSecret) == b){
        b += VimSecretLen;

        // Log("tcp:   %s", b);

        // Update the GlobalEnv buffer before sending the message to Nvim-R
        // because it must be ready for omni completion
        if(str_here(b, "call GlblEnvUpdated(1)"))
            update_glblenv_buffer();

        if(str_here(b, "+BuildOmnils")){
            update_pkg_list();
            build_omnils();
        }

        if (str_here(b, "+FinishArgsCompletion")) {
            // Log("%s", b);
            // strtok doesn't work here because "base" might be empty.
            char *id = b + 22;
            char *base = id;
            while (*base != ';')
                base++;
            *base = 0;
            base++;
            char *fnm = base;
            while (*fnm != ';')
                fnm++;
            *fnm = 0;
            fnm++;
            b = fnm;
            while (*b != 0 && *b != '\n')
                b++;
            *b = 0;
            //Log("%s | %s | %s\n", id, base, fnm);
            complete(id, base, fnm);
            return;
        }


        if (*b != '+'){
            // Send the command to Nvim-R
            printf("%s\n", b);
            fflush(stdout);
        }

        // Update the Object Browser after sending the message to Nvim-R to
        // avoid unnecessary delays in omni completion
        if(auto_obbr && str_here(b, "call GlblEnvUpdated(1)"))
            omni2ob();
    } else {
        fprintf(stderr, "Strange string received: \"%s\"\n", b);
        fflush(stderr);
    }
}

#ifndef WIN32
static void *NeovimServer(void *arg)
{
    unsigned short bindportn = 10100;
    ssize_t nread;
    int bsize = 5012;
    char buf[bsize];
    int result;

    struct addrinfo hints;
    struct addrinfo *rp;
    struct addrinfo *res;
    struct sockaddr_storage peer_addr;
    int Sfd = -1;
    char bindport[16];
    socklen_t peer_addr_len = sizeof(struct sockaddr_storage);

    // block SIGINT
    {
        sigset_t set;
        sigemptyset(&set);
        sigaddset(&set, SIGINT);
        sigprocmask(SIG_BLOCK, &set, NULL);
    }

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
    while(rp == NULL && bindportn < 10149){
        bindportn++;
        sprintf(bindport, "%d", bindportn);
        if(getenv("R_IP_ADDRESS"))
            result = getaddrinfo(NULL, bindport, &hints, &res);
        else
            result = getaddrinfo("127.0.0.1", bindport, &hints, &res);
        if(result != 0){
            fprintf(stderr, "Error at getaddrinfo (%s)\n", gai_strerror(result));
            fflush(stderr);
            return NULL;
        }

        for (rp = res; rp != NULL; rp = rp->ai_next) {
            Sfd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
            if (Sfd == -1)
                continue;
            if (bind(Sfd, rp->ai_addr, rp->ai_addrlen) == 0)
                break;       /* Success */
            close(Sfd);
        }
        freeaddrinfo(res);   /* No longer needed */
    }

    if (rp == NULL) {        /* No address succeeded */
        fprintf(stderr, "Could not bind\n");
        fflush(stderr);
        return NULL;
    }

    RegisterPort(bindportn);

    snprintf(myport, 127, "%d", bindportn);
    char endmsg[128];
    snprintf(endmsg, 127, "%scall >>> STOP Now <<< !!!", getenv("NVIMR_SECRET"));

    /* Read datagrams and reply to sender */
    for (;;) {
        memset(buf, 0, bsize);

        nread = recvfrom(Sfd, buf, bsize, 0,
                (struct sockaddr *) &peer_addr, &peer_addr_len);
        if (nread == -1){
            fprintf(stderr, "recvfrom failed [port %d]\n", bindportn);
            fflush(stderr);
            continue;     /* Ignore failed request */
        }
        if(strncmp(endmsg, buf, 28) == 0)
            break;

        ParseMsg(buf);
    }
    close(Sfd);
    return NULL;
}
#endif

#ifdef WIN32
static void NeovimServer(void *arg)
{
    unsigned short bindportn = 10100;
    ssize_t nread;
    int bsize = 5012;
    char buf[bsize];
    int result;

    WSADATA wsaData;
    SOCKADDR_IN RecvAddr;
    SOCKADDR_IN peer_addr;
    SOCKET Sfd;
    int peer_addr_len = sizeof (peer_addr);
    int nattp = 0;
    int nfail = 0;

    result = WSAStartup(MAKEWORD(2, 2), &wsaData);
    if (result != NO_ERROR) {
        fprintf(stderr, "WSAStartup failed with error %d.\n", result);
        fflush(stderr);
        return;
    }

    while(bindportn < 10149){
        bindportn++;
        Sfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if (Sfd == INVALID_SOCKET) {
            fprintf(stderr, "socket failed with error %d\n", WSAGetLastError());
            fflush(stderr);
            return;
        }

        RecvAddr.sin_family = AF_INET;
        RecvAddr.sin_port = htons(bindportn);
        RecvAddr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

        nattp++;
        if(bind(Sfd, (SOCKADDR *) & RecvAddr, sizeof (RecvAddr)) == 0)
            break;
        nfail++;
    }
    if(nattp == nfail){
        fprintf(stderr, "Could not bind\n");
        fflush(stderr);
        return;
    }

    RegisterPort(bindportn);

    /* Read datagrams and reply to sender */
    for (;;) {
        memset(buf, 0, bsize);

        nread = recvfrom(Sfd, buf, bsize, 0,
                (SOCKADDR *) &peer_addr, &peer_addr_len);
        if (nread == SOCKET_ERROR) {
            fprintf(stderr, "recvfrom failed with error %d [port %d]\n",
                    bindportn, WSAGetLastError());
            fflush(stderr);
            return;
        }
        if(strstr(buf, "QUIT_NVINSERVER_NOW"))
            break;

        ParseMsg(buf);
    }
    result = closesocket(Sfd);
    if (result == SOCKET_ERROR) {
        fprintf(stderr, "closesocket failed with error %d\n", WSAGetLastError());
        fflush(stderr);
        return;
    }
    WSACleanup();
    return;
}
#endif

#ifndef WIN32
static void SendToServer(const char *port, const char *msg)
{
    struct addrinfo hints;
    struct addrinfo *result, *rp;
    int s, a;
    size_t len;

    /* Obtain address(es) matching host/port */
    if(strncmp(port, "0", 15) == 0){
        fprintf(stderr, "Is R running?\n");
        fflush(stderr);
        return;
    }

    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_flags = 0;
    hints.ai_protocol = 0;

    if(getenv("R_IP_ADDRESS"))
        a = getaddrinfo(getenv("R_IP_ADDRESS"), port, &hints, &result);
    else
        a = getaddrinfo("127.0.0.1", port, &hints, &result);
    if (a != 0) {
        fprintf(stderr, "Error in getaddrinfo [port = '%s'] [msg = '%s']: %s\n",
                port, msg, gai_strerror(a));
        fflush(stderr);
        return;
    }

    for (rp = result; rp != NULL; rp = rp->ai_next) {
        s = socket(rp->ai_family, rp->ai_socktype,
                rp->ai_protocol);
        if (s == -1)
            continue;

        if (connect(s, rp->ai_addr, rp->ai_addrlen) != -1)
            break;     /* Success */

        close(s);
    }

    if (rp == NULL) {     /* No address succeeded */
        fprintf(stderr, "Could not connect.\n");
        fflush(stderr);
        return;
    }

    freeaddrinfo(result);    /* No longer needed */

    len = strlen(msg);
    if (write(s, msg, len) != (ssize_t)len) {
        fprintf(stderr, "Partial/failed write.\n");
        fflush(stderr);
        return;
    }
    close(s);
}
#endif

#ifdef WIN32
static void SendToServer(const char *port, const char *msg)
{
    WSADATA wsaData;
    struct sockaddr_in peer_addr;
    SOCKET sfd;

    if(strncmp(port, "0", 15) == 0){
        fprintf(stderr, "Port is 0\n");
        fflush(stderr);
        return;
    }

    WSAStartup(MAKEWORD(2, 2), &wsaData);
    sfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);

    if(sfd < 0){
        fprintf(stderr, "Socket failed\n");
        fflush(stderr);
        return;
    }

    peer_addr.sin_family = AF_INET;
    peer_addr.sin_port = htons(atoi(port));
    peer_addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if(connect(sfd, (struct sockaddr *)&peer_addr, sizeof(peer_addr)) < 0){
        fprintf(stderr, "Could not connect\n");
        fflush(stderr);
        return;
    }

    int len = strlen(msg);
    if (send(sfd, msg, len+1, 0) < 0) {
        fprintf(stderr, "Failed sending message\n");
        fflush(stderr);
        return;
    }

    if(closesocket(sfd) < 0){
        fprintf(stderr, "Error closing socket\n");
        fflush(stderr);
    }
}

static void SendToRConsole(char *aString){
    if(!RConsole){
        fprintf(stderr, "R Console window ID not defined [SendToRConsole]\n");
        fflush(stderr);
        return;
    }

    // The application (such as NeovimQt) might not define $WINDOWID
    if(!NvimHwnd)
        NvimHwnd = GetForegroundWindow();

    char msg[512];
    snprintf(msg, 510, "C%s%s", getenv("NVIMR_ID"), aString);
    SendToServer(NvimcomPort, msg);
    Sleep(0.02);

    // Necessary to force RConsole to actually process the line
    PostMessage(RConsole, WM_NULL, 0, 0);
}

static void RClearConsole(){
    if(!RConsole){
        fprintf(stderr, "R Console window ID not defined [RClearConsole]\n");
        fflush(stderr);
        return;
    }

    SetForegroundWindow(RConsole);
    keybd_event(VK_CONTROL, 0, 0, 0);
    keybd_event(VkKeyScan('L'), 0, KEYEVENTF_EXTENDEDKEY | 0, 0);
    Sleep(0.05);
    keybd_event(VkKeyScan('L'), 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0);
    keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0);
    Sleep(0.05);
    PostMessage(RConsole, WM_NULL, 0, 0);
}

static void SaveWinPos(char *cachedir){
    if(!RConsole){
        fprintf(stderr, "R Console window ID not defined [SaveWinPos]\n");
        fflush(stderr);
        return;
    }

    RECT rcR, rcV;
    if(!GetWindowRect(RConsole, &rcR)){
        fprintf(stderr, "Could not get R Console position\n");
        fflush(stderr);
        return;
    }

    if(!GetWindowRect(NvimHwnd, &rcV)){
        fprintf(stderr, "Could not get Neovim position\n");
        fflush(stderr);
        return;
    }

    rcR.right = rcR.right - rcR.left;
    rcR.bottom = rcR.bottom - rcR.top;
    rcV.right = rcV.right - rcV.left;
    rcV.bottom = rcV.bottom - rcV.top;

    char fname[512];
    snprintf(fname, 511, "%s/win_pos", cachedir);
    FILE *f = fopen(fname, "w");
    if(f == NULL){
        fprintf(stderr, "Could not write to '%s'\n", fname);
        fflush(stderr);
        return;
    }
    fprintf(f, "%ld\n%ld\n%ld\n%ld\n%ld\n%ld\n%ld\n%ld\n",
            rcR.left, rcR.top, rcR.right, rcR.bottom,
            rcV.left, rcV.top, rcV.right, rcV.bottom);
    fclose(f);
}

static void ArrangeWindows(char *cachedir){
    if(!RConsole){
        fprintf(stderr, "R Console window ID not defined [ArrangeWindows]\n");
        fflush(stderr);
        return;
    }

    char fname[512];
    snprintf(fname, 511, "%s/win_pos", cachedir);
    FILE *f = fopen(fname, "r");
    if(f == NULL){
        fprintf(stderr, "Could not read '%s'\n", fname);
        fflush(stderr);
        return;
    }

    RECT rcR, rcV;
    char b[32];
    if((fgets(b, 31, f))){
        rcR.left = atol(b);
    } else {
        fprintf(stderr, "Error reading R left position\n");
        fflush(stderr);
        fclose(f);
        return;
    }
    if((fgets(b, 31, f))){
        rcR.top = atol(b);
    } else {
        fprintf(stderr, "Error reading R top position\n");
        fflush(stderr);
        fclose(f);
        return;
    }
    if((fgets(b, 31, f))){
        rcR.right = atol(b);
    } else {
        fprintf(stderr, "Error reading R right position\n");
        fflush(stderr);
        fclose(f);
        return;
    }
    if((fgets(b, 31, f))){
        rcR.bottom = atol(b);
    } else {
        fprintf(stderr, "Error reading R bottom position\n");
        fflush(stderr);
        fclose(f);
        return;
    }
    if((fgets(b, 31, f))){
        rcV.left = atol(b);
    } else {
        fprintf(stderr, "Error reading Neovim left position\n");
        fflush(stderr);
        fclose(f);
        return;
    }
    if((fgets(b, 31, f))){
        rcV.top = atol(b);
    } else {
        fprintf(stderr, "Error reading Neovim top position\n");
        fflush(stderr);
        fclose(f);
        return;
    }
    if((fgets(b, 31, f))){
        rcV.right = atol(b);
    } else {
        fprintf(stderr, "Error reading Neovim right position\n");
        fflush(stderr);
        fclose(f);
        return;
    }
    if((fgets(b, 31, f))){
        rcV.bottom = atol(b);
    } else {
        fprintf(stderr, "Error reading Neovim bottom position\n");
        fflush(stderr);
        fclose(f);
        return;
    }

    if(rcR.left > 0 && rcR.top > 0 && rcR.right > 0 && rcR.bottom > 0 &&
            rcR.right > rcR.left && rcR.bottom > rcR.top){
        if(!SetWindowPos(RConsole, HWND_TOP,
                    rcR.left, rcR.top, rcR.right, rcR.bottom, 0)){
            fprintf(stderr, "Error positioning RConsole window\n");
            fflush(stderr);
            fclose(f);
            return;
        }
    }

    if(rcV.left > 0 && rcV.top > 0 && rcV.right > 0 && rcV.bottom > 0 &&
            rcV.right > rcV.left && rcV.bottom > rcV.top){
        if(!SetWindowPos(NvimHwnd, HWND_TOP,
                    rcV.left, rcV.top, rcV.right, rcV.bottom, 0)){
            fprintf(stderr, "Error positioning Neovim window\n");
            fflush(stderr);
        }
    }

    SetForegroundWindow(NvimHwnd);
    fclose(f);
}

void Windows_setup()
{
    // Set the value of NvimHwnd
    if(getenv("WINDOWID")){
#ifdef _WIN64
        NvimHwnd = (HWND)atoll(getenv("WINDOWID"));
#else
        NvimHwnd = (HWND)atol(getenv("WINDOWID"));
#endif
    } else {
        // The application (such as NeovimQt) might not define $WINDOWID
        NvimHwnd = FindWindow(NULL, "Neovim");
        if(!NvimHwnd){
            NvimHwnd = FindWindow(NULL, "nvim");
            if(!NvimHwnd){
                fprintf(stderr, "\"Neovim\" window not found\n");
                fflush(stderr);
            }
        }
    }
}
#endif

void start_server()
{
    if(!getenv("NVIMR_SECRET")){
        fprintf(stderr, "NVIMR_SECRET not found\n");
        fflush(stderr);
        exit(1);
    }
    strncpy(VimSecret, getenv("NVIMR_SECRET"), 127);
    VimSecretLen = strlen(VimSecret);

    // Finish immediately with SIGTERM
    signal(SIGTERM, HandleSigTerm);

#ifdef WIN32
    Sleep(1000);
#else
    sleep(1);
#endif

#ifdef WIN32
    Tid = _beginthread(NeovimServer, 0, NULL);
#else
    strcpy(myport, "0");
    pthread_create(&Tid, NULL, NeovimServer, NULL);
#endif
}

char *count_sep(char *b1, int *size)
{
    *size = strlen(b1);
    // Some packages do not export any objects.
    if(*size == 1)
        return b1;

    char *s = b1;
    int n = 0;
    while(*s){
        if(*s == '\006')
            n++;
        if(*s == '\n'){
            if(n == 7){
                n = 0;
            } else {
                char b[64];
                s++;
                strncpy(b, s, 16);
                fprintf(stderr, "Number of separators: %d (%s)\n", n, b);
                fflush(stderr);
                free(b1);
                return NULL;
            }
        }
        s++;
    }
    return b1;
}

char *read_file(const char *fn)
{
    FILE *f = fopen(fn, "rb");
    if(!f){
        fprintf(stderr, "Error opening '%s'", fn);
        fflush(stderr);
        return NULL;
    }
    fseek(f, 0L, SEEK_END);
    long sz = ftell(f);
    rewind(f);
    if(sz == 0){
        // List of objects is empty. Perhaps no object was created yet.
        return NULL;
    }

    char *buffer = calloc(1, sz + 1);
    if(!buffer){
        fclose(f);
        fputs("Error allocating memory\n", stderr);
        fflush(stderr);
    }

    if(1 != fread(buffer, sz, 1 , f)){
        fclose(f);
        free(buffer);
        fprintf(stderr, "Error reading '%s'\n", fn);
        fflush(stderr);
        return NULL;
    }
    fclose(f);
    return buffer;
}

char *read_omnils_file(const char *fn, int *size)
{
    char * buffer = read_file(fn);
    if(!buffer)
        return NULL;

    // Ensure that there are exactly 7 \006 between new line characters
    buffer = count_sep(buffer, size);

    if(!buffer)
        return NULL;

    if(buffer){
        char *p = buffer;
        while(*p){
            if(*p == '\006')
                *p = 0;
            p++;
        }
    }

    return buffer;
}

char *read_pkg_descr(const char *pkgnm, const char *version)
{
    char b[512];
    char *s, *d;
    snprintf(b, 511, "%s/descr_%s_%s", compldir, pkgnm, version);

    d = read_file(b);
    if (d) {
        s = d;
        while(*s != '\t' && *s != 0)
            s++;
        *s = 0;
    }
    return d;
}

void pkg_delete(PkgData *pd)
{
    free(pd->name);
    free(pd->version);
    free(pd->fname);
    if(pd->descr)
        free(pd->descr);
    if(pd->omnils)
        free(pd->omnils);
    free(pd);
}

void load_pkg_data(PkgData *pd)
{
    int size;
    pd->descr = read_pkg_descr(pd->name, pd->version);
    pd->omnils = read_omnils_file(pd->fname, &size);
    pd->nobjs = 0;
    if(pd->omnils){
        pd->loaded = 1;
        if(size > 2)
            for(int i = 0; i < size; i++)
                if(pd->omnils[i] == '\n')
                    pd->nobjs++;
    }
}

PkgData *new_pkg_data(const char *nm, const char *vrsn)
{
    char buf[1024];

    PkgData *pd = calloc(1, sizeof(PkgData));
    pd->name = malloc((strlen(nm)+1) * sizeof(char));
    strcpy(pd->name, nm);
    pd->version = malloc((strlen(vrsn)+1) * sizeof(char));
    strcpy(pd->version, vrsn);
    pd->loaded = 1;

    snprintf(buf, 1023, "%s/omnils_%s_%s", compldir, nm, vrsn);
    pd->fname = malloc((strlen(buf)+1) * sizeof(char));
    strcpy(pd->fname, buf);

    // Check if both fun_ and omnils_ exist
    pd->built = 1;
    if (access(buf, F_OK) != 0) {
        pd->built = 0;
    } else {
        snprintf(buf, 1023, "%s/fun_%s_%s", compldir, nm, vrsn);
        if (access(buf, F_OK) != 0)
            pd->built = 0;
    }
    return pd;
}

PkgData *get_pkg(const char *nm)
{
    if(!pkgList)
        return NULL;

    PkgData *pd = pkgList;
    do{
        if(strcmp(pd->name, nm) == 0)
            return pd;
        pd = pd->next;
    } while(pd);

    return NULL;
}

void add_pkg(const char *nm, const char *vrsn)
{
    PkgData *tmp = pkgList;
    pkgList = new_pkg_data(nm, vrsn);
    pkgList->next = tmp;
}

// Get a string with R code, save it in a file and source the file with R.
static int run_R_code(const char *s, int senderror)
{
    char fnm[512];

    snprintf(fnm, 511, "%s/bo_code.R", tmpdir);
    FILE *f = fopen(fnm, "w");
    if (f) {
        fwrite(s, sizeof(char), strlen(s), f);
        fclose(f);
    } else {
        fprintf(stderr, "Failed to write \"%s/bo_code.R\"\n", fnm);
        return 1;
    }

#ifdef WIN32
    char tdir[1024];
    snprintf(tdir, 1023, "%s", tmpdir);
    char *p = tdir;
    while (*p) {
        if (*p == '/')
            *p = '\\';
        p++;
    }

    // https://docs.microsoft.com/en-us/windows/win32/procthread/creating-a-child-process-with-redirected-input-and-output
    SECURITY_ATTRIBUTES saAttr;
    saAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
    saAttr.bInheritHandle = TRUE;
    saAttr.lpSecurityDescriptor = NULL;

    HANDLE g_hChildStd_OUT_Rd = NULL;
    HANDLE g_hChildStd_OUT_Wr = NULL;

    if (! CreatePipe(&g_hChildStd_OUT_Rd, &g_hChildStd_OUT_Wr, &saAttr, 0)) {
        fprintf(stderr, "CreatePipe error\n");
        return 1;
    }

    // Ensure the read handle to the pipe for STDOUT is not inherited.
    if (! SetHandleInformation(g_hChildStd_OUT_Rd, HANDLE_FLAG_INHERIT, 0)) {
        fprintf(stderr, "SetHandleInformation error\n");
        return 1;
    }

    PROCESS_INFORMATION pi;
    STARTUPINFO si;
    BOOL res = FALSE;

    // Set up members of the PROCESS_INFORMATION structure.

    ZeroMemory(&pi, sizeof(PROCESS_INFORMATION));

    // Set up members of the STARTUPINFO structure.
    // This structure specifies the STDIN and STDOUT handles for redirection.

    ZeroMemory(&si, sizeof(STARTUPINFO));
    si.cb = sizeof(STARTUPINFO);
    si.hStdError = g_hChildStd_OUT_Wr;
    si.hStdOutput = NULL;
    si.hStdInput = NULL;
    si.dwFlags |= STARTF_USESTDHANDLES;

    // Create the child process.

    res = CreateProcess(NULL,
            "R.exe --quiet --no-restore --no-save --no-echo --slave -f bo_code.R",  // Command line
            NULL,          // process security attributes
            NULL,          // primary thread security attributes
            TRUE,          // handles are inherited
            CREATE_NO_WINDOW,             // creation flags
            NULL,          // use parent's environment
            tdir,             // use tmpdir directory
            &si,  // STARTUPINFO pointer
            &pi);  // receives PROCESS_INFORMATION

    // If an error occurs, exit the application.
    if (! res) {
        fprintf(stderr, "CreateProcess error: %ld\n", GetLastError());
        fflush(stderr);
        return 0;
    }

    DWORD exit_code;
    WaitForSingleObject(pi.hProcess, INFINITE);
    GetExitCodeProcess(pi.hProcess, &exit_code);

    // Close handles to the child process and its primary thread.
    // Some applications might keep these handles to monitor the status
    // of the child process, for example.
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    // Close handle to the stderr pipes no longer needed by the child process.
    // If they are not explicitly closed, there is no way to recognize that the child process has ended.
    CloseHandle(g_hChildStd_OUT_Wr);

    // Read output from the child process's pipe for STDOUT
    // and write to the parent process's pipe in a file.
    // Stop when there is no more data.
    DWORD dwRead;
    char chBuf[1024];
    res = FALSE;

    snprintf(fnm, 511, "%s\\run_R_stderr", tdir);
    f = fopen(fnm, "w");
    for (;;) {
        res = ReadFile(g_hChildStd_OUT_Rd, chBuf, 1024, &dwRead, NULL);
        if (!res || dwRead == 0)
            break;
        if (f)
            fwrite(chBuf, sizeof(char), strlen(chBuf), f);
    }
    if (f)
        fclose(f);

    if (exit_code != 0) {
        if (senderror) {
            printf("call ShowBuildOmnilsError('%ld')\n", exit_code);
            fflush(stdout);
        }
        return 0;
    }
    return 1;

#else
    char b[1024];
    snprintf(b, 1023,
            "R --quiet --no-restore --no-save --no-echo --slave -f \"%s/bo_code.R\""
            " > \"%s/run_R_stdout\" 2> \"%s/run_R_stderr\"", tmpdir, tmpdir, tmpdir);

    int stt;
    if ((stt = system(b)) != 0) {
        if (senderror) {
            printf("call ShowBuildOmnilsError('%d')\n", stt);
            fflush(stdout);
        }
        return 0;
    }
    return 1;
#endif
}

// Build the fun_ and omnils_ files required for syntax highlighting and omni
// completion before starting R. This function is called by Nvim-R
static void fake_libnames(const char *s)
{
    char b[2048];
    snprintf(b, 1500,
            "nms <- c(%s)\n"
            "pkgs <- utils::installed.packages()\n"
            "nms <- nms[nms %%in%% rownames(pkgs)]\n"
            "cat(paste(nms, utils::installed.packages()[nms, 'Built'], collapse = '\\n', sep = '_'),\n"
            "    '\\n', sep = '', file = '%s/libnames_%s')\n", s, tmpdir, getenv("NVIMR_ID"));

    int stt = run_R_code(b, 0);

    // Don't rely only in the return vale of run_R_code because it's wrong on Windows
    snprintf(b, 512, "%s/libnames_%s", tmpdir, getenv("NVIMR_ID"));
    if (stt && access(b, F_OK) == 0) {
        update_pkg_list();
        build_omnils();
        snprintf(b, 512, "%s/libs_in_ncs_%s", tmpdir, getenv("NVIMR_ID"));
        if (access(b, F_OK) == 0) {
            char *lnames = read_file(b);
            if (lnames) {
                snprintf(b, 512, "%s/last_default_libnames", compldir);
                FILE *f = fopen(b, "w");
                if (f){
                    fwrite(lnames, sizeof(char), strlen(lnames), f);
                    fclose(f);
                }
                free(lnames);
            }
        }
    } else {
        printf("call ShowBuildOmnilsError('%d')\n", stt);
    }
}

// Read the list of libraries loaded in R, and run another R instance to build
// the omnils_, fun_ and descr_ files in compldir.
static void build_omnils()
{
    if (building_omnils) {
        more_to_build = 1;
        return;
    }
    building_omnils = 1;

    char buf[1024];

    memset(compl_buffer, 0, compl_buffer_size);
    char *p = compl_buffer;

    PkgData *pkg = pkgList;

    // It would be easier to call R once for each library, but we will build
    // all cache files at once to avoid the cost of starting R many times.
    p = str_cat(p, "library('nvimcom')\nnvimcom:::nvim.buildomnils(c(");
    int k = 0;
    while (pkg) {
        if (pkg->to_build == 0) {
            if (k == 0)
                snprintf(buf, 63, "'%s'", pkg->name);
            else
                snprintf(buf, 63, ", '%s'", pkg->name);
            p = str_cat(p, buf);
            pkg->to_build = 1;
            k++;
        }
        pkg = pkg->next;
    }
    p = str_cat(p, "))");

    if (k)
        run_R_code(compl_buffer, 1);

    // Don't check the return value of run_R_code because some packages might
    // have been successfully built before R exiting with status > 0.

    // Check if all files were really built before trying to load them.
    pkg = pkgList;
    while (pkg) {
        if (pkg->built == 0 && access(pkg->fname, F_OK) == 0)
            pkg->built = 1;
        if (pkg->built && !pkg->omnils)
            load_pkg_data(pkg);
        pkg = pkg->next;
    }

    // If this function was called while it was running, build the remaining cache
    // files before saving the list of libraries whose cache files were built.
    building_omnils = 0;
    if (more_to_build) {
        more_to_build = 0;
        build_omnils();
        return;
    }

    // Finally create a list of built omnils_ because libnames_ might have
    // already changed and Nvim-R would try to read omnils_ files not built yet.
    snprintf(buf, 511, "%s/libs_in_ncs_%s", tmpdir, getenv("NVIMR_ID"));
    FILE *f = fopen(buf, "w");
    if (f) {
        PkgData *pkg = pkgList;
        while (pkg) {
            if (pkg->loaded && pkg->built && pkg->omnils)
                fprintf(f, "%s_%s\n", pkg->name, pkg->version);
            pkg = pkg->next;
        }
        fclose(f);
    }

    // Message to Neovim: Update both syntax and Rhelp_list
    printf("call UpdateSynRhlist()\n");
    fflush(stdout);
}

void update_pkg_list()
{
    char buf[512];
    char *s, *vrsn;
    char lbnm[128];
    PkgData *pkg;

    snprintf(buf, 511, "%s/libnames_%s", tmpdir, getenv("NVIMR_ID"));
    FILE *flib = fopen(buf, "r");
    if(!flib){
        fprintf(stderr, "Failed to open \"%s\"\n", buf);
        fflush(stderr);
        return;
    }

    // Consider that all packages were unloaded
    pkg = pkgList;
    while(pkg){
        pkg->loaded = 0;
        pkg = pkg->next;
    }

    while((s = fgets(lbnm, 127, flib))){
        while(*s != '_')
            s++;
        *s = 0;
        s++;
        vrsn = s;
        while(*s != '\n')
            s++;
        *s = 0;

        pkg = get_pkg(lbnm);
        if (pkg)
            pkg->loaded = 1;
        else
            add_pkg(lbnm, vrsn);
    }
    fclose(flib);

    // No command run yet
    if(!pkgList)
        return;

    // Delete data from unloaded packages to ensure that reloaded packages go
    // to the bottom of the Object Browser list
    pkg = pkgList;
    if(pkg->loaded == 0){
        pkgList = pkg->next;
        pkg_delete(pkg);
    } else {
        PkgData *prev = pkg;
        pkg = pkg->next;
        while(pkg){
            if(pkg->loaded == 0){
                prev->next = pkg->next;
                pkg_delete(pkg);
                pkg = prev->next;
            } else {
                prev = pkg;
                pkg = prev->next;
            }
        }
    }
}

ListStatus* search(const char *s)
{
    ListStatus *node = listTree;
    int cmp = strcmp(node->key, s);
    while(node && cmp != 0){
        if(cmp > 0)
            node = node->right;
        else
            node = node->left;
        if(node)
            cmp = strcmp(node->key, s);
    }
    if(cmp == 0)
        return node;
    else
        return NULL;
}

ListStatus* new_ListStatus(const char *s, int stt)
{
    ListStatus *p;
    p = calloc(1, sizeof(ListStatus));
    p->key = malloc((strlen(s)+1)*sizeof(char));
    strcpy(p->key, s);
    p->status = stt;
    return p;
}

ListStatus* insert(ListStatus *root, const char *s, int stt)
{
    if(!root)
        return new_ListStatus(s, stt);
    int cmp = strcmp(root->key, s);
    if(cmp > 0)
        root->right = insert(root->right, s, stt);
    else
        root->left = insert(root->left, s, stt);
    return root;
}

int get_list_status(const char *s, int stt)
{
    if(listTree){
        ListStatus *p = search(s);
        if(p)
            return p->status;
        insert(listTree, s, stt);
        return stt;
    }
    listTree = new_ListStatus(s, stt);
    return stt;
}

void toggle_list_status(const char *s)
{
    ListStatus *p = search(s);
    if(p)
        p->status = !p->status;
}

static const char *write_ob_line(const char *p, const char *bs, char *prfx, int closeddf, FILE *fl)
{
    char base1[128];
    char base2[128];
    char prefix[128];
    char newprfx[96];
    char descr[160];
    const char *f[7];
    const char *s;    // Diagnostic pointer
    const char *bsnm; // Name of object including its parent list, data.frame or S4 object
    int df;           // Is data.frame? If yes, start open unless closeddf = 1
    int i, j;
    int ne;

    nLibObjs--;

    bsnm = p;
    p += strlen(bs);

    i = 0;
    while(i < 7){
        f[i] = p;
        i++;
        while(*p != 0)
            p++;
        p++;
    }
    while(*p != '\n' && *p != 0)
        p++;
    if(*p == '\n')
        p++;

    if(closeddf)
        df = 0;
    else if(f[1][0] == '$')
        df = OpenDF;
    else
        df = OpenLS;

    // Replace \004 with curly closing single quote
    if(f[1][0] == '\003')
        s = f[5];
    else
        s = f[6];
    if(s[0] == 0){
        descr[0] = 0;
    } else {
        i = 0; j = 0;
        while(s[i] && i < 159){
            if(s[i] == '\004'){
                if(nvimcom_is_utf8){
                    descr[j] = '\xe2';
                    j++;
                    descr[j] = '\x80';
                    j++;
                    descr[j] = '\x99';
                } else {
                    descr[j] = '\'';
                }
            } else {
                descr[j] = s[i];
            }
            i++; j++;
        }
        descr[j] = 0;
    }

    if(!(bsnm[0] == '.' && allnames == 0)){
        if(f[1][0] == '\003')
            fprintf(fl, "   %s(#%s\t%s\n", prfx, f[0], descr);
        else
            fprintf(fl, "   %s%c#%s\t%s\n", prfx, f[1][0], f[0], descr);
    }

    if(*p == 0)
        return p;

    if(f[1][0] == '[' || f[1][0] == '$' || f[1][0] == '<' || f[1][0] == ':'){
        s = f[6];
        s++; s++; s++; // Number of elements (list)
        if(f[1][0] == '$'){
            while(*s && *s != ' ')
                s++;
            s++; // Number of columns (data.frame)
        }
        ne = atoi(s);
        if(f[1][0] == '[' || f[1][0] == '$' || f[1][0] == ':'){
            snprintf(base1, 127, "%s$", bsnm); // Named list
            snprintf(base2, 127, "%s[[", bsnm); // Unnamed list
        } else {
            snprintf(base1, 127, "%s@", bsnm); // S4 object
            snprintf(base2, 127, "%s[[", bsnm); // S4 object always have names but base2 must be defined
        }

        if(get_list_status(bsnm, df) == 0){
            while(str_here(p, base1) || str_here(p, base2)){
                while(*p != '\n')
                    p++;
                p++;
                nLibObjs--;
            }
            return p;
        }

        if(str_here(p, base1) == 0 && str_here(p, base2) == 0)
            return p;

        int len = strlen(prfx);
        if(nvimcom_is_utf8){
            int j = 0, i = 0;
            while(i < len){
                if(prfx[i] == '\xe2'){
                    i += 3;
                    if(prfx[i-1] == '\x80' || prfx[i-1] == '\x94'){
                        newprfx[j] = ' '; j++;
                    } else {
                        newprfx[j] = '\xe2'; j++;
                        newprfx[j] = '\x94'; j++;
                        newprfx[j] = '\x82'; j++;
                    }
                } else {
                    newprfx[j] = prfx[i];
                    i++, j++;
                }
            }
            newprfx[j] = 0;
        } else {
            for(int i = 0; i < len; i++){
                if(prfx[i] == '-' || prfx[i] == '`')
                    newprfx[i] = ' ';
                else
                    newprfx[i] = prfx[i];
            }
            newprfx[len] = 0;
        }

        // Check if the next list element really is there
        while(str_here(p, base1) || str_here(p, base2)){
            // Check if this is the last element in the list
            s = p;
            while(*s != '\n')
                s++;
            s++;
            ne--;
            if(ne == 0){
                snprintf(prefix, 112, "%s%s", newprfx, strL);
            } else {
                if(str_here(s, base1) || str_here(s, base2))
                    snprintf(prefix, 112, "%s%s", newprfx, strT);
                else
                    snprintf(prefix, 112, "%s%s", newprfx, strL);
            }

            if(*p){
                if(str_here(p, base1))
                    p = write_ob_line(p, base1, prefix, 0, fl);
                else
                    p = write_ob_line(p, bsnm, prefix, 0, fl);
            }
        }
    }
    return p;
}

void hi_glbenv_fun()
{
    char *p = glbnv_buffer;
    char *s;

    printf("call UpdateLocalFunctions('");
    while(*p){
        s = p;
        while(*s != 0)
            s++;
        s++;
        if (*s == '\003')
            printf("%s ", p);
        while(*p != '\n')
            p++;
        p++;
    }
    printf("')\n");
    fflush(stdout);
}

void update_glblenv_buffer()
{
    if(glbnv_buffer)
        free(glbnv_buffer);
    glbnv_buffer = read_omnils_file(glbnvls, &glbnv_size);
    if(glbnv_buffer == NULL)
        return;

    int n = 0;
    int max = glbnv_size - 5;
    for(int i = 0; i < max; i++)
        if(glbnv_buffer[i] == '\003'){
            n++;
            i += 7;
        }

    if(n != nGlbEnvFun){
        nGlbEnvFun = n;
        hi_glbenv_fun();
    }
}

void omni2ob()
{
    FILE *f = fopen(globenv, "w");
    if(!f){
        fprintf(stderr, "Error opening \"%s\" for writing\n", globenv);
        fflush(stderr);
        return;
    }

    fprintf(f, ".GlobalEnv | Libraries\n\n");

    if (glbnv_buffer) {
        const char *s = glbnv_buffer;
        while(*s)
            s = write_ob_line(s, "", "", 0, f);
    }

    fclose(f);
    if(auto_obbr){
        fputs("call UpdateOB('GlobalEnv')\n", stdout);
        fflush(stdout);
    }
}

void lib2ob()
{
    FILE *f = fopen(liblist, "w");
    if(!f){
        fprintf(stderr, "Failed to open \"%s\"\n", liblist);
        fflush(stderr);
        return;
    }
    fprintf(f, "Libraries | .GlobalEnv\n\n");

    char lbnmc[512];
    PkgData *pkg;
    const char *p;
    int stt;

    pkg = pkgList;
    while(pkg){
        if(pkg->loaded){
            if(pkg->descr)
                fprintf(f, "   :#%s\t%s\n", pkg->name, pkg->descr);
            else
                fprintf(f, "   :#%s\t\n", pkg->name);
            snprintf(lbnmc, 511, "%s:", pkg->name);
            stt = get_list_status(lbnmc, 0);
            if(pkg->omnils && pkg->nobjs > 0 && stt == 1){
                p = pkg->omnils;
                nLibObjs = pkg->nobjs - 1;
                while(*p){
                    if(nLibObjs == 0)
                        p = write_ob_line(p, "", strL, 1, f);
                    else
                        p = write_ob_line(p, "", strT, 1, f);
                }
            }
        }
        pkg = pkg->next;
    }

    fclose(f);
    fputs("call UpdateOB('libraries')\n", stdout);
    fflush(stdout);
}

void change_all(ListStatus *root, int stt)
{
    if(root != NULL){
        // Open all but libraries
        if(!(stt == 1 && root->key[strlen(root->key) - 1] == ':'))
            root->status = stt;
        change_all(root->left, stt);
        change_all(root->right, stt);
    }
}

void print_listTree(ListStatus *root, FILE *f)
{
    if(root != NULL){
        fprintf(f, "%d :: %s\n", root->status, root->key);
        print_listTree(root->left, f);
        print_listTree(root->right, f);
    }
}

void objbr_setup()
{
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

    strncpy(compldir, getenv("NVIMR_COMPLDIR"), 255);
    strncpy(tmpdir, getenv("NVIMR_TMPDIR"), 255);
    snprintf(liblist, 575, "%s/liblist_%s", tmpdir, getenv("NVIMR_ID"));
    snprintf(globenv, 575, "%s/globenv_%s", tmpdir, getenv("NVIMR_ID"));
    snprintf(glbnvls, 575, "%s/GlobalEnvList_%s", tmpdir, getenv("NVIMR_ID"));

    if(getenv("NVIMR_OPENDF"))
        OpenDF = 1;
    else
        OpenDF = 0;
    if(getenv("NVIMR_OPENLS"))
        OpenLS = 1;
    else
        OpenLS = 0;
    if(getenv("NVIMR_OBJBR_ALLNAMES"))
        allnames = 1;
    else
        allnames = 0;

    // List tree sentinel
    listTree = new_ListStatus("base:", 0);

    compl_buffer = calloc(compl_buffer_size, sizeof(char));
}

int count_twice(const char *b1, const char *b2, const char ch)
{
    int n1 = 0;
    int n2 = 0;
    for(unsigned long i = 0; i < strlen(b1); i++)
        if(b1[i] == ch)
            n1++;
    for(unsigned long i = 0; i < strlen(b2); i++)
        if(b2[i] == ch)
            n2++;
    return n1 == n2;
}

// Return user_data of a specific item with function usage, title and
// description to be displayed in the float window
void compl_info(const char *wrd, const char *pkg)
{
    int i, nsz, len;
    const char *f[7];
    char *s;

    if(strcmp(pkg, ".GlobalEnv") == 0){
        s = glbnv_buffer;
    } else {
        PkgData *pd = pkgList;
        while(pd){
            if(strcmp(pkg, pd->name) == 0)
                break;
            else
                pd = pd->next;
        }

        if(pd == NULL)
            return;

        s = pd->omnils;
    }

    memset(compl_buffer, 0, compl_buffer_size);
    char *p = compl_buffer;

    while(*s != 0){
        if(strcmp(s, wrd) == 0){
            i = 0;
            while(i < 7){
                f[i] = s;
                i++;
                while(*s != 0)
                    s++;
                s++;
            }
            while(*s != '\n' && *s != 0)
                s++;
            if(*s == '\n')
                s++;

            if (f[1][0] == '\003' && str_here(f[4], "['not_checked']")) {
                snprintf(compl_buffer, 1024, "%s/args_for_completion", tmpdir);
                remove(compl_buffer);
                snprintf(compl_buffer, 1024, "E%snvimcom:::nvim.GlobalEnv.fun.args(\"%s\")\n", getenv("NVIMR_ID"), wrd);
                SendToServer(NvimcomPort, compl_buffer);
                return;
            }

            // Avoid buffer overflow if the information is bigger than compl_buffer.
            nsz = strlen(f[4]) + strlen(f[5]) + strlen(f[6]) + 256;
            len = p - compl_buffer;
            while((compl_buffer_size - nsz - len) < 0){
                p = grow_buffer(&compl_buffer, &compl_buffer_size);
                len = strlen(compl_buffer);
            }

            p = str_cat(p, "{'cls': '");
            if(f[1][0] == '\003')
                p = str_cat(p, "f");
            else
                p = str_cat(p, f[1]);
            p = str_cat(p, "', 'word': '");
            p = str_cat(p, wrd);
            p = str_cat(p, "', 'pkg': '");
            p = str_cat(p, f[3]);
            p = str_cat(p, "', 'usage': [");
            p = str_cat(p, f[4]);
            p = str_cat(p, "], 'ttl': '");
            p = str_cat(p, f[5]);
            p = str_cat(p, "', 'descr': '");
            p = str_cat(p, f[6]);
            p = str_cat(p, "'}");
            printf("call SetComplInfo(%s)\n", compl_buffer);
            fflush(stdout);
            return;
        }
        while(*s != '\n')
            s++;
        s++;
    }
    printf("call SetComplInfo({})\n");
    fflush(stdout);
}

// Return the menu items for omni completion, but don't include function
// usage, and tittle and description of objects because if the buffer becomes
// too big it will be truncated.
char *parse_omnls(const char *s, const char *base, char *p)
{
    int i, nsz, len;
    const char *f[7];

    while(*s != 0){
        if(str_here(s, base)){
            i = 0;
            while(i < 7){
                f[i] = s;
                i++;
                while(*s != 0)
                    s++;
                s++;
            }
            while(*s != '\n' && *s != 0)
                s++;
            if(*s == '\n')
                s++;

            // Skip elements of lists unless the user is really looking for them,
            // and skip lists if the user is looking for one of its elements.
            if(!count_twice(base, f[0], '@'))
                continue;
            if(!count_twice(base, f[0], '$'))
                continue;
            if(!count_twice(base, f[0], '['))
                continue;

            // Avoid buffer overflow if the information is bigger than compl_buffer.
            nsz = strlen(f[0]) + 256;
            len = p - compl_buffer;
            while((compl_buffer_size - nsz - len) < 0){
                p = grow_buffer(&compl_buffer, &compl_buffer_size);
                len = strlen(compl_buffer);
            }

            p = str_cat(p, "{'word': '");
            p = str_cat(p, f[0]);
            p = str_cat(p, "', 'menu': '");
            if(f[2][0] != 0){
                p = str_cat(p, f[2]);
            } else {
                switch(f[1][0]){
                    case '{':
                        p = str_cat(p, "num ");
                        break;
                    case '~':
                        p = str_cat(p, "char");
                        break;
                    case '!':
                        p = str_cat(p, "fac ");
                        break;
                    case '$':
                        p = str_cat(p, "data");
                        break;
                    case '[':
                        p = str_cat(p, "list");
                        break;
                    case '%':
                        p = str_cat(p, "log ");
                        break;
                    case '\003':
                        p = str_cat(p, "func");
                        break;
                    case '<':
                        p = str_cat(p, "S4  ");
                        break;
                    case '&':
                        p = str_cat(p, "lazy");
                        break;
                    case ':':
                        p = str_cat(p, "env ");
                        break;
                    case '*':
                        p = str_cat(p, "?   ");
                        break;
                }
            }
            p = str_cat(p, " [");
            p = str_cat(p, f[3]);
            p = str_cat(p, "]', 'user_data': {'cls': '");
            if(f[1][0] == '\003')
                p = str_cat(p, "f");
            else
                p = str_cat(p, f[1]);
            p = str_cat(p, "', 'pkg': '");
            p = str_cat(p, f[3]);
            p = str_cat(p, "'}}, "); // Don't include fields 4, 5 and 6 because big data will be truncated.
        } else {
            while(*s != '\n')
                s++;
            s++;
        }
    }
    return p;
}

void complete(const char *id, const char *base, const char *funcnm)
{
    char *p, *s, *t;
    int sz;

    memset(compl_buffer, 0, compl_buffer_size);
    p = compl_buffer;

    // Complete function arguments
    if(funcnm){
        // Get documentation info for each item
        char buf[512];
        snprintf(buf, 511, "%s/args_for_completion", tmpdir);
        s = read_file(buf);
        if(s){
            sz = strlen(s) + 4;
            while(sz > compl_buffer_size)
                p = grow_buffer(&compl_buffer, &compl_buffer_size);
            snprintf(buf, 511, "{'word': '%s", base);
#ifdef WIN32
            t = strtok(s, "\n\r");
#else
            t = strtok(s, "\n");
#endif
            while(t){
                if(strstr(t, buf))
                    p = str_cat(p, t);
#ifdef WIN32
                t = strtok(NULL, "\n\r");
#else
                t = strtok(NULL, "\n");
#endif
            }
            free(s);
        }
        if(base[0] == 0){
            // base will be empty if completing only function arguments
            printf("\005%" PRI_SIZET "\005call SetComplMenu(%s, [%s])\n", strlen(compl_buffer) + strlen(id) + 23, id, compl_buffer);
            fflush(stdout);
            return;
        }
    }

    // Finish filling the compl_buffer
    if(glbnv_buffer)
        p = parse_omnls(glbnv_buffer, base, p);
    PkgData *pd = pkgList;
    while(pd){
        if(pd->omnils)
            p = parse_omnls(pd->omnils, base, p);
        pd = pd->next;
    }

    printf("\005%" PRI_SIZET "\005call SetComplMenu(%s, [%s])\n", strlen(compl_buffer) + strlen(id) + 23, id, compl_buffer);
    fflush(stdout);
}

int main(int argc, char **argv){

    char line[1024];
    if(argc == 3 && getenv("NVIMR_PORT") && getenv("NVIMR_SECRET")){
        snprintf(line, 1023, "%scall SyncTeX_backward('%s', %s)",
                getenv("NVIMR_SECRET"), argv[1], argv[2]);
        SendToServer(getenv("NVIMR_PORT"), line);
        return 0;
    }

    FILE *f;
    char *msg;
    char t;
    memset(line, 0, 1024);
    strcpy(NvimcomPort, "0");

    objbr_setup();

#ifdef WIN32
    Windows_setup();
#endif

    start_server();

    while(fgets(line, 1023, stdin)){

        for(unsigned int i = 0; i < strlen(line); i++)
            if(line[i] == '\n' || line[i] == '\r')
                line[i] = 0;
        // Log("stdin: %s",  line);
        msg = line;
        switch(*msg){
            case '1': // SetPort
                msg++;
#ifdef WIN32
                char *p = msg;
                while(*p != ' ')
                    p++;
                *p = 0;
                p++;
                memcpy(NvimcomPort, msg, 15);
#ifdef _WIN64
                RConsole = (HWND)atoll(p);
#else
                RConsole = (HWND)atol(p);
#endif
                if(msg[0] == '0')
                    RConsole = NULL;
#else
                memcpy(NvimcomPort, msg, 15);
#endif
                break;
            case '2': // Send message
                msg++;
                SendToServer(NvimcomPort, msg);
                break;
            case '3':
                msg++;
                switch(*msg){
                    case '1': // Update GlobalEnv
                        auto_obbr = 1;
                        omni2ob();
                        break;
                    case '2': // Update Libraries
                        auto_obbr = 1;
                        lib2ob();
                        break;
                    case '3': // Open/Close list
                        msg++;
                        t = *msg;
                        msg++;
                        toggle_list_status(msg);
                        if(t == 'G')
                            omni2ob();
                        else
                            lib2ob();
                        break;
                    case '4': // Close/Open all
                        msg++;
                        if(*msg == 'O')
                            change_all(listTree, 1);
                        else
                            change_all(listTree, 0);
                        msg++;
                        if(*msg == 'G')
                            omni2ob();
                        else
                            lib2ob();
                        break;
                    case '5': // Save fake libnames_
                        msg++;
                        fake_libnames(msg);
                        break;
                    case '7':
                        f = fopen("/tmp/listTree", "w");
                        print_listTree(listTree, f);
                        fclose(f);
                        break;
                }
                break;
            case '4': // Print pkg info
                update_glblenv_buffer();
                printf("call NclientserverInfo('Loaded packages:");
                PkgData *pkg = pkgList;
                while(pkg){
                    printf(" %s", pkg->name);
                    pkg = pkg->next;
                }
                printf("')\n");
                fflush(stdout);
                break;
            case '5':
                msg++;
                char *id = msg;
                while(*msg != '\003')
                    msg++;
                *msg = 0;
                msg++;
                complete(id, msg, NULL);
                break;
            case '6':
                msg++;
                char *wrd = msg;
                while(*msg != '\002')
                    msg++;
                *msg = 0;
                msg++;
                compl_info(wrd, msg);
                break;
#ifdef WIN32
            case '7':
                // Messages related with the Rgui on Windows
                msg++;
                switch(*msg){
                    case '1': // Check if R is running
                        if(PostMessage(RConsole, WM_NULL, 0, 0)){
                            printf("call RWarningMsg('R was already started')\n");
                            fflush(stdout);
                        } else {
                            printf("call CleanNvimAndStartR()\n");
                            fflush(stdout);
                        }
                        break;
                    case '3': // SendToRConsole
                        msg++;
                        SendToRConsole(msg);
                        break;
                    case '4': // SaveWinPos
                        msg++;
                        SaveWinPos(msg);
                        break;
                    case '5': // ArrangeWindows
                        msg++;
                        ArrangeWindows(msg);
                        break;
                    case '6':
                        RClearConsole();
                        break;
                    case '7': // RaiseNvimWindow
                        if(NvimHwnd)
                            SetForegroundWindow(NvimHwnd);
                        break;
                }
                break;
#endif
            case '8': // Quit now
                exit(0);
                break;
            default:
                fprintf(stderr, "Unknown command received: [%d] %s\n", line[0], msg);
                fflush(stderr);
                break;
        }
        memset(line, 0, 1024);
    }
#ifdef WIN32
    closesocket(Sfd);
    WSACleanup();
#else
    close(Sfd);
    SendToServer(myport, ">>> STOP Now <<< !!!");
    pthread_join(Tid, NULL);
#endif
    return 0;
}
