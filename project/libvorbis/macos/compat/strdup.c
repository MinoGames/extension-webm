#include <ogg/os_types.h>
#include <sys/types.h>
#include <string.h>
#include <stdlib.h>

char *strdup(const char *inStr)
{
        char *outStr = NULL;
        
        if (inStr == NULL) {
                return NULL;
        }
        
        outStr = _ogg_malloc(strnlen(inStr,512) + 1);
        
        if (outStr != NULL) {
                strncpy(outStr, inStr,512);
        }
        
        return outStr;
}
