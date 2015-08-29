//
// LESSParser.h
// Tests
// Forked from https://github.com/tracy-e/ESCssParser
//
//

@import UIKit;

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
} LESSToken;

extern  const char* _Nullable  LESSTokenName[];

#ifndef YY_TYPEDEF_YY_SCANNER_T
#define YY_TYPEDEF_YY_SCANNER_T
typedef void* yyscan_t;
#endif

//utilities
 NSString * _Nonnull refl_uuid(void);
 NSString * _Nonnull refl_stripQuotesFromString(NSString * _Nonnull string);
BOOL refl_stringHasPrefix( NSString * _Nonnull string, NSArray * _Nonnull prefixes);
 NSArray * _Nonnull refl_prefixedOrderedKeys(NSArray * _Nonnull keys);
 NSString * _Nonnull refl_stringToCamelCase(NSString * _Nonnull string);
NSArray * _Nullable refl_getArgumentForValue( NSString* _Nonnull  stringValue);
__nullable id refl_parseKeyword(NSString * _Nonnull cssValue);
 NSString * _Nullable refl_bundlePath(NSString * _Nonnull file,  NSString * _Nonnull extension);

//lexer
int LESSlex(void);
void refl_parse(const char * _Nonnull buffer);
void refl_scan(const char * _Nullable text, int token);

@interface LESSParser : NSObject

- (NSDictionary* _Nullable )parseText:( NSString* _Nonnull )LESSText;

@end