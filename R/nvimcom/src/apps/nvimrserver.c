#include <ctype.h>     // Character type functions
#include <dirent.h>    // Directory entry
#include <signal.h>    // Signal handling
#include <stdarg.h>    // Variable argument functions
#include <stdio.h>     // Standard input/output definitions
#include <stdlib.h>    // Standard library
#include <string.h>    // String handling functions
#include <sys/stat.h>  // Data returned by the stat() function
#include <sys/types.h> // Data types
#include <unistd.h>    // POSIX operating system API
#ifdef WIN32
#include <inttypes.h>
#include <process.h>
#include <time.h>
#include <winsock2.h>
#include <windows.h>
HWND NvimHwnd = NULL;
HWND RConsole = NULL;
#define bzero(b, len) (memset((b), '\0', (len)), (void)0)
#ifdef _WIN64
#define PRI_SIZET PRIu64
#else
#define PRI_SIZET PRIu32
#endif
#else
#include <netdb.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <sys/socket.h>
#define PRI_SIZET "zu"
#endif

static char strL[8];        // String for last element prefix in tree view
static char strT[8];        // String for tree element prefix in tree view
static int OpenDF;          // Flag for open data frames in tree view
static int OpenLS;          // Flag for open lists in tree view
static int nvimcom_is_utf8; // Flag for UTF-8 encoding
static int allnames; // Flag for showing all names, including starting with '.'

static char compl_cb[64];      // Completion callback buffer
static char compl_info[64];    // Completion info buffer
static char compldir[256];     // Directory for completion files
static char tmpdir[256];       // Temporary directory
static char localtmpdir[256];  // Local temporary directory
static char liblist[576];      // Library list buffer
static char globenv[576];      // Global environment buffer
static int auto_obbr;          // Auto object browser flag
static size_t glbnv_buffer_sz; // Global environment buffer size
static char *glbnv_buffer;     // Global environment buffer
static char *compl_buffer;     // Completion buffer
static char *finalbuffer;      // Final buffer for message processing
static unsigned long compl_buffer_size = 32768; // Completion buffer size
static unsigned long fb_size = 1024;            // Final buffer size
static int n_omnils_build;                      // number of omni lists to build
static int building_omnils;                     // Flag for building Omni lists
static int more_to_build;                       // Flag for more lists to build
static int has_args_to_read;                    // Flag for args to read

void omni2ob(void);                 // Convert Omni completion to Object Browser
void lib2ob(void);                  // Convert Library to object browser
void update_inst_libs(void);        // Update installed libraries
void update_pkg_list(char *libnms); // Update package list
void update_glblenv_buffer(char *g); // Update global environment buffer
static void build_omnils(void);      // Build Omni lists
static void finish_bol();            // Finish building of lists
void complete(const char *id, char *base, char *funcnm,
              char *args); // Perform completion

// List of paths to libraries
typedef struct libpaths_ {
    char *path;             // Path to library
    struct libpaths_ *next; // Next path
} LibPath;

LibPath *libpaths; // Pointer to first library path

// List of installed libraries
typedef struct instlibs_ {
    char *name;             // Library name
    char *title;            // Library title
    char *descr;            // Library description
    int si;                 // still installed flag
    struct instlibs_ *next; // Next installed library
} InstLibs;

InstLibs *instlibs; // Pointer to first installed library

// Is a list or library open or closed in the Object Browser?
typedef struct liststatus_ {
    char *key; // Name of the object or library. Library names are prefixed with
               // "package:"
    int status;                // 0: closed; 1: open
    struct liststatus_ *left;  // Left node
    struct liststatus_ *right; // Right node
} ListStatus;

static ListStatus *listTree = NULL; // Root node of the list status tree

// Store information from an R library
typedef struct pkg_data_ {
    char *name;    // the package name
    char *version; // the package version number
    char *fname;   // omnils_ file name in the compldir
    char *descr;   // the package short description
    char *omnils;  // a copy of the omnils_ file
    char *args;    // a copy of the args_ file
    int nobjs;     // number of objects in the omnils_
    int loaded;    // Loaded flag in libnames_
    int to_build;  // Flag to indicate if the name is sent to build list
    int built;     // Flag to indicate if omnils_ found
    struct pkg_data_ *next; // Pointer to next package data
} PkgData;

PkgData *pkgList;    // Pointer to first package data
static int nLibObjs; // Number of library objects

int nGlbEnvFun; // Number of global environment functions

static int r_conn;          // R connection status flag
static char VimSecret[128]; // Secret for communication with Vim
static int VimSecretLen;    // Length of Vim secret

#ifdef WIN32
static int Tid; // Thread ID
#else
static pthread_t Tid; // Thread ID
#endif
struct sockaddr_in servaddr; // Server address structure
static int sockfd;           // socket file descriptor
static int connfd;           // Connection file descriptor

#define Debug_NRS_
__attribute__((format(printf, 1, 2))) static void
Log(const char *fmt, ...) // Logging function for debugging
{
#ifdef Debug_NRS
    va_list argptr;
    FILE *f = fopen("/dev/shm/nvimrserver_log", "a");
    va_start(argptr, fmt);
    vfprintf(f, fmt, argptr);
    fprintf(f, "\n");
    va_end(argptr);
    fclose(f);
#endif
}

static char *str_cat(char *dest,
                     const char *src) // Function to concatenate strings
{
    while (*dest)
        dest++;
    while ((*dest++ = *src++))
        ;
    return --dest;
}

static int ascii_ic_cmp(const char *a,
                        const char *b) // ASCII case-insensitive compare
{
    int d;
    unsigned x, y;
    while (*a && *b) {
        x = (unsigned char)*a;
        y = (unsigned char)*b;
        if (x <= 'Z')
            x += 32;
        if (y <= 'Z')
            y += 32;
        d = x - y;
        if (d != 0)
            return d;
        a++;
        b++;
    }
    return 0;
}

static char *grow_buffer(char **b, unsigned long *sz,
                         unsigned long inc) // Function to grow a buffer
{
    Log("grow_buffer(%lu, %lu) [%lu, %lu]", *sz, inc, compl_buffer_size,
        fb_size);
    *sz += inc;
    char *tmp = calloc(*sz, sizeof(char));
    strcpy(tmp, *b);
    free(*b);
    *b = tmp;
    return tmp;
}

void fix_x13(char *s) // Replace all instances of '\x13' in the string with '\''
{
    while (*s != 0) {
        if (*s == '\x13')
            *s = '\'';
        s++;
    }
}

void fix_single_quote(
    char *s) // Replace all instances of single quote in the string with '\x13'
{
    while (*s != 0) {
        if (*s == '\'')
            *s = '\x13';
        s++;
    }
}

int str_here(const char *o,
             const char *b) // Check if string b is at the start of string o
{
    while (*b && *o) {
        if (*o != *b)
            return 0;
        o++;
        b++;
    }
    if (*b)
        return 0;
    return 1;
}

static void
HandleSigTerm(__attribute__((unused)) int s) // Signal handler for SIGTERM
{
    exit(0);
}

static void RegisterPort(int bindportn) // Function to register port number to R
{
    // Register the port:
    printf("call RSetMyPort('%d')\n", bindportn);
    fflush(stdout);
}

static void ParseMsg(char *b) // Parse the message from R
{
    Log("ParseMsg(): strlen(b) = %" PRI_SIZET "", strlen(b));

    if (*b == '+') {
        b++;
        switch (*b) {
        case 'G':
            b++;
            update_glblenv_buffer(b);
            if (auto_obbr) // Update the Object Browser after sending the
                           // message to Nvim-R to
                omni2ob(); // avoid unnecessary delays in omni completion
            break;
        case 'L':
            b++;
            update_pkg_list(b);
            build_omnils();
            if (auto_obbr)
                lib2ob();
            break;
        case 'A': // strtok doesn't work here because "base" might be empty.
            b++;
            char *args;
            char *id = b;
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
            args = fnm;
            while (*args != 0 && *args != ';')
                args++;
            *args = 0;
            args++;
            b = args;
            while (*b != 0 && *b != '\n')
                b++;
            *b = 0;
            complete(id, base, fnm, args);
            break;
        }
        return;
    }

    // Send the command to Nvim-R
    printf("\x11%" PRI_SIZET "\x11%s\n", strlen(b), b);
    fflush(stdout);
}

// Adapted from
// https://www.geeksforgeeks.org/socket-programming-in-cc-handling-multiple-clients-on-server-without-multi-threading/
static void init_listening() // Initialise listening for incoming connections
{
    Log("init_listening()");
#ifdef WIN32
    int len;
#else
    socklen_t len;
#endif
    struct sockaddr_in cli;
    int res = 1;
    int port = 10101;

#ifdef WIN32
    WSADATA d;
    int wr = WSAStartup(MAKEWORD(2, 2), &d);
    if (wr != 0) {
        fprintf(stderr, "WSAStartup failed: %d\n", wr);
        fflush(stderr);
    }
#endif
    sockfd = socket(AF_INET, SOCK_STREAM, 0);

    if (sockfd == -1) {
        fprintf(stderr, "socket creation failed...\n");
        fflush(stderr);
        exit(1);
    }

    bzero(&servaddr, sizeof(servaddr));

    // assign IP, PORT
    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = htonl(INADDR_ANY);

    while (port < 10199) {
        servaddr.sin_port = htons(port);
        res = bind(sockfd, (struct sockaddr *)&servaddr, sizeof(servaddr));
        if (res == 0)
            break;
        port++;
    }
    if (res == 0) {
        RegisterPort(port);
        Log("init_listening: RegisterPort");
    } else {
        fprintf(stderr, "Failed to bind to port %d\n", port);
        fflush(stderr);
        exit(2);
    }

    // Now server is ready to listen and verification
    if ((listen(sockfd, 5)) != 0) {
        fprintf(stderr, "Listen failed...\n");
        fflush(stderr);
        exit(3);
    }
    Log("init_listening: Listen succeeded");

    len = sizeof(cli);

    // Accept the data packet from client and verification
    connfd = accept(sockfd, (struct sockaddr *)&cli, &len);
    if (connfd < 0) {
        fprintf(stderr, "server accept failed...\n");
        fflush(stderr);
        exit(4);
    }
    r_conn = 1;
    Log("init_listening: accept succeeded");
}

static void get_whole_msg(char *b) // Get the whole message from the socket
{
    Log("get_whole_msg()");
    char *p;
    char tmp[1];
    int msg_size;

    if (strstr(b, VimSecret) != b) {
        fprintf(stderr, "Strange string received {%s}: \"%s\"\n", VimSecret, b);
        fflush(stderr);
        return;
    }
    p = b + VimSecretLen;

    // Get the message size
    p[9] = 0;
    msg_size = atoi(p);
    p += 10;

    // Allocate enough memory to the final buffer
    if (finalbuffer) {
        memset(finalbuffer, 0, fb_size);
        if (msg_size > fb_size)
            finalbuffer =
                grow_buffer(&finalbuffer, &fb_size, msg_size - fb_size + 1024);
    } else {
        if (msg_size > fb_size)
            fb_size = msg_size + 1024;
        finalbuffer = calloc(fb_size, sizeof(char));
    }

    p = finalbuffer;
    for (;;) {
        if ((recv(connfd, tmp, 1, 0) == 1))
            *p = *tmp;
        else
            break;
        if (*p == '\x11')
            break;
        p++;
    }
    *p = 0;

    // FIXME: Delete this check when the code proved to be reliable
    if (strlen(finalbuffer) != msg_size) {
        fprintf(stderr, "Divergent TCP message size: %" PRI_SIZET " x %d\n",
                strlen(p), msg_size);
        fflush(stderr);
    }

    ParseMsg(finalbuffer);
}

#ifdef WIN32
static void
receive_msg(void *arg) // Thread function to receive messages on Windows
#else
static void *receive_msg() // Thread function to receive messages on Unix
#endif
{
    size_t blen = VimSecretLen + 9;
    char b[32];
    size_t rlen;

    for (;;) {
        bzero(b, blen);
        rlen = recv(connfd, b, blen, 0);
        if (rlen == blen) {
            Log("TCP in [%" PRI_SIZET " bytes] (message header): %s", blen, b);
            get_whole_msg(b);
        } else {
            r_conn = 0;
#ifdef WIN32
            closesocket(sockfd);
            WSACleanup();
#else
            close(sockfd);
#endif
            if (rlen != -1 && rlen != 0) {
                fprintf(stderr, "TCP socket -1: restarting...\n");
                fprintf(stderr,
                        "Wrong TCP data length: %" PRI_SIZET " x %" PRI_SIZET
                        "\n",
                        blen, rlen);
                fflush(stderr);
                break;
            }
            init_listening();
        }
    }
#ifndef WIN32
    return NULL;
#endif
}

void send_to_nvimcom(
    char *msg) // Function to send messages to R (nvimcom package)
{
    Log("TCP out: %s", msg);
    if (connfd) {
        size_t len = strlen(msg);
        if (send(connfd, msg, len, 0) != (ssize_t)len) {
            fprintf(stderr, "Partial/failed write.\n");
            fflush(stderr);
            return;
        }
    } else {
        fprintf(stderr, "nvimcom is not connected");
        fflush(stderr);
    }
}

#ifdef WIN32
static void SendToRConsole(char *aString) {
    if (!RConsole) {
        fprintf(stderr, "R Console window ID not defined [SendToRConsole]\n");
        fflush(stderr);
        return;
    }

    // The application (such as NeovimQt) might not define $WINDOWID
    if (!NvimHwnd)
        NvimHwnd = GetForegroundWindow();

    char msg[1024];
    snprintf(msg, 1023, "C%s%s", getenv("NVIMR_ID"), aString);
    send_to_nvimcom(msg);
    Sleep(0.02);

    // Necessary to force RConsole to actually process the line
    PostMessage(RConsole, WM_NULL, 0, 0);
}

static void RClearConsole() {
    if (!RConsole) {
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

static void SaveWinPos(char *cachedir) {
    if (!RConsole) {
        fprintf(stderr, "R Console window ID not defined [SaveWinPos]\n");
        fflush(stderr);
        return;
    }

    RECT rcR, rcV;
    if (!GetWindowRect(RConsole, &rcR)) {
        fprintf(stderr, "Could not get R Console position\n");
        fflush(stderr);
        return;
    }

    if (!GetWindowRect(NvimHwnd, &rcV)) {
        fprintf(stderr, "Could not get Neovim position\n");
        fflush(stderr);
        return;
    }

    rcR.right = rcR.right - rcR.left;
    rcR.bottom = rcR.bottom - rcR.top;
    rcV.right = rcV.right - rcV.left;
    rcV.bottom = rcV.bottom - rcV.top;

    char fname[1032];
    snprintf(fname, 1031, "%s/win_pos", cachedir);
    FILE *f = fopen(fname, "w");
    if (f == NULL) {
        fprintf(stderr, "Could not write to '%s'\n", fname);
        fflush(stderr);
        return;
    }
    fprintf(f, "%ld\n%ld\n%ld\n%ld\n%ld\n%ld\n%ld\n%ld\n", rcR.left, rcR.top,
            rcR.right, rcR.bottom, rcV.left, rcV.top, rcV.right, rcV.bottom);
    fclose(f);
}

static void ArrangeWindows(char *cachedir) {
    if (!RConsole) {
        fprintf(stderr, "R Console window ID not defined [ArrangeWindows]\n");
        fflush(stderr);
        return;
    }

    char fname[1032];
    snprintf(fname, 1031, "%s/win_pos", cachedir);
    FILE *f = fopen(fname, "r");
    if (f == NULL) {
        fprintf(stderr, "Could not read '%s'\n", fname);
        fflush(stderr);
        return;
    }

    RECT rcR, rcV;
    char b[32];
    if ((fgets(b, 31, f))) {
        rcR.left = atol(b);
    } else {
        fprintf(stderr, "Error reading R left position\n");
        fflush(stderr);
        fclose(f);
        return;
    }
    if ((fgets(b, 31, f))) {
        rcR.top = atol(b);
    } else {
        fprintf(stderr, "Error reading R top position\n");
        fflush(stderr);
        fclose(f);
        return;
    }
    if ((fgets(b, 31, f))) {
        rcR.right = atol(b);
    } else {
        fprintf(stderr, "Error reading R right position\n");
        fflush(stderr);
        fclose(f);
        return;
    }
    if ((fgets(b, 31, f))) {
        rcR.bottom = atol(b);
    } else {
        fprintf(stderr, "Error reading R bottom position\n");
        fflush(stderr);
        fclose(f);
        return;
    }
    if ((fgets(b, 31, f))) {
        rcV.left = atol(b);
    } else {
        fprintf(stderr, "Error reading Neovim left position\n");
        fflush(stderr);
        fclose(f);
        return;
    }
    if ((fgets(b, 31, f))) {
        rcV.top = atol(b);
    } else {
        fprintf(stderr, "Error reading Neovim top position\n");
        fflush(stderr);
        fclose(f);
        return;
    }
    if ((fgets(b, 31, f))) {
        rcV.right = atol(b);
    } else {
        fprintf(stderr, "Error reading Neovim right position\n");
        fflush(stderr);
        fclose(f);
        return;
    }
    if ((fgets(b, 31, f))) {
        rcV.bottom = atol(b);
    } else {
        fprintf(stderr, "Error reading Neovim bottom position\n");
        fflush(stderr);
        fclose(f);
        return;
    }

    if (rcR.left > 0 && rcR.top > 0 && rcR.right > 0 && rcR.bottom > 0 &&
        rcR.right > rcR.left && rcR.bottom > rcR.top) {
        if (!SetWindowPos(RConsole, HWND_TOP, rcR.left, rcR.top, rcR.right,
                          rcR.bottom, 0)) {
            fprintf(stderr, "Error positioning RConsole window\n");
            fflush(stderr);
            fclose(f);
            return;
        }
    }

    if (rcV.left > 0 && rcV.top > 0 && rcV.right > 0 && rcV.bottom > 0 &&
        rcV.right > rcV.left && rcV.bottom > rcV.top) {
        if (!SetWindowPos(NvimHwnd, HWND_TOP, rcV.left, rcV.top, rcV.right,
                          rcV.bottom, 0)) {
            fprintf(stderr, "Error positioning Neovim window\n");
            fflush(stderr);
        }
    }

    SetForegroundWindow(NvimHwnd);
    fclose(f);
}

void Windows_setup() // Setup Windows-specific configurations
{
    // Set the value of NvimHwnd
    if (getenv("WINDOWID")) {
#ifdef _WIN64
        NvimHwnd = (HWND)atoll(getenv("WINDOWID"));
#else
        NvimHwnd = (HWND)atol(getenv("WINDOWID"));
#endif
    } else {
        // The application (such as NeovimQt) might not define $WINDOWID
        NvimHwnd = FindWindow(NULL, "Neovim");
        if (!NvimHwnd) {
            NvimHwnd = FindWindow(NULL, "nvim");
            if (!NvimHwnd) {
                fprintf(stderr, "\"Neovim\" window not found\n");
                fflush(stderr);
            }
        }
    }
}
#endif

void start_server(void) // Start server and listen for connections
{
    // Finish immediately with SIGTERM
    signal(SIGTERM, HandleSigTerm);

    init_listening();

    // Receive messages from TCP and output them to stdout
#ifdef WIN32
    Tid = _beginthread(receive_msg, 0, NULL);
#else
    pthread_create(&Tid, NULL, receive_msg, NULL);
#endif
}

char *count_sep(char *b1, int *size) // Count separators in buffer
{
    *size = strlen(b1);
    // Some packages do not export any objects.
    if (*size == 1)
        return b1;

    char *s = b1;
    int n = 0;
    while (*s) {
        if (*s == '\006')
            n++;
        if (*s == '\n') {
            if (n == 7) {
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

char *read_file(const char *fn, int verbose) {
    FILE *f = fopen(fn, "rb");
    if (!f) {
        if (verbose) {
            fprintf(stderr, "Error opening '%s'", fn);
            fflush(stderr);
        }
        return NULL;
    }
    fseek(f, 0L, SEEK_END);
    long sz = ftell(f);
    rewind(f);
    if (sz == 0) {
        // List of objects is empty. Perhaps no object was created yet.
        fclose(f);
        return NULL;
    }

    char *buffer = calloc(1, sz + 1);
    if (!buffer) {
        fclose(f);
        fputs("Error allocating memory\n", stderr);
        fflush(stderr);
        return NULL;
    }

    if (1 != fread(buffer, sz, 1, f)) {
        fclose(f);
        free(buffer);
        fprintf(stderr, "Error reading '%s'\n", fn);
        fflush(stderr);
        return NULL;
    }
    fclose(f);
    return buffer;
}

void *check_omils_buffer(char *buffer, int *size) {
    // Ensure that there are exactly 7 \006 between new line characters
    buffer = count_sep(buffer, size);

    if (!buffer)
        return NULL;

    if (buffer) {
        char *p = buffer;
        while (*p) {
            if (*p == '\006')
                *p = 0;
            if (*p == '\'')
                *p = '\x13';
            if (*p == '\x12')
                *p = '\'';
            p++;
        }
    }
    return buffer;
}

char *read_omnils_file(const char *fn, int *size) {
    Log("read_omnils_file(%s)", fn);
    char *buffer = read_file(fn, 1);
    if (!buffer)
        return NULL;

    return check_omils_buffer(buffer, size);
}

char *get_pkg_descr(const char *pkgnm) {
    Log("get_pkg_descr(%s)", pkgnm);
    InstLibs *il = instlibs;
    while (il) {
        if (strcmp(il->name, pkgnm) == 0) {
            char *s = malloc((strlen(il->title) + 1) * sizeof(char));
            strcpy(s, il->title);
            fix_x13(s);
            return s;
        }
        il = il->next;
    }
    return NULL;
}

void pkg_delete(PkgData *pd) {
    free(pd->name);
    free(pd->version);
    free(pd->fname);
    if (pd->descr)
        free(pd->descr);
    if (pd->omnils)
        free(pd->omnils);
    if (pd->args)
        free(pd->args);
    free(pd);
}

void load_pkg_data(PkgData *pd) {
    int size;
    if (!pd->descr)
        pd->descr = get_pkg_descr(pd->name);
    pd->omnils = read_omnils_file(pd->fname, &size);
    pd->nobjs = 0;
    if (pd->omnils) {
        pd->loaded = 1;
        if (size > 2)
            for (int i = 0; i < size; i++)
                if (pd->omnils[i] == '\n')
                    pd->nobjs++;
    }
}

PkgData *new_pkg_data(const char *nm, const char *vrsn) {
    char buf[1024];

    PkgData *pd = calloc(1, sizeof(PkgData));
    pd->name = malloc((strlen(nm) + 1) * sizeof(char));
    strcpy(pd->name, nm);
    pd->version = malloc((strlen(vrsn) + 1) * sizeof(char));
    strcpy(pd->version, vrsn);
    pd->descr = get_pkg_descr(pd->name);
    pd->loaded = 1;

    snprintf(buf, 1023, "%s/omnils_%s_%s", compldir, nm, vrsn);
    pd->fname = malloc((strlen(buf) + 1) * sizeof(char));
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

PkgData *get_pkg(const char *nm) {
    if (!pkgList)
        return NULL;

    PkgData *pd = pkgList;
    do {
        if (strcmp(pd->name, nm) == 0)
            return pd;
        pd = pd->next;
    } while (pd);

    return NULL;
}

void add_pkg(const char *nm, const char *vrsn) {
    PkgData *tmp = pkgList;
    pkgList = new_pkg_data(nm, vrsn);
    pkgList->next = tmp;
}

// Get a string with R code, save it in a file and source the file with R.
static int run_R_code(const char *s, int senderror) {
    char fnm[1024];

    snprintf(fnm, 1023, "%s/bo_code.R", tmpdir);
    FILE *f = fopen(fnm, "w");
    if (f) {
        fwrite(s, sizeof(char), strlen(s), f);
        fclose(f);
    } else {
        fprintf(stderr, "Failed to write \"%s/bo_code.R\"\n", fnm);
        fflush(stderr);
        return 1;
    }

#ifdef WIN32
    char tdir[512];
    snprintf(tdir, 511, "%s", tmpdir);
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

    if (!CreatePipe(&g_hChildStd_OUT_Rd, &g_hChildStd_OUT_Wr, &saAttr, 0)) {
        fprintf(stderr, "CreatePipe error\n");
        fflush(stderr);
        return 1;
    }

    // Ensure the read handle to the pipe for STDOUT is not inherited.
    if (!SetHandleInformation(g_hChildStd_OUT_Rd, HANDLE_FLAG_INHERIT, 0)) {
        fprintf(stderr, "SetHandleInformation error\n");
        fflush(stderr);
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

    char b[1024];
    snprintf(b, 1023, "NVIMR_TMPDIR=%s", getenv("NVIMR_REMOTE_TMPDIR"));
    putenv(b);
    snprintf(b, 1023, "NVIMR_COMPLDIR=%s", getenv("NVIMR_REMOTE_COMPLDIR"));
    putenv(b);
    snprintf(b, 1023,
             "%s --quiet --no-restore --no-save --no-echo --slave -f bo_code.R",
             getenv("NVIMR_RPATH"));

    res = CreateProcess(NULL,
                        b,                // Command line
                        NULL,             // process security attributes
                        NULL,             // primary thread security attributes
                        TRUE,             // handles are inherited
                        CREATE_NO_WINDOW, // creation flags
                        NULL,             // use parent's environment
                        tdir,             // use tmpdir directory
                        &si,              // STARTUPINFO pointer
                        &pi);             // receives PROCESS_INFORMATION

    // If an error occurs, exit the application.
    if (!res) {
        fprintf(stderr, "CreateProcess error: %ld\n", GetLastError());
        fflush(stderr);
        return 0;
    }

    snprintf(b, 1023, "NVIMR_TMPDIR=%s", tmpdir);
    putenv(b);
    snprintf(b, 1023, "NVIMR_COMPLDIR=%s", compldir);
    putenv(b);

    DWORD exit_code;
    WaitForSingleObject(pi.hProcess, INFINITE);
    GetExitCodeProcess(pi.hProcess, &exit_code);

    // Close handles to the child process and its primary thread.
    // Some applications might keep these handles to monitor the status
    // of the child process, for example.
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    // Close handle to the stderr pipes no longer needed by the child process.
    // If they are not explicitly closed, there is no way to recognize that the
    // child process has ended.
    CloseHandle(g_hChildStd_OUT_Wr);

    // Read output from the child process's pipe for STDOUT
    // and write to the parent process's pipe in a file.
    // Stop when there is no more data.
    DWORD dwRead;
    char chBuf[1024];
    res = FALSE;

    snprintf(fnm, 1023, "%s\\run_R_stderr", tdir);
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
             "NVIMR_TMPDIR=%s NVIMR_COMPLDIR=%s '%s' --quiet --no-restore "
             "--no-save --no-echo --slave -f \"%s/bo_code.R\""
             " > \"%s/run_R_stdout\" 2> \"%s/run_R_stderr\"",
             getenv("NVIMR_REMOTE_TMPDIR"), getenv("NVIMR_REMOTE_COMPLDIR"),
             getenv("NVIMR_RPATH"), tmpdir, tmpdir, tmpdir);
    Log("R command: %s", b);

    int stt = system(b);
    if (stt != 0 && stt != 512) { // ssh success status seems to be 512
        if (senderror) {
            printf("call ShowBuildOmnilsError('%d')\n", stt);
            fflush(stdout);
        }
        return 0;
    }
    return 1;
#endif
}

int read_field_data(char *s, int i) {
    while (s[i]) {
        if (s[i] == '\n' && s[i + 1] == ' ') {
            s[i] = ' ';
            i++;
            while (s[i] == ' ')
                i++;
        }
        if (s[i] == '\n') {
            s[i] = 0;
            break;
        }
        i++;
    }
    return i;
}

// Read the DESCRIPTION file to get Title and Description fields.
void parse_descr(char *descr, const char *fnm) {
    int m, n;
    int z = 0;
    int k = 0;
    int l = strlen(descr);
    char *ttl, *dsc;
    ttl = NULL;
    dsc = NULL;
    InstLibs *lib, *ptr, *prev;
    while (k < l) {
        if ((k == 0 || descr[k - 1] == '\n' || descr[k - 1] == 0) &&
            str_here(descr + k, "Title: ")) {
            k += 7;
            ttl = descr + k;
            k = read_field_data(descr, k);
            descr[k] = 0;
        }
        if ((k == 0 || descr[k - 1] == '\n' || descr[k - 1] == 0) &&
            str_here(descr + k, "Description: ")) {
            k += 13;
            dsc = descr + k;
            k = read_field_data(descr, k);
            descr[k] = 0;
        }
        k++;
    }
    if (ttl && dsc) {
        if (instlibs == NULL) {
            instlibs = calloc(1, sizeof(InstLibs));
            lib = instlibs;
        } else {
            lib = calloc(1, sizeof(InstLibs));
            if (ascii_ic_cmp(instlibs->name, fnm) > 0) {
                lib->next = instlibs;
                instlibs = lib;
            } else {
                ptr = instlibs;
                prev = NULL;
                while (ptr && ascii_ic_cmp(fnm, ptr->name) > 0) {
                    prev = ptr;
                    ptr = ptr->next;
                }
                if (prev)
                    prev->next = lib;
                lib->next = ptr;
            }
        }
        lib->name = calloc(strlen(fnm) + 1, sizeof(char));
        strcpy(lib->name, fnm);
        lib->title = calloc(strlen(ttl) + 1, sizeof(char));
        strcpy(lib->title, ttl);
        lib->descr = calloc(strlen(dsc) + 1 - z, sizeof(char));
        lib->si = 1;
        m = 0;
        n = 0;
        while (dsc[m] != 0) {
            while (dsc[m] == ' ' && dsc[m + 1] == ' ')
                m++;
            lib->descr[n] = dsc[m];
            m++;
            n++;
        }
        fix_single_quote(lib->title);
        fix_single_quote(lib->descr);
    } else {
        if (ttl)
            fprintf(stderr, "Failed to get Description from %s. ", fnm);
        else
            fprintf(stderr, "Failed to get Title from %s. ", fnm);
        fflush(stderr);
    }
}

void update_inst_libs(void) {
    Log("update_inst_libs()");
    DIR *d;
    struct dirent *dir;
    char fname[512];
    char *descr;
    InstLibs *il;
    int r;
    int n = 0;

    LibPath *lp = libpaths;
    while (lp) {
        d = opendir(lp->path);
        if (d) {
            while ((dir = readdir(d)) != NULL) {
#ifdef _DIRENT_HAVE_D_TYPE
                if (dir->d_name[0] != '.' && dir->d_type == DT_DIR) {
#else
                if (dir->d_name[0] != '.') {
#endif
                    il = instlibs;
                    r = 0;
                    while (il) {
                        if (strcmp(il->name, dir->d_name) == 0) {
                            il->si = 1;
                            r = 1; // Repeated library
                            break;
                        }
                        il = il->next;
                    }
                    if (r)
                        continue;
                    snprintf(fname, 511, "%s/%s/DESCRIPTION", lp->path,
                             dir->d_name);
                    descr = read_file(fname, 1);
                    if (descr) {
                        n++;
                        parse_descr(descr, dir->d_name);
                        free(descr);
                    }
                }
            }
            closedir(d);
        }
        lp = lp->next;
    }

    // New libraries found. Overwrite ~/.cache/Nvim-R/inst_libs
    if (n) {
        char fname[1032];
        snprintf(fname, 1031, "%s/inst_libs", compldir);
        FILE *f = fopen(fname, "w");
        if (f == NULL) {
            fprintf(stderr, "Could not write to '%s'\n", fname);
            fflush(stderr);
        } else {
            il = instlibs;
            while (il) {
                if (il->si)
                    fprintf(f, "%s\006%s\006%s\n", il->name, il->title,
                            il->descr);
                il = il->next;
            }
            fclose(f);
        }
    }
}

static void read_args(void) {
    if (more_to_build) {
        has_args_to_read = 1;
        return;
    }

    char buf[1024];
    PkgData *pkg = pkgList;
    char *p;

    pkg = pkgList;
    while (pkg) {
        if (!pkg->args) {
            snprintf(buf, 1023, "%s/args_%s_%s", compldir, pkg->name,
                     pkg->version);
            pkg->args = read_file(buf, 0);
            if (pkg->args) {
                p = pkg->args;
                while (*p) {
                    if (*p == '\006')
                        *p = 0;
                    p++;
                }
            }
        }
        pkg = pkg->next;
    }
    has_args_to_read = 0;
}

// Read the list of libraries loaded in R, and run another R instance to build
// the omnils_ and fun_ files in compldir.
static void build_omnils(void) {
    Log("build_omnils()");
    unsigned long nsz;

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
    p = str_cat(p, "library('nvimcom')\np <- c(");
    int k = 0;
    while (pkg) {
        if (pkg->to_build == 0) {
            nsz = strlen(pkg->name) + 1024 + (p - compl_buffer);
            if (compl_buffer_size < nsz)
                p = grow_buffer(&compl_buffer, &compl_buffer_size,
                                nsz - compl_buffer_size);
            if (k == 0)
                snprintf(buf, 63, "'%s'", pkg->name);
            else
                snprintf(buf, 63, ",\n  '%s'", pkg->name);
            p = str_cat(p, buf);
            pkg->to_build = 1;
            k++;
        }
        pkg = pkg->next;
    }

    if (k) {
        // Build all the omnils_ files before beginning to build the args_
        // files because: 1. It's about three times faster to build the
        // omnils_ than the args_. 2. During omni completion, omnils_ is used
        // more frequently. 3. The Object Browser only needs the omnils_.

        n_omnils_build++;
        p = str_cat(p, ")\nnvimcom:::nvim.buildomnils(p)\n");
        run_R_code(compl_buffer, 1);
        finish_bol();
    }
    building_omnils = 0;

    // If this function was called while it was running, build the remaining
    // cache files before saving the list of libraries whose cache files were
    // built.
    if (more_to_build) {
        more_to_build = 0;
        build_omnils();
    }

    // Delete args_lock if it's too old
    snprintf(buf, 1023, "%s/args_lock", compldir);
    struct stat filestat;
    if ((stat(buf, &filestat) == 0)) {
        time_t t = time(&t);
        t = t -
            filestat.st_mtime; // st_mtime is a macro defined as st_mtim.tv_sec;
        if (t < 3600)
            return;
        unlink(buf);
    }

    if (has_args_to_read)
        read_args();
}

// Called asynchronously and only if an omnils_ file was actually built.
static void finish_bol() {
    Log("finish_bol()");

    char buf[1024];

    // Don't check the return value of run_R_code because some packages might
    // have been successfully built before R exiting with status > 0.

    // Check if all files were really built before trying to load them.
    PkgData *pkg = pkgList;
    while (pkg) {
        if (pkg->built == 0 && access(pkg->fname, F_OK) == 0)
            pkg->built = 1;
        if (pkg->built && !pkg->omnils)
            load_pkg_data(pkg);
        pkg = pkg->next;
    }

    // Finally create a list of built omnils_ because libnames_ might have
    // already changed and Nvim-R would try to read omnils_ files not built yet.
    snprintf(buf, 511, "%s/libs_in_nrs_%s", localtmpdir, getenv("NVIMR_ID"));
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

// Read the DESCRIPTION of all installed libraries
char *complete_instlibs(char *p, const char *base) {
    update_inst_libs();

    if (!instlibs)
        return p;

    unsigned long len;
    InstLibs *il;

    il = instlibs;
    while (il) {
        len = strlen(il->descr) + (p - compl_buffer) + 1024;
        if (compl_buffer_size < len)
            p = grow_buffer(&compl_buffer, &compl_buffer_size,
                            len - compl_buffer_size);

        if (str_here(il->name, base) && il->si) {
            p = str_cat(p, "{'word': '");
            p = str_cat(p, il->name);
            p = str_cat(p, "', 'menu': '[pkg]', 'user_data': {'ttl': '");
            p = str_cat(p, il->title);
            p = str_cat(p, "', 'descr': '");
            p = str_cat(p, il->descr);
            p = str_cat(p, "', 'cls': 'l'}},");
        }
        il = il->next;
    }

    return p;
}

void update_pkg_list(char *libnms) {
    Log("update_pkg_list()");
    char buf[512];
    char *s, *nm, *vrsn;
    PkgData *pkg;

    // Consider that all packages were unloaded
    pkg = pkgList;
    while (pkg) {
        pkg->loaded = 0;
        pkg = pkg->next;
    }

    if (libnms) {
        // called by nvimcom
        Log("update_pkg_list != NULL");
        while (*libnms) {
            nm = libnms;
            while (*libnms != '\003')
                libnms++;
            *libnms = 0;
            libnms++;
            vrsn = libnms;
            while (*libnms != '\004')
                libnms++;
            *libnms = 0;
            libnms++;
            if (*libnms == '\n') // this was the last package
                libnms++;

            if (strstr(nm, " ") || strstr(vrsn, " ")) {
                break;
            }

            pkg = get_pkg(nm);
            if (pkg)
                pkg->loaded = 1;
            else
                add_pkg(nm, vrsn);
        }
    } else {
        // Called during the initialization with libnames_ created by
        // R/before_nrs.R to highlight function from the `library()` and
        // `require()` commands present in the file being edited.
        char lbnm[128];
        Log("update_pkg_list == NULL");

        snprintf(buf, 511, "%s/libnames_%s", tmpdir, getenv("NVIMR_ID"));
        FILE *flib = fopen(buf, "r");
        if (!flib) {
            fprintf(stderr, "Failed to open \"%s\"\n", buf);
            fflush(stderr);
            return;
        }

        while ((s = fgets(lbnm, 127, flib))) {
            while (*s != '_')
                s++;
            *s = 0;
            s++;
            vrsn = s;
            while (*s != '\n')
                s++;
            *s = 0;

            pkg = get_pkg(lbnm);
            if (pkg)
                pkg->loaded = 1;
            else
                add_pkg(lbnm, vrsn);
        }
        fclose(flib);
    }

    // No command run yet
    if (!pkgList)
        return;

    // Delete data from unloaded packages to ensure that reloaded packages go
    // to the bottom of the Object Browser list
    pkg = pkgList;
    if (pkg->loaded == 0) {
        pkgList = pkg->next;
        pkg_delete(pkg);
    } else {
        PkgData *prev = pkg;
        pkg = pkg->next;
        while (pkg) {
            if (pkg->loaded == 0) {
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

int get_list_status(const char *s, int stt) {
    if (listTree) {
        ListStatus *p = search(s);
        if (p)
            return p->status;
        insert(listTree, s, stt);
        return stt;
    }
    listTree = new_ListStatus(s, stt);
    return stt;
}

void toggle_list_status(const char *s) {
    ListStatus *p = search(s);
    if (p)
        p->status = !p->status;
}

static const char *write_ob_line(const char *p, const char *bs, char *prfx,
                                 int closeddf, FILE *fl) {
    char base1[128];
    char base2[128];
    char prefix[128];
    char newprfx[96];
    char nm[160];
    char descr[160];
    const char *f[7];
    const char *s;    // Diagnostic pointer
    const char *bsnm; // Name of object including its parent list, data.frame or
                      // S4 object
    int df;           // Is data.frame? If yes, start open unless closeddf = 1
    int i;
    int ne;

    nLibObjs--;

    bsnm = p;
    p += strlen(bs);

    i = 0;
    while (i < 7) {
        f[i] = p;
        i++;
        while (*p != 0)
            p++;
        p++;
    }
    while (*p != '\n' && *p != 0)
        p++;
    if (*p == '\n')
        p++;

    if (closeddf)
        df = 0;
    else if (f[1][0] == '$')
        df = OpenDF;
    else
        df = OpenLS;

    // Replace \x13 with single quote
    i = 0;
    s = f[0];
    while (s[i] && i < 159) {
        if (s[i] == '\x13')
            nm[i] = '\'';
        else
            nm[i] = s[i];
        i++;
    }
    nm[i] = 0;

    // Replace \x13 with single quote
    if (f[1][0] == '\003')
        s = f[5];
    else
        s = f[6];
    if (s[0] == 0) {
        descr[0] = 0;
    } else {
        i = 0;
        while (s[i] && i < 159) {
            if (s[i] == '\x13')
                descr[i] = '\'';
            else
                descr[i] = s[i];
            i++;
        }
        descr[i] = 0;
    }

    if (!(bsnm[0] == '.' && allnames == 0)) {
        if (f[1][0] == '\003')
            fprintf(fl, "   %s(#%s\t%s\n", prfx, nm, descr);
        else
            fprintf(fl, "   %s%c#%s\t%s\n", prfx, f[1][0], nm, descr);
    }

    if (*p == 0)
        return p;

    if (f[1][0] == '[' || f[1][0] == '$' || f[1][0] == '<' || f[1][0] == ':') {
        s = f[6];
        s++;
        s++;
        s++; // Number of elements (list)
        if (f[1][0] == '$') {
            while (*s && *s != ' ')
                s++;
            s++; // Number of columns (data.frame)
        }
        ne = atoi(s);
        if (f[1][0] == '[' || f[1][0] == '$' || f[1][0] == ':') {
            snprintf(base1, 127, "%s$", bsnm);  // Named list
            snprintf(base2, 127, "%s[[", bsnm); // Unnamed list
        } else {
            snprintf(base1, 127, "%s@", bsnm); // S4 object
            snprintf(
                base2, 127, "%s[[",
                bsnm); // S4 object always have names but base2 must be defined
        }

        if (get_list_status(bsnm, df) == 0) {
            while (str_here(p, base1) || str_here(p, base2)) {
                while (*p != '\n')
                    p++;
                p++;
                nLibObjs--;
            }
            return p;
        }

        if (str_here(p, base1) == 0 && str_here(p, base2) == 0)
            return p;

        int len = strlen(prfx);
        if (nvimcom_is_utf8) {
            int j = 0, i = 0;
            while (i < len) {
                if (prfx[i] == '\xe2') {
                    i += 3;
                    if (prfx[i - 1] == '\x80' || prfx[i - 1] == '\x94') {
                        newprfx[j] = ' ';
                        j++;
                    } else {
                        newprfx[j] = '\xe2';
                        j++;
                        newprfx[j] = '\x94';
                        j++;
                        newprfx[j] = '\x82';
                        j++;
                    }
                } else {
                    newprfx[j] = prfx[i];
                    i++, j++;
                }
            }
            newprfx[j] = 0;
        } else {
            for (int i = 0; i < len; i++) {
                if (prfx[i] == '-' || prfx[i] == '`')
                    newprfx[i] = ' ';
                else
                    newprfx[i] = prfx[i];
            }
            newprfx[len] = 0;
        }

        // Check if the next list element really is there
        while (str_here(p, base1) || str_here(p, base2)) {
            // Check if this is the last element in the list
            s = p;
            while (*s != '\n')
                s++;
            s++;
            ne--;
            if (ne == 0) {
                snprintf(prefix, 112, "%s%s", newprfx, strL);
            } else {
                if (str_here(s, base1) || str_here(s, base2))
                    snprintf(prefix, 112, "%s%s", newprfx, strT);
                else
                    snprintf(prefix, 112, "%s%s", newprfx, strL);
            }

            if (*p) {
                if (str_here(p, base1))
                    p = write_ob_line(p, base1, prefix, 0, fl);
                else
                    p = write_ob_line(p, bsnm, prefix, 0, fl);
            }
        }
    }
    return p;
}

void hi_glbenv_fun(void) {
    char *g = glbnv_buffer;
    char *p = compl_buffer;
    char *s;

    memset(compl_buffer, 0, compl_buffer_size);
    p = str_cat(p, "call UpdateLocalFunctions('");
    while (*g) {
        s = g;
        while (*s != 0)
            s++;
        s++;
        if (*s == '\003') {
            p = str_cat(p, g);
            p = str_cat(p, " ");
        }
        while (*g != '\n')
            g++;
        g++;
    }
    p = str_cat(p, "')");
    printf("\x11%" PRI_SIZET "\x11%s\n", strlen(compl_buffer), compl_buffer);
    fflush(stdout);
}

void update_glblenv_buffer(char *g) {
    Log("update_glblenv_buffer()");
    int n = 0;
    int max;
    int glbnv_size;

    if (glbnv_buffer) {
        if (strlen(g) > glbnv_buffer_sz) {
            free(glbnv_buffer);
            glbnv_buffer_sz = strlen(g) + 4096;
            glbnv_buffer = malloc(glbnv_buffer_sz * sizeof(char));
        }
    } else {
        glbnv_buffer_sz = strlen(g) + 4096;
        glbnv_buffer = malloc(glbnv_buffer_sz * sizeof(char));
    }
    strcpy(glbnv_buffer, g);
    if (check_omils_buffer(glbnv_buffer, &glbnv_size) == NULL)
        return;

    max = glbnv_size - 5;

    for (int i = 0; i < max; i++)
        if (glbnv_buffer[i] == '\003') {
            n++;
            i += 7;
        }

    if (n != nGlbEnvFun) {
        nGlbEnvFun = n;
        hi_glbenv_fun();
    }
}

void omni2ob(void) {
    Log("omni2ob()");
    FILE *f = fopen(globenv, "w");
    if (!f) {
        fprintf(stderr, "Error opening \"%s\" for writing\n", globenv);
        fflush(stderr);
        return;
    }

    fprintf(f, ".GlobalEnv | Libraries\n\n");

    if (glbnv_buffer) {
        const char *s = glbnv_buffer;
        while (*s)
            s = write_ob_line(s, "", "", 0, f);
    }

    fclose(f);
    if (auto_obbr) {
        fputs("call UpdateOB('GlobalEnv')\n", stdout);
        fflush(stdout);
    }
}

void lib2ob(void) {
    Log("lib2ob()");
    FILE *f = fopen(liblist, "w");
    if (!f) {
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
    while (pkg) {
        if (pkg->loaded) {
            if (pkg->descr)
                fprintf(f, "   :#%s\t%s\n", pkg->name, pkg->descr);
            else
                fprintf(f, "   :#%s\t\n", pkg->name);
            snprintf(lbnmc, 511, "%s:", pkg->name);
            stt = get_list_status(lbnmc, 0);
            if (pkg->omnils && pkg->nobjs > 0 && stt == 1) {
                p = pkg->omnils;
                nLibObjs = pkg->nobjs - 1;
                while (*p) {
                    if (nLibObjs == 0)
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

void change_all(ListStatus *root, int stt) {
    if (root != NULL) {
        // Open all but libraries
        if (!(stt == 1 && root->key[strlen(root->key) - 1] == ':'))
            root->status = stt;
        change_all(root->left, stt);
        change_all(root->right, stt);
    }
}

void print_listTree(ListStatus *root, FILE *f) {
    if (root != NULL) {
        fprintf(f, "%d :: %s\n", root->status, root->key);
        print_listTree(root->left, f);
        print_listTree(root->right, f);
    }
}

static void fill_inst_libs(void) {
    InstLibs *il = NULL;
    char fname[1032];
    snprintf(fname, 1031, "%s/inst_libs", compldir);
    char *b = read_file(fname, 0);
    if (!b)
        return;
    char *s = b;
    char *n, *t, *d;
    while (*s) {
        n = s;
        t = NULL;
        d = NULL;
        while (*s && *s != '\006')
            s++;
        if (*s && *s == '\006') {
            *s = 0;
            s++;
            if (*s) {
                t = s;
                while (*s && *s != '\006')
                    s++;
                if (*s && *s == '\006') {
                    *s = 0;
                    s++;
                    if (*s) {
                        d = s;
                        while (*s && *s != '\n')
                            s++;
                        if (*s && *s == '\n') {
                            *s = 0;
                            s++;
                        } else
                            break;
                    } else
                        break;
                } else
                    break;
            }
            if (d) {
                if (il) {
                    il->next = calloc(1, sizeof(InstLibs));
                    il = il->next;
                } else {
                    il = calloc(1, sizeof(InstLibs));
                }
                if (instlibs == NULL)
                    instlibs = il;
                il->name = malloc((strlen(n) + 1) * sizeof(char));
                strcpy(il->name, n);
                il->title = malloc((strlen(t) + 1) * sizeof(char));
                strcpy(il->title, t);
                il->descr = malloc((strlen(d) + 1) * sizeof(char));
                strcpy(il->descr, d);
            }
        }
    }
    free(b);
}

static void send_nrs_info(void) {
    printf("call EchoNCSInfo('Loaded packages:");
    PkgData *pkg = pkgList;
    while (pkg) {
        printf(" %s", pkg->name);
        pkg = pkg->next;
    }
    printf("')\n");
    fflush(stdout);
}

static void init(void) {
#ifdef Debug_NRS
    time_t t;
    time(&t);
    FILE *f = fopen("/dev/shm/nvimrserver_log", "w");
    fprintf(f, "NSERVER LOG | %s\n\n", ctime(&t));
    fclose(f);
#endif

    char envstr[1024];

    envstr[0] = 0;
    if (getenv("LC_MESSAGES"))
        strcat(envstr, getenv("LC_MESSAGES"));
    if (getenv("LC_ALL"))
        strcat(envstr, getenv("LC_ALL"));
    if (getenv("LANG"))
        strcat(envstr, getenv("LANG"));
    int len = strlen(envstr);
    for (int i = 0; i < len; i++)
        envstr[i] = toupper(envstr[i]);
    if (strstr(envstr, "UTF-8") != NULL || strstr(envstr, "UTF8") != NULL) {
        nvimcom_is_utf8 = 1;
        strcpy(strL, "\xe2\x94\x94\xe2\x94\x80 ");
        strcpy(strT, "\xe2\x94\x9c\xe2\x94\x80 ");
    } else {
        nvimcom_is_utf8 = 0;
        strcpy(strL, "`- ");
        strcpy(strT, "|- ");
    }

    if (!getenv("NVIMR_SECRET")) {
        fprintf(stderr, "NVIMR_SECRET not found\n");
        fflush(stderr);
        exit(1);
    }
    strncpy(VimSecret, getenv("NVIMR_SECRET"), 127);
    VimSecretLen = strlen(VimSecret);

    strncpy(compl_cb, getenv("NVIMR_COMPLCB"), 63);
    strncpy(compl_info, getenv("NVIMR_COMPLInfo"), 63);
    strncpy(compldir, getenv("NVIMR_COMPLDIR"), 255);
    strncpy(tmpdir, getenv("NVIMR_TMPDIR"), 255);
    if (getenv("NVIMR_LOCAL_TMPDIR")) {
        strncpy(localtmpdir, getenv("NVIMR_LOCAL_TMPDIR"), 255);
    } else {
        strncpy(localtmpdir, getenv("NVIMR_TMPDIR"), 255);
    }

    snprintf(liblist, 575, "%s/liblist_%s", localtmpdir, getenv("NVIMR_ID"));
    snprintf(globenv, 575, "%s/globenv_%s", localtmpdir, getenv("NVIMR_ID"));

    if (getenv("NVIMR_OPENDF"))
        OpenDF = 1;
    else
        OpenDF = 0;
    if (getenv("NVIMR_OPENLS"))
        OpenLS = 1;
    else
        OpenLS = 0;
    if (getenv("NVIMR_OBJBR_ALLNAMES"))
        allnames = 1;
    else
        allnames = 0;

    // Fill immediately the list of installed libraries. Each entry still has
    // to be confirmed by listing the directories in .libPaths.
    fill_inst_libs();

    // List tree sentinel
    listTree = new_ListStatus("base:", 0);

    compl_buffer = calloc(compl_buffer_size, sizeof(char));

    char fname[512];
    snprintf(fname, 511, "%s/libPaths", tmpdir);
    char *b = read_file(fname, 1);
#ifdef WIN32
    for (int i = 0; i < strlen(b); i++)
        if (b[i] == '\\')
            b[i] = '/';
#endif
    if (b) {
        libpaths = calloc(1, sizeof(LibPath));
        libpaths->path = b;
        LibPath *p = libpaths;
        while (*b) {
            if (*b == '\n') {
                while (*b == '\n' || *b == '\r') {
                    *b = 0;
                    b++;
                }
                if (*b) {
                    p->next = calloc(1, sizeof(LibPath));
                    p = p->next;
                    p->path = b;
                } else {
                    break;
                }
            }
            b++;
        }
    }
    update_inst_libs();
    update_pkg_list(NULL);
    build_omnils();

    printf("let g:rplugin.nrs_running = 1\n");
    fflush(stdout);

    Log("init() finished");
}

int count_twice(const char *b1, const char *b2, const char ch) {
    int n1 = 0;
    int n2 = 0;
    for (unsigned long i = 0; i < strlen(b1); i++)
        if (b1[i] == ch)
            n1++;
    for (unsigned long i = 0; i < strlen(b2); i++)
        if (b2[i] == ch)
            n2++;
    return n1 == n2;
}

// Return user_data of a specific item with function usage, title and
// description to be displayed in the float window
void completion_info(const char *wrd, const char *pkg) {
    int i;
    unsigned long nsz;
    const char *f[7];
    char *s;

    if (strcmp(pkg, ".GlobalEnv") == 0) {
        s = glbnv_buffer;
    } else {
        PkgData *pd = pkgList;
        while (pd) {
            if (strcmp(pkg, pd->name) == 0)
                break;
            else
                pd = pd->next;
        }

        if (pd == NULL)
            return;

        s = pd->omnils;
    }

    memset(compl_buffer, 0, compl_buffer_size);
    char *p = compl_buffer;

    while (*s != 0) {
        if (strcmp(s, wrd) == 0) {
            i = 0;
            while (i < 7) {
                f[i] = s;
                i++;
                while (*s != 0)
                    s++;
                s++;
            }
            while (*s != '\n' && *s != 0)
                s++;
            if (*s == '\n')
                s++;

            if (f[1][0] == '\003' && str_here(f[4], "[\x12not_checked\x12]")) {
                snprintf(compl_buffer, 1024,
                         "E%snvimcom:::nvim.GlobalEnv.fun.args(\"%s\")\n",
                         getenv("NVIMR_ID"), wrd);
                send_to_nvimcom(compl_buffer);
                return;
            }

            // Avoid buffer overflow if the information is bigger than
            // compl_buffer.
            nsz = strlen(f[4]) + strlen(f[5]) + strlen(f[6]) + 1024 +
                  (p - compl_buffer);
            if (compl_buffer_size < nsz)
                p = grow_buffer(&compl_buffer, &compl_buffer_size,
                                nsz - compl_buffer_size);

            p = str_cat(p, "{'cls': '");
            if (f[1][0] == '\003')
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
            printf("call %s(%s)\n", compl_info, compl_buffer);
            fflush(stdout);
            return;
        }
        while (*s != '\n')
            s++;
        s++;
    }
    printf("call %s({})\n", compl_info);
    fflush(stdout);
}

// Return the menu items for omni completion, but don't include function
// usage, and tittle and description of objects because if the buffer becomes
// too big it will be truncated.
char *parse_omnils(const char *s, const char *base, const char *pkg, char *p) {
    int i;
    unsigned long nsz;
    const char *f[7];

    while (*s != 0) {
        if (str_here(s, base)) {
            i = 0;
            while (i < 7) {
                f[i] = s;
                i++;
                while (*s != 0)
                    s++;
                s++;
            }
            while (*s != '\n' && *s != 0)
                s++;
            if (*s == '\n')
                s++;

            // Skip elements of lists unless the user is really looking for
            // them, and skip lists if the user is looking for one of its
            // elements.
            if (!count_twice(base, f[0], '@'))
                continue;
            if (!count_twice(base, f[0], '$'))
                continue;
            if (!count_twice(base, f[0], '['))
                continue;

            // Avoid buffer overflow if the information is bigger than
            // compl_buffer.
            nsz = strlen(f[0]) + 1024 + (p - compl_buffer);
            if (compl_buffer_size < nsz)
                p = grow_buffer(&compl_buffer, &compl_buffer_size,
                                nsz - compl_buffer_size);

            p = str_cat(p, "{'word': '");
            if (pkg) {
                p = str_cat(p, pkg);
                p = str_cat(p, "::");
            }
            p = str_cat(p, f[0]);
            p = str_cat(p, "', 'menu': '");
            if (f[2][0] != 0) {
                p = str_cat(p, f[2]);
            } else {
                switch (f[1][0]) {
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
            if (f[1][0] == '\003')
                p = str_cat(p, "f");
            else
                p = str_cat(p, f[1]);
            p = str_cat(p, "', 'pkg': '");
            p = str_cat(p, f[3]);
            p = str_cat(p, "'}}, "); // Don't include fields 4, 5 and 6 because
                                     // big data will be truncated.
        } else {
            while (*s != '\n')
                s++;
            s++;
        }
    }
    return p;
}

void resolve_arg_item(char *pkg, char *fnm, char *itm) {
    char item[128];
    snprintf(item, 127, "%s\005", itm);
    PkgData *p = pkgList;
    while (p) {
        if (strcmp(p->name, pkg) == 0) {
            if (p->args) {
                char *s = p->args;
                while (*s) {
                    if (strcmp(s, fnm) == 0) {
                        while (*s)
                            s++;
                        s++;
                        while (*s != '\n') {
                            if (str_here(s, item)) {
                                while (*s && *s != '\005')
                                    s++;
                                s++;
                                printf("call "
                                       "v:lua.require'cmp_nvim_r'.finish_get_"
                                       "args('%s')\n",
                                       s);
                                fflush(stdout);
                            }
                            s++;
                        }
                        return;
                    } else {
                        while (*s != '\n')
                            s++;
                        s++;
                    }
                }
            }
            break;
        }
        p = p->next;
    }
}

char *complete_args(char *p, char *funcnm) {
    // Check if function is "pkg::fun"
    char *pkg = NULL;
    if (strstr(funcnm, "::")) {
        pkg = funcnm;
        funcnm = strstr(funcnm, "::");
        *funcnm = 0;
        funcnm++;
        funcnm++;
    }

    PkgData *pd = pkgList;
    char *s;
    while (pd) {
        if (pd->omnils &&
            (pkg == NULL || (pkg && strcmp(pd->name, pkg) == 0))) {
            s = pd->omnils;
            while (*s != 0) {
                if (strcmp(s, funcnm) == 0) {
                    int i = 4;
                    while (i) {
                        s++;
                        if (*s == 0)
                            i--;
                    }
                    s++;
                    p = str_cat(p, "{'pkg': '");
                    p = str_cat(p, pd->name);
                    p = str_cat(p, "', 'fnm': '");
                    p = str_cat(p, funcnm);
                    p = str_cat(p, "', 'args': [");
                    p = str_cat(p, s);
                    p = str_cat(p, "]},");
                    break;
                } else {
                    while (*s != '\n')
                        s++;
                    s++;
                }
            }
        }
        pd = pd->next;
    }
    return p;
}

void complete(const char *id, char *base, char *funcnm, char *args) {
    if (args)
        Log("complete(%s, %s, %s, [%c%c%c%c...])", id, base, funcnm, args[0],
            args[1], args[2], args[3]);
    else
        Log("complete(%s, %s, %s, NULL)", id, base, funcnm);
    char *p;

    memset(compl_buffer, 0, compl_buffer_size);
    p = compl_buffer;

    // Complete function arguments
    if (funcnm) {
        if (*funcnm == '\004') {
            // Get menu completion for installed libraries
            p = complete_instlibs(p, base);
            printf("\x11%" PRI_SIZET "\x11"
                   "call %s(%s, [%s])\n",
                   strlen(compl_cb) + strlen(id) + strlen(compl_buffer) + 11,
                   compl_cb, id, compl_buffer);
            fflush(stdout);
            return;
        } else {
            // Normal completion of arguments
            if (r_conn == 0) {
                p = complete_args(p, funcnm);
            } else {
                if ((strlen(args) + 1024) > compl_buffer_size)
                    p = grow_buffer(&compl_buffer, &compl_buffer_size,
                                    strlen(args) + 1024 - compl_buffer_size);

                char *s = args;
                while (*s) {
                    if (*s == '\x12')
                        *s = '\'';
                    s++;
                }
                p = str_cat(p, args);
            }
        }
        if (base[0] == 0) {
            // base will be empty if completing only function arguments
            printf("\x11%" PRI_SIZET "\x11"
                   "call %s(%s, [%s])\n",
                   strlen(compl_cb) + strlen(id) + strlen(compl_buffer) + 11,
                   compl_cb, id, compl_buffer);
            fflush(stdout);
            return;
        }
    }

    // Finish filling the compl_buffer
    if (glbnv_buffer)
        p = parse_omnils(glbnv_buffer, base, NULL, p);
    PkgData *pd = pkgList;

    // Check if base is "pkg::fun"
    char *pkg = NULL;
    if (strstr(base, "::")) {
        pkg = base;
        base = strstr(base, "::");
        *base = 0;
        base++;
        base++;
    }

    while (pd) {
        if (pd->omnils && (pkg == NULL || (pkg && strcmp(pd->name, pkg) == 0)))
            p = parse_omnils(pd->omnils, base, pkg, p);
        pd = pd->next;
    }

    printf("\x11%" PRI_SIZET "\x11"
           "call %s(%s, [%s])\n",
           strlen(compl_cb) + strlen(id) + strlen(compl_buffer) + 11, compl_cb,
           id, compl_buffer);
    fflush(stdout);
}

void stdin_loop() {
    char line[1024];
    FILE *f;
    char *msg;
    char t;
    memset(line, 0, 1024);

    while (fgets(line, 1023, stdin)) {

        for (unsigned int i = 0; i < strlen(line); i++)
            if (line[i] == '\n' || line[i] == '\r')
                line[i] = 0;
        Log("stdin:   %s", line);
        msg = line;
        switch (*msg) {
        case '1': // Start server and wait nvimcom connection
            start_server();
            Log("server started");
            break;
        case '2': // Send message
            msg++;
            send_to_nvimcom(msg);
            break;
        case '3':
            msg++;
            switch (*msg) {
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
                if (t == 'G')
                    omni2ob();
                else
                    lib2ob();
                break;
            case '4': // Close/Open all
                msg++;
                if (*msg == 'O')
                    change_all(listTree, 1);
                else
                    change_all(listTree, 0);
                msg++;
                if (*msg == 'G')
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
        case '4': // Miscellaneous commands
            msg++;
            switch (*msg) {
            case '1':
                read_args();
                break;
            case '2':
                send_nrs_info();
                break;
            case '3':
                update_glblenv_buffer("");
                if (auto_obbr)
                    omni2ob();
                break;
            }
            break;
        case '5':
            msg++;
            char *id = msg;
            while (*msg != '\003')
                msg++;
            *msg = 0;
            msg++;
            if (*msg == '\004') {
                msg++;
                complete(id, msg, "\004", NULL);
            } else if (*msg == '\005') {
                msg++;
                char *base = msg;
                while (*msg != '\005')
                    msg++;
                *msg = 0;
                msg++;
                complete(id, base, msg, NULL);
            } else {
                complete(id, msg, NULL, NULL);
            }
            break;
        case '6':
            msg++;
            char *wrd = msg;
            while (*msg != '\002')
                msg++;
            *msg = 0;
            msg++;
            if (strstr(wrd, "::"))
                wrd = strstr(wrd, "::") + 2;
            completion_info(wrd, msg);
            break;
        case '7':
            msg++;
            char *p = msg;
            while (*msg != '\002')
                msg++;
            *msg = 0;
            msg++;
            char *f = msg;
            while (*msg != '\002')
                msg++;
            *msg = 0;
            msg++;
            resolve_arg_item(p, f, msg);
            break;
#ifdef WIN32
        case '8':
            // Messages related with the Rgui on Windows
            msg++;
            switch (*msg) {
            case '1': // Check if R is running
                if (PostMessage(RConsole, WM_NULL, 0, 0)) {
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
                if (NvimHwnd)
                    SetForegroundWindow(NvimHwnd);
                break;
            }
            break;
#endif
        case '9': // Quit now
            exit(0);
            break;
        default:
            fprintf(stderr, "Unknown command received: [%d] %s\n", line[0],
                    msg);
            fflush(stderr);
            break;
        }
        memset(line, 0, 1024);
    }
}

int main(int argc, char **argv) {
    init();
#ifdef WIN32
    Windows_setup();
#endif
    stdin_loop();
    return 0;
}
