#include <stdlib.h>
#include <string.h>
#include <windows.h>

static char Reply[256];

const char *SendToRConsole(char *aString){
#ifdef _WIN64
    HWND rcon = (HWND)atoll(getenv("RCONSOLE"));
#else
    HWND rcon = (HWND)atol(getenv("RCONSOLE"));
#endif

    if(!rcon){
        strcpy(Reply, "rcon is NULL");
        return Reply;
    }

    SetForegroundWindow(rcon);
    Sleep(0.05);

    // This is the most inefficient way of sending Ctrl+V. See:
    // http://stackoverflow.com/questions/27976500/postmessage-ctrlv-without-raising-the-window
    keybd_event(VK_CONTROL, 0, 0, 0);
    keybd_event(VkKeyScan('V'), 0, KEYEVENTF_EXTENDEDKEY | 0, 0);
    Sleep(0.05);
    keybd_event(VkKeyScan('V'), 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0);
    keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0);

    strcpy(Reply, "OK");
    return Reply;
}
