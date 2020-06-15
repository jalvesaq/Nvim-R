#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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
HWND NvimHwnd = NULL;
HWND RConsole = NULL;
#else
#include <stdint.h>
#include <sys/socket.h>
#include <netdb.h>
#include <pthread.h>
#include <signal.h>
#include <sys/time.h>
#endif

static FILE *F2;
static char strL[8];
static char strT[8];
static int OpenDF;
static int OpenLS;
static int nvimcom_is_utf8;

static char tmpdir[256];
static char liblist[576];
static char globenv[576];
static char glbnvls[576];
void omni2ob();
void lib2ob();

typedef struct liststatus_ {
    char *key;
    int status;
    struct liststatus_ *left;
    struct liststatus_ *right;
} ListStatus;

static ListStatus *listTree = NULL;

typedef struct pkg_descr_ {
    char *name;
    char *descr;
    struct pkg_descr_ *next;
} PkgDescr;

PkgDescr *pkgList;

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
    char *bbuf = buf;
    if(strstr(bbuf, VimSecret) == bbuf){
        bbuf += VimSecretLen;
        printf("%s\n", bbuf);
        fflush(stdout);
    } else {
        fprintf(stderr, "Strange string received: \"%s\"\n", bbuf);
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
        fprintf(stderr, "Port is 0\n");
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
        fprintf(stderr, "Error in getaddrinfo [port = '%s'] [msg = '%s']: %s\n", port, msg, gai_strerror(a));
        fflush(stderr);
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
        fprintf(stderr, "Could not connect.\n");
        fflush(stderr);
        return;
    }

    freeaddrinfo(result);	   /* No longer needed */

    len = strlen(msg);
    if (write(s, msg, len) != (ssize_t)len) {
        fprintf(stderr, "Partial/failed write.\n");
        fflush(stderr);
        return;
    }
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

    // FIXME: Delete this code when $WINDOWID is implemented in NeovimQt
    if(!NvimHwnd)
        NvimHwnd = GetForegroundWindow();

    char msg[512];
    snprintf(msg, 510, "\005%s%s", getenv("NVIMR_ID"), aString);
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
        //fprintf(stderr, "$WINDOWID not defined\n");
        //fflush(stderr);
        // FIXME: Delete this code when $WINDOWID is implemented in NeovimQt
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

PkgDescr *new_pkg_descr(const char *nm, const char *dscr)
{
    PkgDescr *pd = calloc(1, sizeof(PkgDescr));
    pd->name = malloc((strlen(nm)+1) * sizeof(char));
    pd->descr = malloc((strlen(dscr)+1) * sizeof(char));
    strcpy(pd->name, nm);
    strcpy(pd->descr, dscr);
    return pd;
}

char *get_pkg_descr(const char *nm)
{
    if(!pkgList)
        return NULL;

    PkgDescr *pd = pkgList;
    do{
        if(strcmp(pd->name, nm) == 0)
            return pd->descr;
        pd = pd->next;
    } while(pd);

    return NULL;
}

void add_pkg_descr(const char *nm, const char *dscr)
{
    if(pkgList){
        PkgDescr *pd = pkgList;
        while(pd->next)
            pd = pd->next;
        pd->next = new_pkg_descr(nm, dscr);
    } else {
        pkgList = new_pkg_descr(nm, dscr);
    }
}

void read_pkg_descr()
{
    char b[128];
    char *s, *nm, *dscr;
    FILE *f = fopen("/home/aquino/.cache/Nvim-R/pack_descriptions", "r");
    if(!f)
        return;

    while((s = fgets(b, 127, f))){
        nm = b;
        while(*s != '\t' && *s != 0)
            s++;
        if(*s == '\t'){
            *s = 0;
            s++;
            dscr = s;
            while(*s != '\t' && *s != 0){
                s++;
                if(*s == '\t'){
                    *s = 0;
                    if(!get_pkg_descr(nm))
                        add_pkg_descr(nm, dscr);
                    break;
                }
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

void toggle_list_status(ListStatus *root, const char *s)
{
    ListStatus *p = search(s);
    if(p)
        p->status = !p->status;
}

static char *write_line(char *p, const char *bs, char *prfx, int closeddf)
{
    char base[64];
    char prefix[127];
    char newprfx[96];
    char *s;    // Diagnostic pointer
    char *nm;   // Name of object
    char *bsnm; // Name of object including its parent list, data.frame or S4 object
    char *ne;   // Number of elements in lists, data.frames and S4 objects
    char *nr;   // Number of rows in data.frames
    char *dc;   // Description
    char tp;    // Type of object
    int df;     // Is data.frame? If yes, start open unless closeddf = 1
    int i, e;

    bsnm = p;
    p += strlen(bs);
    nm = p;
    while(*p != '\006'){
        if(*p == 0)
            return p;
        p++;
    }
    *p = 0;
    p++;
    if(closeddf)
        df = 0;
    else if(*p == 'd')
        df = OpenDF;
    else
        df = OpenLS;
    if(p[0] == 'n')
        tp = '{';
    else if(p[0] == 'c')
        tp = '"';
    else if(p[0] == 'f' && p[1] == 'a')
        tp = '\'';
    else if(p[0] == 'd')
        tp = '[';
    else if(p[0] == 'l' && p[1] == 'i')
        tp = '[';
    else if(p[0] == 'l' && p[1] == 'o')
        tp = '%';
    else if(p[0] == 'f' && p[1] == 'u')
        tp = '(';
    else if(p[0] == 's')
        tp = '<';
    else if(p[0] == 'l' && p[1] == 'a')
        tp = '&';
    else if(p[0] == 'e')
        tp = ':';
    else
        tp = '=';

    i = 0;
    while(i < 3){
        p++;
        if(*p == '\006'){
            *p = 0;
            i++;
        }
    }
    p++;

    ne = p;
    while(*p != '\006' && *p != '\001')
        p++;
    if(*p == '\001'){
        *p = 0;
        p++;
        nr = p;
        while(*p != '\006')
            p++;
        *p = 0;
    } else {
        *p = 0;
        nr = p;
    }
    e = atoi(ne);
    p++;

    while(*p != '\006')
        p++;
    *p = 0;
    p++;
    dc = p;

    while(*p != '\n')
        p++;
    *p = 0;
    p++;

    if(tp == '[' || tp == '<')
        if(*nr)
            fprintf(F2, "   %s%c#%s\t [%s, %d]\n", prfx, tp, nm, nr, e);
        else
            fprintf(F2, "   %s%c#%s\t [%d]\n", prfx, tp, nm, e);
    else
        fprintf(F2, "   %s%c#%s\t%s\n", prfx, tp, nm, dc);

    if(tp == '[' || tp == '<'){
        strncpy(base, bsnm, 63);
        if(tp == '['){
            if(p[strlen(base)] == '$') // Named list
                strncat(base, "$", 63);
        } else
            strncat(base, "@", 63);


        if(e > 0){
            if(get_list_status(bsnm, df) == 0){
                while(strstr(p, base) == p){
                    while(*p != '\n')
                        p++;
                    p++;
                }
                return p;
            }

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
            while(strstr(p, base) == p){
                // Check if this is the last element in the list
                s = p;
                while(*s && *s != '\n')
                    s++;
                if(*s == '\n')
                    s++;
                if(strstr(s, base) == s)
                    snprintf(prefix, 112, "%s%s", newprfx, strT);
                else
                    snprintf(prefix, 112, "%s%s", newprfx, strL);

                if(*p)
                    p = write_line(p, base, prefix, 0);
            }
        }
    }
    return p;
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

void omni2ob()
{
    char *buffer = read_file(glbnvls);

    if(!buffer)
        return;

    F2 = fopen(globenv, "w");
    if(!F2){
        fprintf(stderr, "Error opening \"%s\" for writing\n", globenv);
        fflush(stderr);
        free(buffer);
        return;
    }
    
    fprintf(F2, ".GlobalEnv | Libraries\n\n");

    char *s;

    s = buffer;
    while(*s)
        s = write_line(s, "", "", 0);

    free(buffer);
    fclose(F2);
    fputs("call UpdateOB('GlobalEnv')\n", stdout);
    fflush(stdout);
}

int find_in_cache(char buf[512], const char *onm)
{
    DIR *d;
    struct dirent *e;
    char b[512];

    d = opendir(getenv("NVIMR_COMPLDIR"));
    if(d != NULL){
        snprintf(b, 511, "omnils_%s_", onm);
        while((e = readdir (d))){
            if(strstr(e->d_name, b)){
                snprintf(buf, 511, "%s/%s", getenv("NVIMR_COMPLDIR"), e->d_name);
                closedir(d);
                return 1;
            }
        }
        closedir(d);
        fprintf(stderr, "Couldn't find omni file for \"%s\"\n", onm);
    } else {
        fprintf(stderr, "Couldn't open the cache directory (%s)\n",
                getenv("NVIMR_COMPLDIR"));
    }
    fflush(stderr);
    return 0;
}

void lib2ob()
{
    F2 = fopen(liblist, "w");
    if(!F2){
        fprintf(stderr, "Failed to open \"%s\"\n", liblist);
        fflush(stderr);
        return;
    }
    fprintf(F2, "Libraries | .GlobalEnv\n\n");

    char lbnm[128];
    char lbnmc[512];
    char buf[512];
    char *buffer;
    char *s;
    char *d;
    char *p;
    //FILE *of;

    snprintf(buf, 511, "%s/libnames_%s", tmpdir, getenv("NVIMR_ID"));
    FILE *flib = fopen(buf, "r");
    if(!flib){
        fprintf(stderr, "Failed to open \"%s\"\n", buf);
        fflush(stderr);
        return;
    }

    while((s = fgets(lbnm, 511, flib))){
        while(*s != '\n')
            s++;
        *s = 0;
        d = get_pkg_descr(lbnm);
        if(!d){
            // Perhaps the library was installed in this R session
            read_pkg_descr();
            d = get_pkg_descr(lbnm);
        }
        if(d)
            fprintf(F2, "   :#%s\t%s\n", lbnm, d);
        else
            fprintf(F2, "   :#%s\t\n", lbnm);
        snprintf(lbnmc, 511, "%s:", lbnm);
        if(get_list_status(lbnmc, 0) == 1){
            if(find_in_cache(buf, lbnm)){
                buffer = read_file(buf);
                if(!buffer){
                    fclose(F2);
                    fclose(flib);
                    return;
                }
                p = buffer;
                while(*p){
                    s = p;
                    while(*s != '\n') // Check if this is the last line
                        s++;
                    s++;
                    if(*s == 0)
                        p = write_line(p, "", strL, 1);
                    else
                        p = write_line(p, "", strT, 1);
                }
                free(buffer);
            }
        }
    }

    fclose(F2);
    fclose(flib);
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

    // List tree sentinel
    listTree = new_ListStatus("base:", 0);
}

int main(int argc, char **argv){

    if(argc == 2 && strcmp(argv[1], "random") == 0){
        time_t t;
        srand((unsigned) time(&t));
        printf("%d%d %d%d", rand(), rand(), rand(), rand());
        return 0;
    }

    read_pkg_descr();

    objbr_setup();

    FILE *f;

    char line[1024];
    char *msg;
    char t;
    memset(line, 0, 1024);
    strcpy(NvimcomPort, "0");

    if(argc == 3 && getenv("NVIMR_PORT") && getenv("NVIMR_SECRET")){
        snprintf(line, 1023, "%scall SyncTeX_backward('%s', %s)", getenv("NVIMR_SECRET"), argv[1], argv[2]);
        SendToServer(getenv("NVIMR_PORT"), line);
        return 0;
    }

#ifdef WIN32
    Windows_setup();
#endif

    start_server();

    while(fgets(line, 1023, stdin)){
        for(unsigned int i = 0; i < strlen(line); i++)
            if(line[i] == '\n' || line[i] == '\r')
                line[i] = 0;
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
                strncpy(NvimcomPort, msg, 15);
#ifdef _WIN64
                RConsole = (HWND)atoll(p);
#else
                RConsole = (HWND)atol(p);
#endif
                if(msg[0] == '0')
                    RConsole = NULL;
#else
                strncpy(NvimcomPort, msg, 15);
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
                        omni2ob();
                        break;
                    case '2': // Update Libraries
                        lib2ob();
                        break;
                    case '3': // Open/Close list
                        msg++;
                        t = *msg;
                        msg++;
                        toggle_list_status(listTree, msg);
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
                    case '7':
                        f = fopen("/tmp/listTree", "w");
                        print_listTree(listTree, f);
                        fclose(f);
                        break;
                }
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
