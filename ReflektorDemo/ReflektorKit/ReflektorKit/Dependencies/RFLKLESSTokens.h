//
// RFLKLESSToken.h
// Tests
// Forked from https://github.com/tracy-e/ESCssParser
//
//

#include <stdio.h>

typedef enum {
    CHARSET_SYM,          //@charset
    IMPORT_SYM,           //@import
    PAGE_SYM,             //@page
    MEDIA_SYM,            //@media
    FONT_FACE_SYM,        //@font-face
    NAMESPACE_SYM,        //@namespace
    IMPORTANT_SYM,        //!{w}important
    
    S,                    //{space}
    STRING,               //{string}
    IDENT,                //{ident}
    HASH,                 //#{name}
    CDO,                  //<!--
    CDC,                  //-->
    INCLUDES,             //~=
    DASHMATCH,            //!=
    
    EMS,                  //{num}em
    EXS,                  //{num}ex
    LENGTH,               //{num}px | cm | mm | in | pt | pc
    ANGLE,                //{num}deg | rad | grad
    TIME,                 //{num}ms | s
    FREQ,                 //{num}Hz | kHz
    DIMEN,                //{num}{ident}
    PERCENTAGE,           //{num}%
    NUMBER,               //{num}
    
    URI,                  //url()
    FUNCTION,             //{ident}(
    
    UNICODERANGE,         //U\+{range} | U\+{h}{1,6}-{h}{1,6}
    UNKNOWN               //.
} RFLKLESSToken;

extern const char* RFLKLESSTokenName[];

#ifndef YY_TYPEDEF_YY_SCANNER_T
#define YY_TYPEDEF_YY_SCANNER_T
typedef void* yyscan_t;
#endif

int RFLKLESSlex(void);
void RFLKLESS_parse(const char *buffer);
void RFLKLESS_scan(const char *text, int token);
