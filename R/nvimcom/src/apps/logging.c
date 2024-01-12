#include "logging.h"
#include <stdarg.h> // For va_list
#include <stdio.h>  // For vfprintf

/**
 * @brief Logs a formatted message to a specified log file.
 *
 * This function writes a formatted message to a log file located at
 * "/dev/shm/nvimrserver_log". It behaves similarly to printf, formatting the
 * provided message and appending it to the log file. This function is active
 * only when Debug_NRS is defined.
 *
 * @param fmt Format string for the log message (printf-style).
 * @param ... Variable arguments providing data to format.
 *
 * @note This function is conditionally compiled only if Debug_NRS is defined.
 *       If Debug_NRS is not defined, calls to this function are effectively
 * no-ops.
 */

__attribute__((format(printf, 1, 2))) void Log(const char *fmt, ...) {
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
