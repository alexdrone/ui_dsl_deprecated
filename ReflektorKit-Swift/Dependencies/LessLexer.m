//
// LESSParser.m
// Tests
// Forked from https://github.com/tracy-e/ESCssParser
//
//

#import "LessLexer.h"

#pragma mark - Utilities

NSString *refl_uuid()
{
    //Returns a UUID
    static const NSString *letters = @"1234567890abcdef";
    static const u_int32_t lenght = 16;
    
    NSMutableString *randomString = [NSMutableString stringWithCapacity:lenght];
    
    for (int i = 0; i < lenght; i++)
        [randomString appendFormat: @"%C", [letters characterAtIndex:(NSUInteger)arc4random_uniform((u_int32_t)letters.length)]];
    
    return randomString;
}

NSString *refl_stripQuotesFromString(NSString *string)
{
    NSString *result = string;
    
    //If the strings is wrapped with ' or "...
    if ([string characterAtIndex:0] == '\'' || [string characterAtIndex:0] == '\"')
        result = [string substringFromIndex:1];
    
    if ([result characterAtIndex:result.length-1] == '\'' || [result characterAtIndex:result.length-1] == '\"')
        result = [result substringToIndex:result.length-1];
    
    //returns a string without quotation marks
    return result;
}

BOOL refl_stringHasPrefix(NSString *string, NSArray *prefixes)
{
    BOOL match = NO;
    for (NSString *s in prefixes)
        match |= [string hasPrefix:s];
    
    return match;
}

NSArray *refl_prefixedOrderedKeys(NSArray *keys)
{
    NSMutableArray *vk = keys.mutableCopy;
    for (NSInteger i = 0; i < vk.count; i++) {
        for (NSInteger j = 0; j < vk.count; j++) {
            
            //move the item that is prefix of another at the bottom
            if (refl_stringHasPrefix(vk[i], @[vk[j]])) {
                NSString *v = vk[j];
                [vk removeObjectAtIndex:j];
                [vk insertObject:v atIndex:0];
            }
        }
    }
    
    return vk;
}

NSString *refl_stringToCamelCase(NSString *string)
{
    //Transform a string in dash notation (e.g. property-foo) into camel case notation
    //(e.g. propertyFoo)
    
    NSMutableString *output = [NSMutableString string];
    BOOL makeNextCharacterUpperCase = NO;
    for (NSInteger i = 0; i < string.length; i++) {
        
        unichar c = [string characterAtIndex:i];
        
        if (c == '-') {
            makeNextCharacterUpperCase = YES;
        } else if (makeNextCharacterUpperCase) {
            [output appendString:[[NSString stringWithCharacters:&c length:1] uppercaseString]];
            makeNextCharacterUpperCase = NO;
        } else {
            [output appendFormat:@"%C", c];
        }
    }
    return output;
}

NSArray *refl_getArgumentForValue(NSString* stringValue)
{
    NSCParameterAssert(stringValue);
    
    //Given a function-value string such as font('Arial', 12px) returns its
    //arguments (e.g. @['Arial', @12])
    
    NSUInteger argsStartIndex = 0;
    for (argsStartIndex = 0; argsStartIndex < stringValue.length; argsStartIndex++)
        if ([stringValue characterAtIndex:argsStartIndex] == '(')
            break;
    
    NSCAssert([stringValue characterAtIndex:stringValue.length-1] == ')', nil);
    stringValue = [stringValue substringFromIndex:argsStartIndex+1];
    stringValue = [stringValue substringToIndex:stringValue.length-1];
    
    //or ([^,]+\(.+?\))|([^,]+)
    NSArray *matches = [stringValue componentsSeparatedByString:@","];
    NSMutableArray *arguments = @[].mutableCopy;
    
    //note: it doesn't support recursively nested functions (just depth 1)
    for (NSInteger i = 0; i < matches.count; i++) {
        
        NSMutableString *match = [matches[i] mutableCopy];
        
        //is a nested function value
        NSInteger j = i+1;
        if ([match containsString:@"("])
            for (;j < matches.count; j++) {
                
                [match appendString:@","];
                
                //append the nested match
                NSString *nestedMatch = matches[j];
                
                //end of nested fuction
                if ([nestedMatch containsString:@")"]) {
                    [match appendString:nestedMatch];
                    i = j;
                    break;
                }
                
                [match appendString:nestedMatch];
            }
        
        [arguments addObject:match];
    }
    
    return arguments;
}

NSDictionary *refl_rhsKeywordsMap()
{
    static NSDictionary *__mapping;
    
    if (__mapping == nil) {
        __mapping = @{
                      
          //autoresizing masks
          @"none": @(0),
          @"flexible-left-margin": @(UIViewAutoresizingFlexibleLeftMargin),
          @"flexible-width": @(UIViewAutoresizingFlexibleWidth),
          @"flexible-right-margin": @(UIViewAutoresizingFlexibleRightMargin),
          @"flexible-top-margin": @(UIViewAutoresizingFlexibleTopMargin),
          @"flexible-height": @(UIViewAutoresizingFlexibleHeight),
          @"flexible-bottom-margin": @(UIViewAutoresizingFlexibleBottomMargin),
          
          //content mode
          @"mode-scale-to-fill": @(UIViewContentModeScaleToFill),
          @"mode-scale-aspect-fit": @(UIViewContentModeScaleAspectFit),
          @"mode-scale-aspect-fill": @(UIViewContentModeScaleAspectFill),
          @"mode-redraw": @(UIViewContentModeRedraw),
          @"mode-center": @(UIViewContentModeCenter),
          @"mode-top": @(UIViewContentModeTop),
          @"mode-bottom": @(UIViewContentModeBottom),
          @"mode-left": @(UIViewContentModeLeft),
          @"mode-right": @(UIViewContentModeRight),
          @"mode-top-left": @(UIViewContentModeTopLeft),
          @"mode-top-right": @(UIViewContentModeTopRight),
          @"mode-bottom-left": @(UIViewContentModeBottomLeft),
          @"mode-bottom-right": @(UIViewContentModeRight),
          
          //ui text alignment
          @"center": @(NSTextAlignmentCenter),
          @"right": @(NSTextAlignmentRight),
          @"left": @(NSTextAlignmentLeft),
          @"justified": @(NSTextAlignmentJustified),
          @"natural": @(NSTextAlignmentNatural)
        };
    }
    
    return __mapping;
}

id refl_parseKeyword(NSString *cssValue)
{
    //Called from rhs_parseRhsValue
    //If the Rhs value is a reserved keyword (or a combination of those) this function
    //returns the associated value right aways
    
    NSArray *components = [cssValue componentsSeparatedByString:@","];
    
    BOOL keywords = YES;
    for (NSString *c in components)
        keywords &= refl_rhsKeywordsMap()[c] != nil;
    
    if (!keywords)
        return nil;
    
    NSInteger value = 0;
    for (NSString *c in components) {
        value = value | [refl_rhsKeywordsMap()[c] integerValue];
    }
    
    return @(value);
}

NSString *refl_bundlePath(NSString *file, NSString *extension)
{
    NSString *const resourcePath = @"Frameworks/ReflektorKitSwift.framework/";
    NSString *path = [[NSBundle mainBundle] pathForResource:file ofType:extension];
    
    if (!path)
        path = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%@%@", resourcePath, file] ofType:extension];
    
    return path;
}

#pragma mark - Tokenizer

const char* LESSTokenName[] = {
    "charset",
    "import",
    "page",
    "media",
    "font-face",
    "namespace",
    "important",
    
    "space",
    "string",
    "ident",
    "hash",
    "<!--",
    "-->",
    "~=",
    "!=",
    
    "em",
    "ex",
    "length",
    "angle",
    "time",
    "freq",
    "dimen",
    "percentage",
    "number",
    
    "url",
    "function",
    "unicoderange",
    "unknown"
};

static LESSParser *__currentParser = nil;

typedef NS_ENUM(NSUInteger, RuleType) {
    RuleTypeStyle,
    RuleTypeCharset,
    RuleTypeKeyframes,
    RuleTypeKeyframe
};

typedef NS_ENUM(NSUInteger, Flags) {
    InsideStyleSheet,
    InsideKeyframes,
    InsideRuleSet,
    InsideProperty,
    InsideValue
};

@interface LESSParser () {
    NSMutableDictionary*    _styleSheet;
    NSMutableDictionary *   _activeKeyframes;
    NSMutableDictionary *   _activeRuleSet;
    NSMutableString *       _activeSelector;
    NSMutableString *       _activeKeyframesName;
    NSString *              _activePropertyName;
    
    
    struct {
        RuleType type;
        Flags flag;
        int lastToken;
    } _state;
}

- (void)LESSScan:(const char *)text token:(int)token;

@end

void refl_scan(const char *text, int token)
{
    [__currentParser LESSScan:text token:token];
}


@implementation LESSParser

- (instancetype)init
{
    self = [super init];
    if (self) {
        _activeSelector = [[NSMutableString alloc] init];
        _styleSheet = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)LESSScan:(const char *)text token:(int)token
{
    switch (token) {
        case S:
            return;
        case CHARSET_SYM: {
            _state.type = RuleTypeCharset;
            break;
        }
        case HASH:
        case IDENT: {
            if (_state.type == RuleTypeKeyframes) {
                if (_state.flag == InsideStyleSheet) {
                    if (_activeKeyframesName.length) {
                        [_activeKeyframesName appendString:@" "];
                    }
                    [_activeKeyframesName appendString:@(text)];
                } else if (_state.flag == InsideKeyframes) {
                    [_activeSelector appendString:@(text)];
                } else if (_state.flag == InsideRuleSet) {
                    _state.flag = InsideProperty;
                    _activePropertyName = @(text);
                } else if (_state.flag == InsideValue) {
                    NSMutableString *value = _activeRuleSet[_activePropertyName];
                    [value appendString:@(text)];
                }
                
            }
            else if (_state.type == RuleTypeStyle) {
                if (_state.flag == InsideStyleSheet) {
                    [_activeSelector appendString:@(text)];
                    
                } else if (_state.flag == InsideRuleSet) {
                    _state.flag = InsideProperty;
                    _activePropertyName = @(text);
                } else if (_state.flag == InsideValue) {
                    NSMutableString *value = _activeRuleSet[_activePropertyName];
                    [value appendString:@(text)];
                }
            }
            break;
        }
        case FUNCTION: {
            NSMutableString *value = _activeRuleSet[_activePropertyName];
            [value appendString:@(text)];
            break;
        }
        case STRING:
        case PERCENTAGE:
        case EMS:
        case EXS:
        case LENGTH:
        case FREQ:
        case ANGLE:
        case NUMBER:
        case TIME:
        case URI: {
            if (_state.type == RuleTypeCharset) {
                printf("@charset: %s; \n", text);
            } else if (_state.flag == InsideValue) {
                NSMutableString *value = _activeRuleSet[_activePropertyName];
                if (value.length && _state.lastToken != FUNCTION) {
                    [value appendString:@" "];
                }
                [value appendString:@(text)];
            }
            break;
        }
        case UNKNOWN: {
            switch (text[0]) {
                case '{':
                    if (_state.type == RuleTypeStyle) {
                        _state.flag = InsideRuleSet;
                        _activeRuleSet = [[NSMutableDictionary alloc] init];
                        _activePropertyName = [[NSMutableString alloc] init];
                    } else if (_state.type == RuleTypeKeyframes) {
                        if (_state.flag == InsideStyleSheet) {
                            _state.flag = InsideKeyframes;
                            _activeKeyframes = [[NSMutableDictionary alloc] init];
                        } else if (_state.flag == InsideKeyframes) {
                            _state.flag = InsideRuleSet;
                            _activeRuleSet = [[NSMutableDictionary alloc] init];
                        }
                    }
                    break;
                case '}':
                    if (_state.type == RuleTypeStyle) {
                        _state.flag = InsideStyleSheet;
                        _styleSheet[_activeSelector] = _activeRuleSet;
                        _activeSelector = [[NSMutableString alloc] init];
                    } else if (_state.type == RuleTypeKeyframes) {
                        if (_state.flag == InsideKeyframes) {
                            _state.type = RuleTypeStyle;
                            _state.flag = InsideStyleSheet;
                            _styleSheet[_activeKeyframesName] = _activeKeyframes;
                        } else if (_state.flag == InsideRuleSet) {
                            _state.flag = InsideKeyframes;
                            _activeKeyframes[_activeSelector] = _activeRuleSet;
                            _activeSelector = [[NSMutableString alloc] init];
                        }
                    }
                    break;
                case '*':
                    [_activeSelector appendString:@(text)];
                    break;
                case ':':
                    if (_state.flag == InsideProperty) {
                        _state.flag = InsideValue;
                        NSMutableString *value = [[NSMutableString alloc] init];
                        _activeRuleSet[_activePropertyName] = value;
                    }
                    if (_state.flag == InsideStyleSheet) {
                        [_activeSelector appendString:@(text)];
                    }
                    break;
                case '@': {
                    _state.type = RuleTypeKeyframes;
                    _activeKeyframesName = [[NSMutableString alloc] init];
                    break;
                }
                case ';': {
                    if (_state.type == RuleTypeCharset) {
                        _state.type = RuleTypeStyle;
                    } else if (_state.type == RuleTypeStyle) {
                        if (_state.flag == InsideValue) {
                            _state.flag = InsideRuleSet;
                            _activePropertyName = [[NSMutableString alloc] init];
                        }
                    } else if (_state.type == RuleTypeKeyframes) {
                        if (_state.flag == InsideValue) {
                            _state.flag = InsideRuleSet;
                            _activePropertyName = [[NSMutableString alloc] init];
                        }
                    }
                    break;
                }
                case ',': {
                    if (_state.flag == InsideValue) {
                        NSMutableString *value = _activeRuleSet[_activePropertyName];
                        [value appendString:@(text)];
                    }
                    break;
                }
                case '.': {
                    if (_state.flag == InsideStyleSheet) {
                        [_activeSelector appendString:@(text)];
                    }
                    break;
                }
                case ')': {
                    if (_state.flag == InsideValue) {
                        NSMutableString *value = _activeRuleSet[_activePropertyName];
                        [value appendString:@(text)];
                    }
                    break;
                }
                default:
                    //printf("[%s] (%s)", text, LESSTokenName[token]);
                    break;
            }
            break;
        }
        default:
            //printf("[%s] (%s)", text, LESSTokenName[token]);
            break;
    }
    _state.lastToken = token;
    
}

- (NSDictionary*)parseText:(NSString*)LESSText
{
    __currentParser = self;
    refl_parse([LESSText UTF8String]);
    return _styleSheet;
}

@end

#line 3 "lex.LESS.c"

#define  YY_INT_ALIGNED short int

/* A lexical scanner generated by flex */

#define yy_create_buffer refl_create_buffer
#define yy_delete_buffer refl_delete_buffer
#define yy_flex_debug refl_flex_debug
#define yy_init_buffer refl_init_buffer
#define yy_flush_buffer refl_flush_buffer
#define yy_load_buffer_state refl_load_buffer_state
#define yy_switch_to_buffer refl_switch_to_buffer
#define yyin LESSin
#define yyleng LESSleng
#define yylex LESSlex
#define yylineno LESSlineno
#define yyout LESSout
#define yyrestart LESSrestart
#define yytext LESStext
#define yywrap LESSwrap
#define yyalloc LESSalloc
#define yyrealloc LESSrealloc
#define yyfree LESSfree

#define FLEX_SCANNER
#define YY_FLEX_MAJOR_VERSION 2
#define YY_FLEX_MINOR_VERSION 5
#define YY_FLEX_SUBMINOR_VERSION 35
#if YY_FLEX_SUBMINOR_VERSION > 0
#define FLEX_BETA
#endif

/* First, we deal with  platform-specific or compiler-specific issues. */

/* begin standard C headers. */
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>

/* end standard C headers. */

/* flex integer type definitions */

#ifndef FLEXINT_H
#define FLEXINT_H

/* C99 systems have <inttypes.h>. Non-C99 systems may or may not. */

#if defined (__STDC_VERSION__) && __STDC_VERSION__ >= 199901L

/* C99 says to define __STDC_LIMIT_MACROS before including stdint.h,
 * if you want the limit (max/min) macros for int types.
 */
#ifndef __STDC_LIMIT_MACROS
#define __STDC_LIMIT_MACROS 1
#endif

#include <inttypes.h>
typedef int8_t flex_int8_t;
typedef uint8_t flex_uint8_t;
typedef int16_t flex_int16_t;
typedef uint16_t flex_uint16_t;
typedef int32_t flex_int32_t;
typedef uint32_t flex_uint32_t;
typedef uint64_t flex_uint64_t;
#else
typedef signed char flex_int8_t;
typedef short int flex_int16_t;
typedef int flex_int32_t;
typedef unsigned char flex_uint8_t;
typedef unsigned short int flex_uint16_t;
typedef unsigned int flex_uint32_t;
#endif /* ! C99 */

/* Limits of integral types. */
#ifndef INT8_MIN
#define INT8_MIN               (-128)
#endif
#ifndef INT16_MIN
#define INT16_MIN              (-32767-1)
#endif
#ifndef INT32_MIN
#define INT32_MIN              (-2147483647-1)
#endif
#ifndef INT8_MAX
#define INT8_MAX               (127)
#endif
#ifndef INT16_MAX
#define INT16_MAX              (32767)
#endif
#ifndef INT32_MAX
#define INT32_MAX              (2147483647)
#endif
#ifndef UINT8_MAX
#define UINT8_MAX              (255U)
#endif
#ifndef UINT16_MAX
#define UINT16_MAX             (65535U)
#endif
#ifndef UINT32_MAX
#define UINT32_MAX             (4294967295U)
#endif

#endif /* ! FLEXINT_H */

#ifdef __cplusplus

/* The "const" storage-class-modifier is valid. */
#define YY_USE_CONST

#else	/* ! __cplusplus */

/* C99 requires __STDC__ to be defined as 1. */
#if defined (__STDC__)

#define YY_USE_CONST

#endif	/* defined (__STDC__) */
#endif	/* ! __cplusplus */

#ifdef YY_USE_CONST
#define yyconst const
#else
#define yyconst
#endif

/* Returned upon end-of-file. */
#define YY_NULL 0

/* Promotes a possibly negative, possibly signed char to an unsigned
 * integer for use as an array index.  If the signed char is negative,
 * we want to instead treat it as an 8-bit unsigned char, hence the
 * double cast.
 */
#define YY_SC_TO_UI(c) ((unsigned int) (unsigned char) c)

/* Enter a start condition.  This macro really ought to take a parameter,
 * but we do it the disgusting crufty way forced on us by the ()-less
 * definition of BEGIN.
 */
#define BEGIN (yy_start) = 1 + 2 *

/* Translate the current start state into a value that can be later handed
 * to BEGIN to return to the state.  The YYSTATE alias is for lex
 * compatibility.
 */
#define YY_START (((yy_start) - 1) / 2)
#define YYSTATE YY_START

/* Action number for EOF rule of a given start state. */
#define YY_STATE_EOF(state) (YY_END_OF_BUFFER + state + 1)

/* Special action meaning "start processing a new file". */
#define YY_NEW_FILE LESSrestart(LESSin  )

#define YY_END_OF_BUFFER_CHAR 0

/* Size of default input buffer. */
#ifndef YY_BUF_SIZE
#define YY_BUF_SIZE 16384
#endif

/* The state buf must be large enough to hold one state per character in the main buffer.
 */
#define YY_STATE_BUF_SIZE   ((YY_BUF_SIZE + 2) * sizeof(yy_state_type))

#ifndef YY_TYPEDEF_YY_BUFFER_STATE
#define YY_TYPEDEF_YY_BUFFER_STATE
typedef struct yy_buffer_state *YY_BUFFER_STATE;
#endif

#ifndef YY_TYPEDEF_YY_SIZE_T
#define YY_TYPEDEF_YY_SIZE_T
typedef size_t yy_size_t;
#endif

extern yy_size_t LESSleng;

extern FILE *LESSin, *LESSout;

#define EOB_ACT_CONTINUE_SCAN 0
#define EOB_ACT_END_OF_FILE 1
#define EOB_ACT_LAST_MATCH 2

#define YY_refl_LINENO(n)

/* Return all but the first "n" matched characters back to the input stream. */
#define yyless(n) \
do \
{ \
/* Undo effects of setting up LESStext. */ \
int yyrefl_macro_arg = (n); \
YY_refl_LINENO(yyrefl_macro_arg);\
*yy_cp = (yy_hold_char); \
YY_RESTORE_YY_MORE_OFFSET \
(yy_c_buf_p) = yy_cp = yy_bp + yyrefl_macro_arg - YY_MORE_ADJ; \
YY_DO_BEFORE_ACTION; /* set up LESStext again */ \
} \
while ( 0 )

#define unput(c) yyunput( c, (yytext_ptr)  )

#ifndef YY_STRUCT_YY_BUFFER_STATE
#define YY_STRUCT_YY_BUFFER_STATE
struct yy_buffer_state
{
    FILE *yy_input_file;
    
    char *yy_ch_buf;		/* input buffer */
    char *yy_buf_pos;		/* current position in input buffer */
    
    /* Size of input buffer in bytes, not including room for EOB
     * characters.
     */
    yy_size_t yy_buf_size;
    
    /* Number of characters read into yy_ch_buf, not including EOB
     * characters.
     */
    yy_size_t yy_n_chars;
    
    /* Whether we "own" the buffer - i.e., we know we created it,
     * and can realloc() it to grow it, and should free() it to
     * delete it.
     */
    int yy_is_our_buffer;
    
    /* Whether this is an "interactive" input source; if so, and
     * if we're using stdio for input, then we want to use getc()
     * instead of fread(), to make sure we stop fetching input after
     * each newline.
     */
    int yy_is_interactive;
    
    /* Whether we're considered to be at the beginning of a line.
     * If so, '^' rules will be active on the next match, otherwise
     * not.
     */
    int yy_at_bol;
    
    int yy_bs_lineno; /**< The line count. */
    int yy_bs_column; /**< The column count. */
    
    /* Whether to try to fill the input buffer when we reach the
     * end of it.
     */
    int yy_fill_buffer;
    
    int yy_buffer_status;
    
#define YY_BUFFER_NEW 0
#define YY_BUFFER_NORMAL 1
    /* When an EOF's been seen but there's still some text to process
     * then we mark the buffer as YY_EOF_PENDING, to indicate that we
     * shouldn't try reading from the input source any more.  We might
     * still have a bunch of tokens to match, though, because of
     * possible backing-up.
     *
     * When we actually see the EOF, we change the status to "new"
     * (via LESSrestart()), so that the user can continue scanning by
     * just pointing LESSin at a new input file.
     */
#define YY_BUFFER_EOF_PENDING 2
    
};
#endif /* !YY_STRUCT_YY_BUFFER_STATE */

/* Stack of input buffers. */
static size_t yy_buffer_stack_top = 0; /**< index of top of stack. */
static size_t yy_buffer_stack_max = 0; /**< capacity of stack. */
static YY_BUFFER_STATE * yy_buffer_stack = 0; /**< Stack as an array. */

/* We provide macros for accessing buffer states in case in the
 * future we want to put the buffer states in a more general
 * "scanner state".
 *
 * Returns the top of the stack, or NULL.
 */
#define YY_CURRENT_BUFFER ( (yy_buffer_stack) \
? (yy_buffer_stack)[(yy_buffer_stack_top)] \
: NULL)

/* Same as previous macro, but useful when we know that the buffer stack is not
 * NULL or when we need an lvalue. For internal use only.
 */
#define YY_CURRENT_BUFFER_LVALUE (yy_buffer_stack)[(yy_buffer_stack_top)]

/* yy_hold_char holds the character lost when LESStext is formed. */
static char yy_hold_char;
static yy_size_t yy_n_chars;		/* number of characters read into yy_ch_buf */
yy_size_t LESSleng;

/* Points to current character in buffer. */
static char *yy_c_buf_p = (char *) 0;
static int yy_init = 0;		/* whether we need to initialize */
static int yy_start = 0;	/* start state number */

/* Flag which is used to allow LESSwrap()'s to do buffer switches
 * instead of setting up a fresh LESSin.  A bit of a hack ...
 */
static int yy_did_buffer_switch_on_eof;

void LESSrestart (FILE *input_file  );
void refl_switch_to_buffer (YY_BUFFER_STATE new_buffer  );
YY_BUFFER_STATE refl_create_buffer (FILE *file,int size  );
void refl_delete_buffer (YY_BUFFER_STATE b  );
void refl_flush_buffer (YY_BUFFER_STATE b  );
void LESSpush_buffer_state (YY_BUFFER_STATE new_buffer  );
void LESSpop_buffer_state (void );

static void LESSensure_buffer_stack (void );
static void refl_load_buffer_state (void );
static void refl_init_buffer (YY_BUFFER_STATE b,FILE *file  );

#define YY_FLUSH_BUFFER refl_flush_buffer(YY_CURRENT_BUFFER )

YY_BUFFER_STATE refl_scan_buffer (char *base,yy_size_t size  );
YY_BUFFER_STATE refl_scan_string (yyconst char *yy_str  );
YY_BUFFER_STATE refl_scan_bytes (yyconst char *bytes,yy_size_t len  );

void *LESSalloc (yy_size_t  );
void *LESSrealloc (void *,yy_size_t  );
void LESSfree (void *  );

#define yy_new_buffer refl_create_buffer

#define yy_set_interactive(is_interactive) \
{ \
if ( ! YY_CURRENT_BUFFER ){ \
LESSensure_buffer_stack (); \
YY_CURRENT_BUFFER_LVALUE =    \
refl_create_buffer(LESSin,YY_BUF_SIZE ); \
} \
YY_CURRENT_BUFFER_LVALUE->yy_is_interactive = is_interactive; \
}

#define yy_set_bol(at_bol) \
{ \
if ( ! YY_CURRENT_BUFFER ){\
LESSensure_buffer_stack (); \
YY_CURRENT_BUFFER_LVALUE =    \
refl_create_buffer(LESSin,YY_BUF_SIZE ); \
} \
YY_CURRENT_BUFFER_LVALUE->yy_at_bol = at_bol; \
}

#define YY_AT_BOL() (YY_CURRENT_BUFFER_LVALUE->yy_at_bol)

/* Begin user sect3 */

typedef unsigned char YY_CHAR;

FILE *LESSin = (FILE *) 0, *LESSout = (FILE *) 0;

typedef int yy_state_type;

extern int LESSlineno;

int LESSlineno = 1;

extern char *LESStext;
#define yytext_ptr LESStext

static yy_state_type yy_get_previous_state (void );
static yy_state_type yy_try_NUL_trans (yy_state_type current_state  );
static int yy_get_next_buffer (void );
static void yy_fatal_error (yyconst char msg[]  );

/* Done after the current pattern has been matched and before the
 * corresponding action - sets up LESStext.
 */
#define YY_DO_BEFORE_ACTION \
(yytext_ptr) = yy_bp; \
LESSleng = (yy_size_t) (yy_cp - yy_bp); \
(yy_hold_char) = *yy_cp; \
*yy_cp = '\0'; \
(yy_c_buf_p) = yy_cp;

#define YY_NUM_RULES 41
#define YY_END_OF_BUFFER 42
/* This struct is not used in this scanner,
 but its presence is necessary. */
struct yy_trans_info
{
    flex_int32_t yy_verify;
    flex_int32_t yy_nxt;
};
static yyconst flex_int16_t yy_accept[292] =
{   0,
    0,    0,   42,   40,    1,    1,   40,   40,   40,   40,
    40,   40,   40,   34,   40,   40,    8,    8,   40,   40,
    40,    1,    0,    0,    7,    0,    9,    0,    0,    0,
    0,    8,    0,   34,    0,   33,    0,    0,   34,   32,
    32,   32,   32,   32,   32,   32,   32,   32,   32,   32,
    29,    0,    0,    0,    0,    0,    0,    0,    0,   37,
    8,    0,    0,    8,    8,    8,    6,    5,    0,    0,
    0,    7,    0,    0,    9,    9,    0,    0,    7,    0,
    0,    4,    0,    0,   32,    0,   20,   32,   17,   18,
    32,   30,   22,   32,   21,   28,   24,   23,   19,   32,
    
    32,   32,    0,    0,    0,    0,    0,    0,    0,    8,
    8,   38,   38,    8,    8,    0,    0,    0,    9,    0,
    0,    0,    0,    2,   32,   32,   25,   32,   31,   26,
    32,    3,    0,    0,    0,    0,    0,    0,    8,    0,
    38,   38,   38,   37,    8,    0,    0,    9,    0,    0,
    0,    0,    0,    2,   32,   27,   32,    0,    0,    0,
    0,    0,   11,    8,   39,   38,   38,   38,   38,    0,
    0,    0,    0,   36,    0,    8,    0,    0,    9,    0,
    0,   32,   32,    0,    0,    0,   12,    0,    8,   39,
    38,   38,   38,   38,   38,    0,    0,    0,    0,    0,
    
    0,    0,    0,    0,   36,    0,    0,    8,    0,    0,
    9,    0,   32,   32,    0,    0,   10,    0,    8,   39,
    38,   38,   38,   38,   38,   38,    0,   35,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    8,
    0,    0,    9,    0,   32,   32,   14,    0,    0,    8,
    39,   38,   38,   38,   38,   38,   38,   38,    0,   35,
    0,    0,    0,   35,    0,    0,    0,    0,   32,    0,
    0,   39,    0,    0,    0,    0,   13,   15,   39,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,   16,
    0
    
} ;

static yyconst flex_int32_t yy_ec[256] =
{   0,
    1,    1,    1,    1,    1,    1,    1,    1,    2,    3,
    1,    4,    5,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    6,    7,    8,    9,   10,   11,   10,   12,   13,
    14,   15,   16,   10,   17,   18,   19,   20,   20,   20,
    20,   20,   20,   20,   20,   20,   20,   10,   10,   21,
    22,   23,   24,   25,   26,   27,   28,   29,   30,   31,
    32,   33,   34,   35,   36,   37,   38,   39,   40,   41,
    35,   42,   43,   44,   45,   35,   46,   47,   35,   48,
    10,   49,   10,   10,   10,   10,   50,   27,   51,   52,
    
    53,   54,   55,   56,   57,   35,   58,   59,   60,   61,
    62,   63,   35,   64,   65,   66,   67,   35,   68,   69,
    35,   70,   71,   72,   73,   74,    1,   75,   75,   75,
    75,   75,   75,   75,   75,   75,   75,   75,   75,   75,
    75,   75,   75,   75,   75,   75,   75,   75,   75,   75,
    75,   75,   75,   75,   75,   75,   75,   75,   75,   75,
    75,   75,   75,   75,   75,   75,   75,   75,   75,   75,
    75,   75,   75,   75,   75,   75,   75,   75,   75,   75,
    75,   75,   75,   75,   75,   75,   75,   75,   75,   75,
    75,   75,   75,   75,   75,   75,   75,   75,   75,   75,
    
    75,   75,   75,   75,   75,   75,   75,   75,   75,   75,
    75,   75,   75,   75,   75,   75,   75,   75,   75,   75,
    75,   75,   75,   75,   75,   75,   75,   75,   75,   75,
    75,   75,   75,   75,   75,   75,   75,   75,   75,   75,
    75,   75,   75,   75,   75,   75,   75,   75,   75,   75,
    75,   75,   75,   75,   75
} ;

static yyconst flex_int32_t yy_meta[76] =
{   0,
    1,    2,    3,    3,    3,    4,    4,    4,    4,    4,
    4,    4,    5,    4,    4,    4,    6,    4,    4,    7,
    4,    4,    4,    8,    4,    9,    9,    9,    9,    9,
    9,   10,   10,   10,   10,   10,   10,   10,   10,   10,
    10,   10,   10,   10,   10,   10,   10,   10,   10,    9,
    9,    9,    9,    9,   10,   10,   10,   10,   10,   10,
    10,   10,   10,   10,   10,   10,   10,   10,   10,   10,
    4,    4,    4,    4,   10
} ;

static yyconst flex_int16_t yy_base[328] =
{   0,
    0,    0,  691, 3338,   74,   79,  618,   78,  639,   75,
    71,  665,  664,  117,  671,  165,   76,   77,  209,  655,
    654,   92,   45,   84, 3338,  262,  626,  297,   87,  350,
    639,   89,  385,   83,  646, 3338,  611,  639,    0,  608,
    62,  158,  163,   65,   60,  156,   83,  208,  203,  164,
    602,  420,  633,   84,  158,  164,  188,   92,  165, 3338,
    181,  455,  625,  184,  195,  508, 3338, 3338,  575,  245,
    226,  234,  561,  614,  598,  667,  246,  259,  269,  720,
    773, 3338,  631,   91,  589,  808,  587,  247,  586,  583,
    248,  577,  576,  207,  574,  560,  559,  558,  556,  251,
    
    555,  861,  583,  259,  245,  258,  249,  269,  255,  196,
    914,   88,  574,  273,  949,  285,  296,  984, 1019,  308,
    1054,  557,  315, 3338,  522, 1107,  493,  307,  476,  468,
    1142, 3338,  296,  295,  301,  301,  313,  314, 1177,    0,
    316,  474,  445,  380, 1212,  308, 1247, 1282, 1317,  445,
    350,  427,  356,  418, 1352,  376, 1387,  330,  390,  332,
    367,  344, 3338, 1422,    0,  373,  340,  313,  308,  416,
    450,  323,  377, 3338, 1475, 1510,  369, 1545, 1580, 1615,
    408, 1650, 1685,  378,  403,  397, 3338,  403, 1720,    0,
    374,  281,  252,  203,  176,  474,  451,  487, 1773,  394,
    
    1826,  571,  625,  678,  731, 1879, 1932, 1967,  405, 2002,
    2037, 2072, 2107, 2142,  450,  469, 3338,  470, 2177,    0,
    444,  165,  107,   99,   97,   91,  527, 3338,  494,  495,
    784, 2230, 2283,  537,  475,  803, 2336, 2389, 2424, 2459,
    462, 2494, 2529, 2564, 2599, 2634, 3338,  494,  495,  548,
    0,   87, 3338, 3338, 3338, 3338, 3338, 3338,  872,  507,
    519, 2669,  921,  506,  535, 2704, 2739,  504,  591,  548,
    550,    0, 2774, 2809, 2844,  556, 3338, 3338, 3338, 2879,
    2914, 2949,  560, 2984, 3019, 3054,  558,  650,  703, 3338,
    3338, 3107, 3112, 3121, 3126, 3132, 3139, 3148, 3155, 3164,
    
    3174, 3176, 3181, 3188, 3195, 3199, 3208, 3215, 3220, 3229,
    3239, 3243, 3247, 3255, 3259, 3263, 3271, 3280, 3289, 3293,
    3297, 3305, 3314, 3318, 3322, 3325, 3328
} ;

static yyconst flex_int16_t yy_def[328] =
{   0,
    291,    1,  291,  291,  291,  291,  291,  292,  293,  294,
    295,  291,  291,  291,  291,  291,  296,  296,  297,  291,
    291,  291,  291,  292,  291,  298,  293,  299,  294,  300,
    291,  296,  297,   14,  301,  291,  302,  291,   14,  303,
    303,  303,  303,  303,  303,  303,  303,  303,  303,  303,
    303,  304,  291,  291,  291,  291,  291,  291,  291,  291,
    296,  305,  306,  296,  296,  296,  291,  291,  291,  292,
    292,  292,  292,  298,  293,  293,  294,  294,  294,  294,
    300,  291,  301,  307,  303,  308,  303,  303,  303,  303,
    303,  303,  303,  303,  303,  303,  303,  303,  303,  303,
    
    303,  303,  291,  291,  291,  291,  291,  291,  291,  296,
    66,  309,  291,  296,   66,  291,  292,   73,   76,  294,
    80,  310,  311,  291,  303,  102,  303,  303,  303,  303,
    102,  291,  291,  291,  291,  291,  291,  291,  111,  312,
    313,  291,  291,  314,   66,  291,   73,   76,   80,  310,
    307,  310,  311,  310,  126,  303,  102,  291,  291,  291,
    291,  291,  291,  111,  315,  316,  291,  291,  291,  314,
    314,  317,  318,  291,  319,   66,  291,   73,   76,   80,
    311,  126,  102,  291,  291,  291,  291,  291,  111,  320,
    321,  291,  291,  291,  291,  291,  317,  291,  322,  318,
    
    323,  314,  314,  314,  314,  314,  319,   66,  291,   73,
    76,   80,  126,  102,  291,  291,  291,  291,  111,  324,
    325,  291,  291,  291,  291,  291,  291,  291,  317,  317,
    317,  317,  322,  318,  318,  318,  318,  323,  206,   66,
    291,   73,   76,   80,  126,  102,  291,  291,  291,  240,
    326,  291,  291,  291,  291,  291,  291,  291,  317,  317,
    317,  232,  318,  318,  318,  237,  206,  291,  246,  291,
    291,  327,  232,  237,  206,  291,  291,  291,  291,  232,
    237,  206,  291,  232,  237,  206,  291,  317,  318,  291,
    0,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291
} ;

static yyconst flex_int16_t yy_nxt[3414] =
{   0,
    4,    5,    6,    5,    5,    5,    7,    8,    9,    4,
    4,   10,    4,    4,    4,    4,   11,   12,   13,   14,
    15,    4,    4,    4,   16,   17,   17,   17,   17,   17,
    17,   17,   17,   17,   17,   17,   17,   17,   17,   17,
    17,   17,   17,   17,   18,   17,   17,   17,   19,   17,
    17,   17,   17,   17,   17,   17,   17,   17,   17,   17,
    17,   17,   17,   17,   17,   17,   18,   17,   17,   17,
    4,   20,    4,   21,   17,   22,   22,   22,   22,   22,
    22,   22,   22,   22,   22,   25,   25,   31,   60,   60,
    69,   25,   63,   22,   22,   22,   22,   22,   25,   87,
    
    291,   60,   34,  140,  140,  123,   91,   92,   86,  124,
    86,  142,   69,   86,  258,   94,  104,  108,   64,   33,
    257,   87,  256,   30,   62,   62,   26,   36,   91,   92,
    255,   86,   26,   37,   38,   30,   39,   62,   94,  104,
    64,  108,   40,   40,   41,   42,   43,   40,   44,   45,
    46,   40,   47,   40,   48,   40,   40,   49,   50,   51,
    40,   40,   40,   40,   40,   52,   40,   41,   42,   43,
    40,   44,   45,   46,   47,   40,   48,   40,   40,   49,
    50,   51,   40,   40,   40,   40,   40,   88,  254,  100,
    109,   40,   54,   60,   93,   55,   60,  105,   56,  226,
    
    89,  106,   57,   58,   86,   59,   86,   60,   60,   90,
    88,   86,   86,  100,  109,   54,   93,  107,   55,  105,
    114,   56,   89,  106,   57,   58,  225,   59,   66,   62,
    97,   90,   62,   25,   66,   66,   66,   66,   66,   66,
    107,   25,  114,   62,   62,   95,   98,   24,   29,   99,
    96,   86,   25,   97,  129,   86,   86,   25,   66,   66,
    66,   66,   66,   24,   24,   24,   70,   95,   98,   72,
    25,   99,   96,  128,   26,  224,  129,  136,  127,  130,
    25,   73,   26,  134,  133,  144,  138,   73,   73,   73,
    73,   73,   73,   26,   30,   86,   86,  128,  135,   86,
    
    136,  127,  130,   25,  223,  134,  137,   30,  133,  138,
    74,   73,   73,   73,   73,   73,   76,   30,  146,   25,
    135,   62,   76,   76,   76,   76,   76,   76,  137,  153,
    198,  195,  140,  154,  161,  156,  194,  158,  159,  167,
    160,  146,  162,  163,   26,  177,   76,   76,   76,   76,
    76,   29,   29,   29,   77,   86,   30,  161,  156,  158,
    159,   79,  160,  193,  181,  162,  163,  177,  124,   80,
    153,  199,  184,  186,  154,   80,   80,   80,   80,   80,
    80,  170,  170,  170,  170,  170,  188,  172,  198,  140,
    140,  173,  187,  174,  184,  186,  192,  222,   81,   80,
    
    80,   80,   80,   80,   66,  198,  185,  215,  188,  209,
    66,   66,   66,   66,   66,   66,  187,  170,  170,  170,
    170,  170,  181,  172,   86,  201,  154,  173,  175,  174,
    215,  209,  151,  216,   66,   66,   66,   66,   66,  102,
    217,  151,  201,  218,  241,  102,  102,  102,  102,  102,
    102,  196,  196,  196,  196,  196,  216,  291,  198,  151,
    140,  291,  217,  174,  175,  218,  241,  253,  169,  102,
    102,  102,  102,  102,  111,  196,  196,  196,  196,  196,
    111,  111,  111,  111,  111,  111,  198,  174,  227,  227,
    227,  227,  227,  247,  248,  249,  197,  168,  175,  199,
    
    228,  198,  198,  268,  111,  111,  111,  111,  111,   65,
    65,   65,   65,   65,  198,  247,   86,  198,  248,  249,
    60,  270,  271,  201,   86,  268,  198,  115,  227,  227,
    227,  227,  227,  115,  115,  115,  115,  115,  115,  200,
    228,   86,  199,  199,  270,  271,  198,  276,  198,  110,
    110,  110,  110,  110,  201,  199,   62,  115,  115,  115,
    115,  115,   71,  117,  117,  117,   71,  199,   25,  276,
    86,  151,  196,  196,  196,  196,  196,  277,  291,  278,
    118,  283,  291,  201,  174,  201,  118,  118,  118,  118,
    118,  118,  125,  125,  125,  125,  125,  143,  287,  132,
    
    277,  290,  278,   86,   86,  283,   86,   86,   86,   26,
    118,  118,  118,  118,  118,   24,   24,   24,   70,  175,
    287,   72,   86,  290,   86,   86,  196,  196,  196,  196,
    196,   86,  291,   73,   86,   86,  291,   86,  174,   73,
    73,   73,   73,   73,   73,   84,   28,  116,  113,  103,
    86,  230,  261,  261,  261,  230,   86,  198,   34,   52,
    84,   82,   74,   73,   73,   73,   73,   73,   75,   75,
    75,   75,   75,  175,   28,   68,   67,   53,   35,  196,
    196,  196,  196,  196,   34,  291,  119,   28,   23,  291,
    291,  174,  119,  119,  119,  119,  119,  119,  199,  291,
    
    291,  291,  291,  291,  235,  265,  265,  265,  235,  291,
    291,  291,  291,  291,  198,   28,  119,  119,  119,  119,
    119,   78,  120,  120,  120,   78,  175,  291,  291,  291,
    291,   25,  196,  196,  196,  196,  196,  291,  291,  121,
    291,  291,  291,  291,  174,  121,  121,  121,  121,  121,
    121,  201,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,   30,  121,
    121,  121,  121,  121,   29,   29,   29,   77,  291,  175,
    291,  291,  291,  291,   79,  259,  227,  227,  227,  259,
    291,  198,   80,  291,  291,  291,  291,  260,   80,   80,
    
    80,   80,   80,   80,  263,  227,  227,  227,  263,  291,
    291,  291,  291,  291,  198,  291,  264,  291,  291,  291,
    291,   81,   80,   80,   80,   80,   80,  126,  291,  291,
    291,  291,  199,  126,  126,  126,  126,  126,  126,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  201,  291,  291,  291,  291,  291,  126,  126,  126,
    126,  126,  101,  101,  101,  101,  101,  291,  291,  291,
    291,  291,  291,  259,  227,  227,  227,  259,  291,  198,
    131,  291,  291,  291,  291,  260,  131,  131,  131,  131,
    131,  131,  291,  291,  291,  291,  291,  291,  291,  291,
    
    291,  291,  291,  291,  291,  291,  291,  291,  291,   86,
    131,  131,  131,  131,  131,  110,  110,  110,  110,  110,
    199,  291,  263,  227,  227,  227,  263,  291,  291,  291,
    291,  291,  198,  139,  264,  291,  291,  291,  291,  139,
    139,  139,  139,  139,  139,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  139,  139,  139,  139,  139,  145,  201,
    291,  291,  291,  291,  145,  145,  145,  145,  145,  145,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  145,  145,
    
    145,  145,  145,  147,  291,  291,  291,  291,  291,  147,
    147,  147,  147,  147,  147,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  147,  147,  147,  147,  147,  148,  291,
    291,  291,  291,  291,  148,  148,  148,  148,  148,  148,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  148,  148,
    148,  148,  148,  149,  291,  291,  291,  291,  291,  149,
    149,  149,  149,  149,  149,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    
    291,  291,  291,  149,  149,  149,  149,  149,  125,  125,
    125,  125,  125,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  155,  291,  291,  291,
    291,  291,  155,  155,  155,  155,  155,  155,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  155,  155,  155,  155,
    155,  157,  291,  291,  291,  291,  291,  157,  157,  157,
    157,  157,  157,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  157,  157,  157,  157,  157,  164,  291,  291,  291,
    
    291,  291,  164,  164,  164,  164,  164,  164,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  164,  164,  164,  164,
    164,  176,  291,  291,  291,  291,  291,  176,  176,  176,
    176,  176,  176,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  176,  176,  176,  176,  176,  178,  291,  291,  291,
    291,  291,  178,  178,  178,  178,  178,  178,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  178,  178,  178,  178,
    
    178,  179,  291,  291,  291,  291,  291,  179,  179,  179,
    179,  179,  179,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  179,  179,  179,  179,  179,  180,  291,  291,  291,
    291,  291,  180,  180,  180,  180,  180,  180,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  180,  180,  180,  180,
    180,  182,  291,  291,  291,  291,  291,  182,  182,  182,
    182,  182,  182,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    
    291,  182,  182,  182,  182,  182,  183,  291,  291,  291,
    291,  291,  183,  183,  183,  183,  183,  183,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  183,  183,  183,  183,
    183,  189,  291,  291,  291,  291,  291,  189,  189,  189,
    189,  189,  189,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  189,  189,  189,  189,  189,  196,  196,  196,  196,
    202,  291,  204,  291,  291,  291,  204,  204,  205,  291,
    291,  291,  291,  291,  206,  291,  291,  291,  291,  291,
    
    206,  206,  206,  206,  206,  206,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  207,  206,  206,  206,  206,  206,  208,
    291,  291,  291,  291,  291,  208,  208,  208,  208,  208,
    208,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  208,
    208,  208,  208,  208,  210,  291,  291,  291,  291,  291,
    210,  210,  210,  210,  210,  210,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  210,  210,  210,  210,  210,  211,
    
    291,  291,  291,  291,  291,  211,  211,  211,  211,  211,
    211,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  211,
    211,  211,  211,  211,  212,  291,  291,  291,  291,  291,
    212,  212,  212,  212,  212,  212,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  212,  212,  212,  212,  212,  213,
    291,  291,  291,  291,  291,  213,  213,  213,  213,  213,
    213,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  213,
    
    213,  213,  213,  213,  214,  291,  291,  291,  291,  291,
    214,  214,  214,  214,  214,  214,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  214,  214,  214,  214,  214,  219,
    291,  291,  291,  291,  291,  219,  219,  219,  219,  219,
    219,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  219,
    219,  219,  219,  219,  197,  197,  197,  229,  291,  291,
    231,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  232,  291,  291,  291,  291,  291,  232,  232,
    
    232,  232,  232,  232,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  233,  232,  232,  232,  232,  232,  200,  200,  200,
    234,  291,  291,  291,  291,  291,  291,  236,  291,  291,
    291,  291,  291,  291,  291,  237,  291,  291,  291,  291,
    291,  237,  237,  237,  237,  237,  237,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  238,  237,  237,  237,  237,  237,
    202,  202,  202,  202,  202,  291,  291,  291,  291,  291,
    291,  291,  174,  291,  291,  291,  291,  291,  239,  291,
    
    291,  291,  291,  291,  239,  239,  239,  239,  239,  239,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  175,  239,  239,
    239,  239,  239,  196,  196,  196,  196,  202,  291,  204,
    291,  291,  291,  204,  204,  205,  291,  291,  291,  291,
    291,  206,  291,  291,  291,  291,  291,  206,  206,  206,
    206,  206,  206,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    207,  206,  206,  206,  206,  206,  240,  291,  291,  291,
    291,  291,  240,  240,  240,  240,  240,  240,  291,  291,
    
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  240,  240,  240,  240,
    240,  242,  291,  291,  291,  291,  291,  242,  242,  242,
    242,  242,  242,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  242,  242,  242,  242,  242,  243,  291,  291,  291,
    291,  291,  243,  243,  243,  243,  243,  243,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  243,  243,  243,  243,
    243,  244,  291,  291,  291,  291,  291,  244,  244,  244,
    
    244,  244,  244,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  244,  244,  244,  244,  244,  245,  291,  291,  291,
    291,  291,  245,  245,  245,  245,  245,  245,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  245,  245,  245,  245,
    245,  246,  291,  291,  291,  291,  291,  246,  246,  246,
    246,  246,  246,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  246,  246,  246,  246,  246,  250,  291,  291,  291,
    
    291,  291,  250,  250,  250,  250,  250,  250,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  250,  250,  250,  250,
    250,  230,  261,  261,  261,  230,  291,  198,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  262,
    291,  291,  291,  291,  291,  262,  262,  262,  262,  262,
    262,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  199,  262,
    262,  262,  262,  262,  197,  197,  197,  229,  291,  291,
    231,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    
    291,  291,  232,  291,  291,  291,  291,  291,  232,  232,
    232,  232,  232,  232,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  233,  232,  232,  232,  232,  232,  235,  265,  265,
    265,  235,  291,  291,  291,  291,  291,  198,  291,  291,
    291,  291,  291,  291,  291,  266,  291,  291,  291,  291,
    291,  266,  266,  266,  266,  266,  266,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  201,  266,  266,  266,  266,  266,
    200,  200,  200,  234,  291,  291,  291,  291,  291,  291,
    
    236,  291,  291,  291,  291,  291,  291,  291,  237,  291,
    291,  291,  291,  291,  237,  237,  237,  237,  237,  237,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  238,  237,  237,
    237,  237,  237,  267,  291,  291,  291,  291,  291,  267,
    267,  267,  267,  267,  267,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  267,  267,  267,  267,  267,   61,  291,
    291,  291,  291,  291,   61,   61,   61,   61,   61,   61,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    
    291,  291,  291,  291,  291,  291,  291,  291,   61,   61,
    61,   61,   61,   24,  291,  291,  291,  291,  291,   24,
    24,   24,   24,   24,   24,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,   24,   24,   24,   24,   24,   27,  291,
    291,  291,  291,  291,   27,   27,   27,   27,   27,   27,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,   27,   27,
    27,   27,   27,   29,  291,  291,  291,  291,  291,   29,
    29,   29,   29,   29,   29,  291,  291,  291,  291,  291,
    
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,   29,   29,   29,   29,   29,  269,  291,
    291,  291,  291,  291,  269,  269,  269,  269,  269,  269,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  269,  269,
    269,  269,  269,   85,  291,  291,  291,  291,  291,   85,
    85,   85,   85,   85,   85,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,   85,   85,   85,   85,   85,  273,  291,
    291,  291,  291,  291,  273,  273,  273,  273,  273,  273,
    
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  273,  273,
    273,  273,  273,  274,  291,  291,  291,  291,  291,  274,
    274,  274,  274,  274,  274,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  274,  274,  274,  274,  274,  275,  291,
    291,  291,  291,  291,  275,  275,  275,  275,  275,  275,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  275,  275,
    275,  275,  275,  280,  291,  291,  291,  291,  291,  280,
    
    280,  280,  280,  280,  280,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  280,  280,  280,  280,  280,  281,  291,
    291,  291,  291,  291,  281,  281,  281,  281,  281,  281,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  281,  281,
    281,  281,  281,  282,  291,  291,  291,  291,  291,  282,
    282,  282,  282,  282,  282,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  282,  282,  282,  282,  282,  284,  291,
    
    291,  291,  291,  291,  284,  284,  284,  284,  284,  284,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  284,  284,
    284,  284,  284,  285,  291,  291,  291,  291,  291,  285,
    285,  285,  285,  285,  285,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  285,  285,  285,  285,  285,  286,  291,
    291,  291,  291,  291,  286,  286,  286,  286,  286,  286,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  286,  286,
    
    286,  286,  286,  288,  291,  291,  291,  291,  291,  288,
    288,  288,  288,  288,  288,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  288,  288,  288,  288,  288,  289,  291,
    291,  291,  291,  291,  289,  289,  289,  289,  289,  289,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  289,  289,
    289,  289,  289,  171,  291,  291,  291,  291,  291,  171,
    171,  171,  171,  171,  171,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    
    291,  291,  291,  171,  171,  171,  171,  171,   24,  291,
    24,   24,   24,   24,   24,   24,   24,   27,   27,  291,
    27,   27,   29,  291,   29,   29,   29,   29,   29,   29,
    29,   32,  291,  291,   32,   32,   61,   61,   61,  291,
    61,   61,   65,   65,   65,   65,   65,   65,   65,   71,
    71,   71,   71,   71,   71,   71,   71,   71,   75,   75,
    75,   75,   75,   75,   75,   78,   78,   78,   78,   78,
    78,   78,   78,   78,   83,   83,   83,   83,   83,   83,
    83,   83,   83,   83,   40,   40,   85,   85,  291,   85,
    85,  101,  101,  101,  101,  101,  101,  101,  110,  110,
    
    110,  110,  110,  110,  110,  112,  112,  112,  122,  122,
    122,  122,  122,  122,  122,  122,  122,  122,  125,  125,
    125,  125,  125,  125,  125,  141,  141,  141,  141,  150,
    150,  150,  150,  150,  150,  150,  150,  150,  150,  152,
    152,  152,  152,  152,  152,  152,  152,  152,  152,  165,
    291,  165,  166,  166,  166,  166,  171,  171,  171,  291,
    171,  171,  171,  171,  171,  190,  291,  190,  191,  191,
    191,  191,  197,  291,  197,  197,  197,  197,  197,  197,
    197,  200,  291,  200,  200,  200,  200,  200,  200,  200,
    203,  203,  203,  203,  203,  203,  203,  203,  203,  220,
    
    291,  220,  221,  221,  221,  221,  230,  230,  230,  230,
    230,  230,  230,  230,  230,  235,  235,  235,  235,  235,
    235,  235,  235,  235,  251,  291,  251,  252,  252,  252,
    252,  272,  291,  272,  279,  291,  279,    3,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291
} ;

static yyconst flex_int16_t yy_chk[3414] =
{   0,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    5,    5,    5,    5,    5,
    6,    6,    6,    6,    6,    8,   10,   11,   17,   18,
    23,   24,   18,   22,   22,   22,   22,   22,   29,   41,
    
    34,   32,   34,  252,  112,   84,   44,   45,   45,   84,
    41,  112,   23,   44,  226,   47,   54,   58,   18,   11,
    225,   41,  224,   10,   17,   18,    8,   14,   44,   45,
    223,   47,   24,   14,   14,   29,   14,   32,   47,   54,
    18,   58,   14,   14,   14,   14,   14,   14,   14,   14,
    14,   14,   14,   14,   14,   14,   14,   14,   14,   14,
    14,   14,   14,   14,   14,   14,   14,   14,   14,   14,
    14,   14,   14,   14,   14,   14,   14,   14,   14,   14,
    14,   14,   14,   14,   14,   14,   14,   42,  222,   50,
    59,   14,   16,   61,   46,   16,   64,   55,   16,  195,
    
    43,   56,   16,   16,   46,   16,   42,   65,  110,   43,
    42,   43,   50,   50,   59,   16,   46,   57,   16,   55,
    64,   16,   43,   56,   16,   16,  194,   16,   19,   61,
    49,   43,   64,   71,   19,   19,   19,   19,   19,   19,
    57,   72,   64,   65,  110,   48,   49,   70,   77,   49,
    48,   49,   70,   49,   94,   94,   48,   77,   19,   19,
    19,   19,   19,   26,   26,   26,   26,   48,   49,   26,
    78,   49,   48,   91,   71,  193,   94,  107,   88,  100,
    79,   26,   72,  105,  104,  114,  109,   26,   26,   26,
    26,   26,   26,   70,   77,   88,   91,   91,  106,  100,
    
    107,   88,  100,  117,  192,  105,  108,   78,  104,  109,
    26,   26,   26,   26,   26,   26,   28,   79,  116,  120,
    106,  114,   28,   28,   28,   28,   28,   28,  108,  123,
    172,  169,  141,  123,  136,  128,  168,  133,  134,  141,
    135,  116,  137,  138,  117,  146,   28,   28,   28,   28,
    28,   30,   30,   30,   30,  128,  120,  136,  128,  133,
    134,   30,  135,  167,  151,  137,  138,  146,  151,   30,
    153,  172,  158,  160,  153,   30,   30,   30,   30,   30,
    30,  144,  144,  144,  144,  144,  162,  144,  173,  166,
    191,  144,  161,  144,  158,  160,  166,  191,   30,   30,
    
    30,   30,   30,   30,   33,  200,  159,  184,  162,  177,
    33,   33,   33,   33,   33,   33,  161,  170,  170,  170,
    170,  170,  181,  170,  156,  173,  181,  170,  144,  170,
    184,  177,  154,  185,   33,   33,   33,   33,   33,   52,
    186,  152,  200,  188,  209,   52,   52,   52,   52,   52,
    52,  171,  171,  171,  171,  171,  185,  171,  197,  150,
    221,  171,  186,  171,  170,  188,  209,  221,  143,   52,
    52,   52,   52,   52,   62,  196,  196,  196,  196,  196,
    62,   62,   62,   62,   62,   62,  235,  196,  198,  198,
    198,  198,  198,  215,  216,  218,  229,  142,  171,  197,
    
    198,  229,  230,  241,   62,   62,   62,   62,   62,   66,
    66,   66,   66,   66,  260,  215,  130,  264,  216,  218,
    66,  248,  249,  235,  129,  241,  261,   66,  227,  227,
    227,  227,  227,   66,   66,   66,   66,   66,   66,  234,
    227,  127,  229,  230,  248,  249,  265,  268,  234,  250,
    250,  250,  250,  250,  264,  260,   66,   66,   66,   66,
    66,   66,   73,   73,   73,   73,   73,  261,   73,  268,
    125,  122,  202,  202,  202,  202,  202,  270,  202,  271,
    73,  276,  202,  265,  202,  234,   73,   73,   73,   73,
    73,   73,  269,  269,  269,  269,  269,  113,  283,  103,
    
    270,  287,  271,  101,   99,  276,   98,   97,   96,   73,
    73,   73,   73,   73,   73,   74,   74,   74,   74,  202,
    283,   74,   95,  287,   93,   92,  203,  203,  203,  203,
    203,   90,  203,   74,   89,   87,  203,   85,  203,   74,
    74,   74,   74,   74,   74,   83,   75,   69,   63,   53,
    51,  288,  288,  288,  288,  288,   40,  288,   38,   37,
    35,   31,   74,   74,   74,   74,   74,   74,   76,   76,
    76,   76,   76,  203,   27,   21,   20,   15,   13,  204,
    204,  204,  204,  204,   12,  204,   76,    9,    7,  204,
    3,  204,   76,   76,   76,   76,   76,   76,  288,    0,
    
    0,    0,    0,    0,  289,  289,  289,  289,  289,    0,
    0,    0,    0,    0,  289,   76,   76,   76,   76,   76,
    76,   80,   80,   80,   80,   80,  204,    0,    0,    0,
    0,   80,  205,  205,  205,  205,  205,    0,  205,   80,
    0,    0,  205,    0,  205,   80,   80,   80,   80,   80,
    80,  289,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,   80,   80,
    80,   80,   80,   80,   81,   81,   81,   81,    0,  205,
    0,    0,    0,    0,   81,  231,  231,  231,  231,  231,
    0,  231,   81,    0,    0,    0,    0,  231,   81,   81,
    
    81,   81,   81,   81,  236,  236,  236,  236,  236,    0,
    0,    0,    0,    0,  236,    0,  236,    0,    0,    0,
    0,   81,   81,   81,   81,   81,   81,   86,    0,    0,
    0,    0,  231,   86,   86,   86,   86,   86,   86,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,  236,    0,    0,    0,    0,    0,   86,   86,   86,
    86,   86,  102,  102,  102,  102,  102,    0,    0,    0,
    0,    0,    0,  259,  259,  259,  259,  259,    0,  259,
    102,    0,    0,    0,    0,  259,  102,  102,  102,  102,
    102,  102,    0,    0,    0,    0,    0,    0,    0,    0,
    
    0,    0,    0,    0,    0,    0,    0,    0,    0,  102,
    102,  102,  102,  102,  102,  111,  111,  111,  111,  111,
    259,    0,  263,  263,  263,  263,  263,    0,    0,    0,
    0,    0,  263,  111,  263,    0,    0,    0,    0,  111,
    111,  111,  111,  111,  111,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,  111,  111,  111,  111,  111,  115,  263,
    0,    0,    0,    0,  115,  115,  115,  115,  115,  115,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,  115,  115,
    
    115,  115,  115,  118,    0,    0,    0,    0,    0,  118,
    118,  118,  118,  118,  118,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,  118,  118,  118,  118,  118,  119,    0,
    0,    0,    0,    0,  119,  119,  119,  119,  119,  119,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,  119,  119,
    119,  119,  119,  121,    0,    0,    0,    0,    0,  121,
    121,  121,  121,  121,  121,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    
    0,    0,    0,  121,  121,  121,  121,  121,  126,  126,
    126,  126,  126,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,  126,    0,    0,    0,
    0,    0,  126,  126,  126,  126,  126,  126,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,  126,  126,  126,  126,
    126,  131,    0,    0,    0,    0,    0,  131,  131,  131,
    131,  131,  131,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,  131,  131,  131,  131,  131,  139,    0,    0,    0,
    
    0,    0,  139,  139,  139,  139,  139,  139,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,  139,  139,  139,  139,
    139,  145,    0,    0,    0,    0,    0,  145,  145,  145,
    145,  145,  145,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,  145,  145,  145,  145,  145,  147,    0,    0,    0,
    0,    0,  147,  147,  147,  147,  147,  147,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,  147,  147,  147,  147,
    
    147,  148,    0,    0,    0,    0,    0,  148,  148,  148,
    148,  148,  148,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,  148,  148,  148,  148,  148,  149,    0,    0,    0,
    0,    0,  149,  149,  149,  149,  149,  149,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,  149,  149,  149,  149,
    149,  155,    0,    0,    0,    0,    0,  155,  155,  155,
    155,  155,  155,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    
    0,  155,  155,  155,  155,  155,  157,    0,    0,    0,
    0,    0,  157,  157,  157,  157,  157,  157,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,  157,  157,  157,  157,
    157,  164,    0,    0,    0,    0,    0,  164,  164,  164,
    164,  164,  164,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,  164,  164,  164,  164,  164,  175,  175,  175,  175,
    175,    0,  175,    0,    0,    0,  175,  175,  175,    0,
    0,    0,    0,    0,  175,    0,    0,    0,    0,    0,
    
    175,  175,  175,  175,  175,  175,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,  175,  175,  175,  175,  175,  175,  176,
    0,    0,    0,    0,    0,  176,  176,  176,  176,  176,
    176,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,  176,
    176,  176,  176,  176,  178,    0,    0,    0,    0,    0,
    178,  178,  178,  178,  178,  178,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,  178,  178,  178,  178,  178,  179,
    
    0,    0,    0,    0,    0,  179,  179,  179,  179,  179,
    179,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,  179,
    179,  179,  179,  179,  180,    0,    0,    0,    0,    0,
    180,  180,  180,  180,  180,  180,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,  180,  180,  180,  180,  180,  182,
    0,    0,    0,    0,    0,  182,  182,  182,  182,  182,
    182,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,  182,
    
    182,  182,  182,  182,  183,    0,    0,    0,    0,    0,
    183,  183,  183,  183,  183,  183,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,  183,  183,  183,  183,  183,  189,
    0,    0,    0,    0,    0,  189,  189,  189,  189,  189,
    189,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,  189,
    189,  189,  189,  189,  199,  199,  199,  199,    0,    0,
    199,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,  199,    0,    0,    0,    0,    0,  199,  199,
    
    199,  199,  199,  199,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,  199,  199,  199,  199,  199,  199,  201,  201,  201,
    201,    0,    0,    0,    0,    0,    0,  201,    0,    0,
    0,    0,    0,    0,    0,  201,    0,    0,    0,    0,
    0,  201,  201,  201,  201,  201,  201,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,  201,  201,  201,  201,  201,  201,
    206,  206,  206,  206,  206,    0,  206,    0,    0,    0,
    206,    0,  206,    0,    0,    0,    0,    0,  206,    0,
    
    0,    0,    0,    0,  206,  206,  206,  206,  206,  206,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,  206,  206,  206,
    206,  206,  206,  207,  207,  207,  207,  207,    0,  207,
    0,    0,    0,  207,  207,  207,    0,    0,    0,    0,
    0,  207,    0,    0,    0,    0,    0,  207,  207,  207,
    207,  207,  207,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    207,  207,  207,  207,  207,  207,  208,    0,    0,    0,
    0,    0,  208,  208,  208,  208,  208,  208,    0,    0,
    
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,  208,  208,  208,  208,
    208,  210,    0,    0,    0,    0,    0,  210,  210,  210,
    210,  210,  210,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,  210,  210,  210,  210,  210,  211,    0,    0,    0,
    0,    0,  211,  211,  211,  211,  211,  211,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,  211,  211,  211,  211,
    211,  212,    0,    0,    0,    0,    0,  212,  212,  212,
    
    212,  212,  212,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,  212,  212,  212,  212,  212,  213,    0,    0,    0,
    0,    0,  213,  213,  213,  213,  213,  213,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,  213,  213,  213,  213,
    213,  214,    0,    0,    0,    0,    0,  214,  214,  214,
    214,  214,  214,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,  214,  214,  214,  214,  214,  219,    0,    0,    0,
    
    0,    0,  219,  219,  219,  219,  219,  219,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,  219,  219,  219,  219,
    219,  232,  232,  232,  232,  232,    0,  232,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,  232,
    0,    0,    0,    0,    0,  232,  232,  232,  232,  232,
    232,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,  232,  232,
    232,  232,  232,  232,  233,  233,  233,  233,    0,    0,
    233,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    
    0,    0,  233,    0,    0,    0,    0,    0,  233,  233,
    233,  233,  233,  233,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,  233,  233,  233,  233,  233,  233,  237,  237,  237,
    237,  237,    0,    0,    0,    0,    0,  237,    0,    0,
    0,    0,    0,    0,    0,  237,    0,    0,    0,    0,
    0,  237,  237,  237,  237,  237,  237,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,  237,  237,  237,  237,  237,  237,
    238,  238,  238,  238,    0,    0,    0,    0,    0,    0,
    
    238,    0,    0,    0,    0,    0,    0,    0,  238,    0,
    0,    0,    0,    0,  238,  238,  238,  238,  238,  238,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,  238,  238,  238,
    238,  238,  238,  239,    0,    0,    0,    0,    0,  239,
    239,  239,  239,  239,  239,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,  239,  239,  239,  239,  239,  240,    0,
    0,    0,    0,    0,  240,  240,  240,  240,  240,  240,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    
    0,    0,    0,    0,    0,    0,    0,    0,  240,  240,
    240,  240,  240,  242,    0,    0,    0,    0,    0,  242,
    242,  242,  242,  242,  242,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,  242,  242,  242,  242,  242,  243,    0,
    0,    0,    0,    0,  243,  243,  243,  243,  243,  243,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,  243,  243,
    243,  243,  243,  244,    0,    0,    0,    0,    0,  244,
    244,  244,  244,  244,  244,    0,    0,    0,    0,    0,
    
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,  244,  244,  244,  244,  244,  245,    0,
    0,    0,    0,    0,  245,  245,  245,  245,  245,  245,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,  245,  245,
    245,  245,  245,  246,    0,    0,    0,    0,    0,  246,
    246,  246,  246,  246,  246,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,  246,  246,  246,  246,  246,  262,    0,
    0,    0,    0,    0,  262,  262,  262,  262,  262,  262,
    
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,  262,  262,
    262,  262,  262,  266,    0,    0,    0,    0,    0,  266,
    266,  266,  266,  266,  266,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,  266,  266,  266,  266,  266,  267,    0,
    0,    0,    0,    0,  267,  267,  267,  267,  267,  267,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,  267,  267,
    267,  267,  267,  273,    0,    0,    0,    0,    0,  273,
    
    273,  273,  273,  273,  273,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,  273,  273,  273,  273,  273,  274,    0,
    0,    0,    0,    0,  274,  274,  274,  274,  274,  274,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,  274,  274,
    274,  274,  274,  275,    0,    0,    0,    0,    0,  275,
    275,  275,  275,  275,  275,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,  275,  275,  275,  275,  275,  280,    0,
    
    0,    0,    0,    0,  280,  280,  280,  280,  280,  280,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,  280,  280,
    280,  280,  280,  281,    0,    0,    0,    0,    0,  281,
    281,  281,  281,  281,  281,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,  281,  281,  281,  281,  281,  282,    0,
    0,    0,    0,    0,  282,  282,  282,  282,  282,  282,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,  282,  282,
    
    282,  282,  282,  284,    0,    0,    0,    0,    0,  284,
    284,  284,  284,  284,  284,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,  284,  284,  284,  284,  284,  285,    0,
    0,    0,    0,    0,  285,  285,  285,  285,  285,  285,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,  285,  285,
    285,  285,  285,  286,    0,    0,    0,    0,    0,  286,
    286,  286,  286,  286,  286,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
    
    0,    0,    0,  286,  286,  286,  286,  286,  292,    0,
    292,  292,  292,  292,  292,  292,  292,  293,  293,    0,
    293,  293,  294,    0,  294,  294,  294,  294,  294,  294,
    294,  295,    0,    0,  295,  295,  296,  296,  296,    0,
    296,  296,  297,  297,  297,  297,  297,  297,  297,  298,
    298,  298,  298,  298,  298,  298,  298,  298,  299,  299,
    299,  299,  299,  299,  299,  300,  300,  300,  300,  300,
    300,  300,  300,  300,  301,  301,  301,  301,  301,  301,
    301,  301,  301,  301,  302,  302,  303,  303,    0,  303,
    303,  304,  304,  304,  304,  304,  304,  304,  305,  305,
    
    305,  305,  305,  305,  305,  306,  306,  306,  307,  307,
    307,  307,  307,  307,  307,  307,  307,  307,  308,  308,
    308,  308,  308,  308,  308,  309,  309,  309,  309,  310,
    310,  310,  310,  310,  310,  310,  310,  310,  310,  311,
    311,  311,  311,  311,  311,  311,  311,  311,  311,  312,
    0,  312,  313,  313,  313,  313,  314,  314,  314,    0,
    314,  314,  314,  314,  314,  315,    0,  315,  316,  316,
    316,  316,  317,    0,  317,  317,  317,  317,  317,  317,
    317,  318,    0,  318,  318,  318,  318,  318,  318,  318,
    319,  319,  319,  319,  319,  319,  319,  319,  319,  320,
    
    0,  320,  321,  321,  321,  321,  322,  322,  322,  322,
    322,  322,  322,  322,  322,  323,  323,  323,  323,  323,
    323,  323,  323,  323,  324,    0,  324,  325,  325,  325,
    325,  326,    0,  326,  327,    0,  327,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    
    291,  291,  291,  291,  291,  291,  291,  291,  291,  291,
    291,  291,  291
} ;

static yy_state_type yy_last_accepting_state;
static char *yy_last_accepting_cpos;

extern int refl_flex_debug;
int refl_flex_debug = 0;

/* The intent behind this definition is that it'll catch
 * any uses of REJECT which flex missed.
 */
#define REJECT reject_used_but_not_detected
#define yymore() yymore_used_but_not_detected
#define YY_MORE_ADJ 0
#define YY_RESTORE_YY_MORE_OFFSET
char *LESStext;
#line 1 "LESS.l"
/* http://www.w3.org/TR/LESS3-syntax/ */
#line 6 "LESS.l"

void refl_parse(const char* buffer) {
    refl_scan_bytes(buffer,strlen(buffer));
    LESSlex();
    refl_delete_buffer(YY_CURRENT_BUFFER);
}
int LESSwrap(void){ return 1;}
#line 1337 "lex.LESS.c"

#define INITIAL 0

#ifndef YY_NO_UNISTD_H
/* Special case for "unistd.h", since it is non-ANSI. We include it way
 * down here because we want the user's section 1 to have been scanned first.
 * The user has a chance to override it with an option.
 */
#include <unistd.h>
#endif

#ifndef YY_EXTRA_TYPE
#define YY_EXTRA_TYPE void *
#endif

static int yy_init_globals (void );

/* Accessor methods to globals.
 These are made visible to non-reentrant scanners for convenience. */

int LESSlex_destroy (void );

int LESSget_debug (void );

void LESSset_debug (int debug_flag  );

YY_EXTRA_TYPE LESSget_extra (void );

void LESSset_extra (YY_EXTRA_TYPE user_defined  );

FILE *LESSget_in (void );

void LESSset_in  (FILE * in_str  );

FILE *LESSget_out (void );

void LESSset_out  (FILE * out_str  );

yy_size_t LESSget_leng (void );

char *LESSget_text (void );

int LESSget_lineno (void );

void LESSset_lineno (int line_number  );

/* Macros after this point can all be overridden by user definitions in
 * section 1.
 */

#ifndef YY_SKIP_YYWRAP
#ifdef __cplusplus
extern "C" int LESSwrap (void );
#else
extern int LESSwrap (void );
#endif
#endif

#ifndef yytext_ptr
static void yy_flex_strncpy (char *,yyconst char *,int );
#endif

#ifdef YY_NEED_STRLEN
static int yy_flex_strlen (yyconst char * );
#endif

#ifndef YY_NO_INPUT

#ifdef __cplusplus
static int yyinput (void );
#else
static int input (void );
#endif

#endif

/* Amount of stuff to slurp up with each read. */
#ifndef YY_READ_BUF_SIZE
#define YY_READ_BUF_SIZE 8192
#endif

/* Copy whatever the last rule matched to the standard output. */
#ifndef ECHO
/* This used to be an fputs(), but since the string might contain NUL's,
 * we now use fwrite().
 */
#define ECHO fwrite( LESStext, LESSleng, 1, LESSout )
#endif

/* Gets input and stuffs it into "buf".  number of characters read, or YY_NULL,
 * is returned in "result".
 */
#ifndef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
if ( YY_CURRENT_BUFFER_LVALUE->yy_is_interactive ) \
{ \
int c = '*'; \
yy_size_t n; \
for ( n = 0; n < max_size && \
(c = getc( LESSin )) != EOF && c != '\n'; ++n ) \
buf[n] = (char) c; \
if ( c == '\n' ) \
buf[n++] = (char) c; \
if ( c == EOF && ferror( LESSin ) ) \
YY_FATAL_ERROR( "input in flex scanner failed" ); \
result = n; \
} \
else \
{ \
errno=0; \
while ( (result = fread(buf, 1, max_size, LESSin))==0 && ferror(LESSin)) \
{ \
if( errno != EINTR) \
{ \
YY_FATAL_ERROR( "input in flex scanner failed" ); \
break; \
} \
errno=0; \
clearerr(LESSin); \
} \
}\
\

#endif

/* No semi-colon after return; correct usage is to write "yyterminate();" -
 * we don't want an extra ';' after the "return" because that will cause
 * some compilers to complain about unreachable statements.
 */
#ifndef yyterminate
#define yyterminate() return YY_NULL
#endif

/* Number of entries by which start-condition stack grows. */
#ifndef YY_START_STACK_INCR
#define YY_START_STACK_INCR 25
#endif

/* Report a fatal error. */
#ifndef YY_FATAL_ERROR
#define YY_FATAL_ERROR(msg) yy_fatal_error( msg )
#endif

/* end tables serialization structures and prototypes */

/* Default declaration of generated scanner - a define so the user can
 * easily add parameters.
 */
#ifndef YY_DECL
#define YY_DECL_IS_OURS 1

extern int LESSlex (void);

#define YY_DECL int LESSlex (void)
#endif /* !YY_DECL */

/* Code executed at the beginning of each rule, after LESStext and LESSleng
 * have been set up.
 */
#ifndef YY_USER_ACTION
#define YY_USER_ACTION
#endif

/* Code executed at the end of each rule. */
#ifndef YY_BREAK
#define YY_BREAK break;
#endif

#define YY_RULE_SETUP \
YY_USER_ACTION

/** The main scanner function which does all the work.
 */
YY_DECL
{
    register yy_state_type yy_current_state;
    register char *yy_cp, *yy_bp;
    register int yy_act;
    
#line 33 "LESS.l"
    
    
#line 1520 "lex.LESS.c"
    
    if ( !(yy_init) )
    {
        (yy_init) = 1;
        
#ifdef YY_USER_INIT
        YY_USER_INIT;
#endif
        
        if ( ! (yy_start) )
            (yy_start) = 1;	/* first start state */
        
        if ( ! LESSin )
            LESSin = stdin;
        
        if ( ! LESSout )
            LESSout = stdout;
        
        if ( ! YY_CURRENT_BUFFER ) {
            LESSensure_buffer_stack ();
            YY_CURRENT_BUFFER_LVALUE =
            refl_create_buffer(LESSin,YY_BUF_SIZE );
        }
        
        refl_load_buffer_state( );
    }
    
    while ( 1 )		/* loops until end-of-file is reached */
    {
        yy_cp = (yy_c_buf_p);
        
        /* Support of LESStext. */
        *yy_cp = (yy_hold_char);
        
        /* yy_bp points to the position in yy_ch_buf of the start of
         * the current run.
         */
        yy_bp = yy_cp;
        
        yy_current_state = (yy_start);
    yy_match:
        do
        {
            register YY_CHAR yy_c = yy_ec[YY_SC_TO_UI(*yy_cp)];
            if ( yy_accept[yy_current_state] )
            {
                (yy_last_accepting_state) = yy_current_state;
                (yy_last_accepting_cpos) = yy_cp;
            }
            while ( yy_chk[yy_base[yy_current_state] + yy_c] != yy_current_state )
            {
                yy_current_state = (int) yy_def[yy_current_state];
                if ( yy_current_state >= 292 )
                    yy_c = yy_meta[(unsigned int) yy_c];
            }
            yy_current_state = yy_nxt[yy_base[yy_current_state] + (unsigned int) yy_c];
            ++yy_cp;
        }
        while ( yy_base[yy_current_state] != 3338 );
        
    yy_find_action:
        yy_act = yy_accept[yy_current_state];
        if ( yy_act == 0 )
        { /* have to back up */
            yy_cp = (yy_last_accepting_cpos);
            yy_current_state = (yy_last_accepting_state);
            yy_act = yy_accept[yy_current_state];
        }
        
        YY_DO_BEFORE_ACTION;
        
    do_action:	/* This label is used only to access EOF actions. */
        
        switch ( yy_act )
        { /* beginning of action switch */
            case 0: /* must back up */
                /* undo the effects of YY_DO_BEFORE_ACTION */
                *yy_cp = (yy_hold_char);
                yy_cp = (yy_last_accepting_cpos);
                yy_current_state = (yy_last_accepting_state);
                goto yy_find_action;
                
            case 1:
                /* rule 1 can match eol */
                YY_RULE_SETUP
#line 35 "LESS.l"
            { refl_scan(LESStext, S); }
                YY_BREAK
            case 2:
                /* rule 2 can match eol */
                YY_RULE_SETUP
#line 37 "LESS.l"
                /* ignore comments */
                YY_BREAK
            case 3:
                YY_RULE_SETUP
#line 39 "LESS.l"
            { refl_scan(LESStext, CDO); }
                YY_BREAK
            case 4:
                YY_RULE_SETUP
#line 40 "LESS.l"
            { refl_scan(LESStext, CDC); }
                YY_BREAK
            case 5:
                YY_RULE_SETUP
#line 41 "LESS.l"
            { refl_scan(LESStext, INCLUDES); }
                YY_BREAK
            case 6:
                YY_RULE_SETUP
#line 42 "LESS.l"
            { refl_scan(LESStext, DASHMATCH); }
                YY_BREAK
            case 7:
                /* rule 7 can match eol */
                YY_RULE_SETUP
#line 44 "LESS.l"
            { refl_scan(LESStext, STRING); }
                YY_BREAK
            case 8:
                /* rule 8 can match eol */
                YY_RULE_SETUP
#line 46 "LESS.l"
            { refl_scan(LESStext, IDENT); }
                YY_BREAK
            case 9:
                /* rule 9 can match eol */
                YY_RULE_SETUP
#line 48 "LESS.l"
            { refl_scan(LESStext, HASH); }
                YY_BREAK
            case 10:
                YY_RULE_SETUP
#line 50 "LESS.l"
            { refl_scan(LESStext, IMPORT_SYM); }
                YY_BREAK
            case 11:
                YY_RULE_SETUP
#line 51 "LESS.l"
            { refl_scan(LESStext, PAGE_SYM); }
                YY_BREAK
            case 12:
                YY_RULE_SETUP
#line 52 "LESS.l"
            { refl_scan(LESStext, MEDIA_SYM); }
                YY_BREAK
            case 13:
                YY_RULE_SETUP
#line 53 "LESS.l"
            { refl_scan(LESStext, FONT_FACE_SYM); }
                YY_BREAK
            case 14:
                YY_RULE_SETUP
#line 54 "LESS.l"
            { refl_scan(LESStext, CHARSET_SYM); }
                YY_BREAK
            case 15:
                YY_RULE_SETUP
#line 55 "LESS.l"
            { refl_scan(LESStext, NAMESPACE_SYM); }
                YY_BREAK
            case 16:
                YY_RULE_SETUP
#line 57 "LESS.l"
            { refl_scan(LESStext, IMPORTANT_SYM); }
                YY_BREAK
            case 17:
                YY_RULE_SETUP
#line 59 "LESS.l"
            { refl_scan(LESStext, EMS); }
                YY_BREAK
            case 18:
                YY_RULE_SETUP
#line 60 "LESS.l"
            { refl_scan(LESStext, EXS); }
                YY_BREAK
            case 19:
                YY_RULE_SETUP
#line 61 "LESS.l"
            { refl_scan(LESStext, LENGTH); }
                YY_BREAK
            case 20:
                YY_RULE_SETUP
#line 62 "LESS.l"
            { refl_scan(LESStext, LENGTH); }
                YY_BREAK
            case 21:
                YY_RULE_SETUP
#line 63 "LESS.l"
            { refl_scan(LESStext, LENGTH); }
                YY_BREAK
            case 22:
                YY_RULE_SETUP
#line 64 "LESS.l"
            { refl_scan(LESStext, LENGTH); }
                YY_BREAK
            case 23:
                YY_RULE_SETUP
#line 65 "LESS.l"
            { refl_scan(LESStext, LENGTH); }
                YY_BREAK
            case 24:
                YY_RULE_SETUP
#line 66 "LESS.l"
            { refl_scan(LESStext, LENGTH); }
                YY_BREAK
            case 25:
                YY_RULE_SETUP
#line 67 "LESS.l"
            { refl_scan(LESStext, ANGLE); }
                YY_BREAK
            case 26:
                YY_RULE_SETUP
#line 68 "LESS.l"
            { refl_scan(LESStext, ANGLE); }
                YY_BREAK
            case 27:
                YY_RULE_SETUP
#line 69 "LESS.l"
            { refl_scan(LESStext, ANGLE); }
                YY_BREAK
            case 28:
                YY_RULE_SETUP
#line 70 "LESS.l"
            { refl_scan(LESStext, TIME); }
                YY_BREAK
            case 29:
                YY_RULE_SETUP
#line 71 "LESS.l"
            { refl_scan(LESStext, TIME); }
                YY_BREAK
            case 30:
                YY_RULE_SETUP
#line 72 "LESS.l"
            { refl_scan(LESStext, FREQ); }
                YY_BREAK
            case 31:
                YY_RULE_SETUP
#line 73 "LESS.l"
            { refl_scan(LESStext, FREQ); }
                YY_BREAK
            case 32:
                /* rule 32 can match eol */
                YY_RULE_SETUP
#line 74 "LESS.l"
            { refl_scan(LESStext, DIMEN); }
                YY_BREAK
            case 33:
                YY_RULE_SETUP
#line 75 "LESS.l"
            { refl_scan(LESStext, PERCENTAGE); }
                YY_BREAK
            case 34:
                YY_RULE_SETUP
#line 76 "LESS.l"
            { refl_scan(LESStext, NUMBER); }
                YY_BREAK
            case 35:
                /* rule 35 can match eol */
                YY_RULE_SETUP
#line 78 "LESS.l"
            { refl_scan(LESStext, URI); }
                YY_BREAK
            case 36:
                /* rule 36 can match eol */
                YY_RULE_SETUP
#line 79 "LESS.l"
            { refl_scan(LESStext, URI); }
                YY_BREAK
            case 37:
                /* rule 37 can match eol */
                YY_RULE_SETUP
#line 80 "LESS.l"
            { refl_scan(LESStext, FUNCTION); }
                YY_BREAK
            case 38:
                YY_RULE_SETUP
#line 82 "LESS.l"
            { refl_scan(LESStext, UNICODERANGE); }
                YY_BREAK
            case 39:
                YY_RULE_SETUP
#line 83 "LESS.l"
            { refl_scan(LESStext, UNICODERANGE); }
                YY_BREAK
            case 40:
                YY_RULE_SETUP
#line 85 "LESS.l"
            { refl_scan(LESStext, UNKNOWN); }
                YY_BREAK
            case 41:
                YY_RULE_SETUP
#line 87 "LESS.l"
                ECHO;
                YY_BREAK
#line 1817 "lex.LESS.c"
            case YY_STATE_EOF(INITIAL):
                yyterminate();
                
            case YY_END_OF_BUFFER:
            {
                /* Amount of text matched not including the EOB char. */
                int yy_amount_of_matched_text = (int) (yy_cp - (yytext_ptr)) - 1;
                
                /* Undo the effects of YY_DO_BEFORE_ACTION. */
                *yy_cp = (yy_hold_char);
                YY_RESTORE_YY_MORE_OFFSET
                
                if ( YY_CURRENT_BUFFER_LVALUE->yy_buffer_status == YY_BUFFER_NEW )
                {
                    /* We're scanning a new file or input source.  It's
                     * possible that this happened because the user
                     * just pointed LESSin at a new source and called
                     * LESSlex().  If so, then we have to assure
                     * consistency between YY_CURRENT_BUFFER and our
                     * globals.  Here is the right place to do so, because
                     * this is the first action (other than possibly a
                     * back-up) that will match for the new input source.
                     */
                    (yy_n_chars) = YY_CURRENT_BUFFER_LVALUE->yy_n_chars;
                    YY_CURRENT_BUFFER_LVALUE->yy_input_file = LESSin;
                    YY_CURRENT_BUFFER_LVALUE->yy_buffer_status = YY_BUFFER_NORMAL;
                }
                
                /* Note that here we test for yy_c_buf_p "<=" to the position
                 * of the first EOB in the buffer, since yy_c_buf_p will
                 * already have been incremented past the NUL character
                 * (since all states make transitions on EOB to the
                 * end-of-buffer state).  Contrast this with the test
                 * in input().
                 */
                if ( (yy_c_buf_p) <= &YY_CURRENT_BUFFER_LVALUE->yy_ch_buf[(yy_n_chars)] )
                { /* This was really a NUL. */
                    yy_state_type yy_next_state;
                    
                    (yy_c_buf_p) = (yytext_ptr) + yy_amount_of_matched_text;
                    
                    yy_current_state = yy_get_previous_state(  );
                    
                    /* Okay, we're now positioned to make the NUL
                     * transition.  We couldn't have
                     * yy_get_previous_state() go ahead and do it
                     * for us because it doesn't know how to deal
                     * with the possibility of jamming (and we don't
                     * want to build jamming into it because then it
                     * will run more slowly).
                     */
                    
                    yy_next_state = yy_try_NUL_trans( yy_current_state );
                    
                    yy_bp = (yytext_ptr) + YY_MORE_ADJ;
                    
                    if ( yy_next_state )
                    {
                        /* Consume the NUL. */
                        yy_cp = ++(yy_c_buf_p);
                        yy_current_state = yy_next_state;
                        goto yy_match;
                    }
                    
                    else
                    {
                        yy_cp = (yy_c_buf_p);
                        goto yy_find_action;
                    }
                }
                
                else switch ( yy_get_next_buffer(  ) )
                {
                    case EOB_ACT_END_OF_FILE:
                    {
                        (yy_did_buffer_switch_on_eof) = 0;
                        
                        if ( LESSwrap( ) )
                        {
                            /* Note: because we've taken care in
                             * yy_get_next_buffer() to have set up
                             * LESStext, we can now set up
                             * yy_c_buf_p so that if some total
                             * hoser (like flex itself) wants to
                             * call the scanner after we return the
                             * YY_NULL, it'll still work - another
                             * YY_NULL will get returned.
                             */
                            (yy_c_buf_p) = (yytext_ptr) + YY_MORE_ADJ;
                            
                            yy_act = YY_STATE_EOF(YY_START);
                            goto do_action;
                        }
                        
                        else
                        {
                            if ( ! (yy_did_buffer_switch_on_eof) )
                                YY_NEW_FILE;
                        }
                        break;
                    }
                        
                    case EOB_ACT_CONTINUE_SCAN:
                        (yy_c_buf_p) =
                        (yytext_ptr) + yy_amount_of_matched_text;
                        
                        yy_current_state = yy_get_previous_state(  );
                        
                        yy_cp = (yy_c_buf_p);
                        yy_bp = (yytext_ptr) + YY_MORE_ADJ;
                        goto yy_match;
                        
                    case EOB_ACT_LAST_MATCH:
                        (yy_c_buf_p) =
                        &YY_CURRENT_BUFFER_LVALUE->yy_ch_buf[(yy_n_chars)];
                        
                        yy_current_state = yy_get_previous_state(  );
                        
                        yy_cp = (yy_c_buf_p);
                        yy_bp = (yytext_ptr) + YY_MORE_ADJ;
                        goto yy_find_action;
                }
                break;
            }
                
            default:
                YY_FATAL_ERROR(
                               "fatal flex scanner internal error--no action found" );
        } /* end of action switch */
    } /* end of scanning one token */
} /* end of LESSlex */

/* yy_get_next_buffer - try to read in a new buffer
 *
 * Returns a code representing an action:
 *	EOB_ACT_LAST_MATCH -
 *	EOB_ACT_CONTINUE_SCAN - continue scanning from current position
 *	EOB_ACT_END_OF_FILE - end of file
 */
static int yy_get_next_buffer (void)
{
    register char *dest = YY_CURRENT_BUFFER_LVALUE->yy_ch_buf;
    register char *source = (yytext_ptr);
    register int number_to_move, i;
    int ret_val;
    
    if ( (yy_c_buf_p) > &YY_CURRENT_BUFFER_LVALUE->yy_ch_buf[(yy_n_chars) + 1] )
        YY_FATAL_ERROR(
                       "fatal flex scanner internal error--end of buffer missed" );
    
    if ( YY_CURRENT_BUFFER_LVALUE->yy_fill_buffer == 0 )
    { /* Don't try to fill the buffer, so this is an EOF. */
        if ( (yy_c_buf_p) - (yytext_ptr) - YY_MORE_ADJ == 1 )
        {
            /* We matched a single character, the EOB, so
             * treat this as a final EOF.
             */
            return EOB_ACT_END_OF_FILE;
        }
        
        else
        {
            /* We matched some text prior to the EOB, first
             * process it.
             */
            return EOB_ACT_LAST_MATCH;
        }
    }
    
    /* Try to read more data. */
    
    /* First move last chars to start of buffer. */
    number_to_move = (int) ((yy_c_buf_p) - (yytext_ptr)) - 1;
    
    for ( i = 0; i < number_to_move; ++i )
        *(dest++) = *(source++);
    
    if ( YY_CURRENT_BUFFER_LVALUE->yy_buffer_status == YY_BUFFER_EOF_PENDING )
    /* don't do the read, it's not guaranteed to return an EOF,
     * just force an EOF
     */
        YY_CURRENT_BUFFER_LVALUE->yy_n_chars = (yy_n_chars) = 0;
    
    else
    {
        yy_size_t num_to_read =
        YY_CURRENT_BUFFER_LVALUE->yy_buf_size - number_to_move - 1;
        
        while ( num_to_read <= 0 )
        { /* Not enough room in the buffer - grow it. */
            
            /* just a shorter name for the current buffer */
            YY_BUFFER_STATE b = YY_CURRENT_BUFFER;
            
            int yy_c_buf_p_offset =
            (int) ((yy_c_buf_p) - b->yy_ch_buf);
            
            if ( b->yy_is_our_buffer )
            {
                yy_size_t new_size = b->yy_buf_size * 2;
                
                if ( new_size <= 0 )
                    b->yy_buf_size += b->yy_buf_size / 8;
                else
                    b->yy_buf_size *= 2;
                
                b->yy_ch_buf = (char *)
                /* Include room in for 2 EOB chars. */
                LESSrealloc((void *) b->yy_ch_buf,b->yy_buf_size + 2  );
            }
            else
            /* Can't grow it, we don't own it. */
                b->yy_ch_buf = 0;
            
            if ( ! b->yy_ch_buf )
                YY_FATAL_ERROR(
                               "fatal error - scanner input buffer overflow" );
            
            (yy_c_buf_p) = &b->yy_ch_buf[yy_c_buf_p_offset];
            
            num_to_read = YY_CURRENT_BUFFER_LVALUE->yy_buf_size -
            number_to_move - 1;
            
        }
        
        if ( num_to_read > YY_READ_BUF_SIZE )
            num_to_read = YY_READ_BUF_SIZE;
        
        /* Read in more data. */
        YY_INPUT( (&YY_CURRENT_BUFFER_LVALUE->yy_ch_buf[number_to_move]),
                 (yy_n_chars), num_to_read );
        
        YY_CURRENT_BUFFER_LVALUE->yy_n_chars = (yy_n_chars);
    }
    
    if ( (yy_n_chars) == 0 )
    {
        if ( number_to_move == YY_MORE_ADJ )
        {
            ret_val = EOB_ACT_END_OF_FILE;
            LESSrestart(LESSin  );
        }
        
        else
        {
            ret_val = EOB_ACT_LAST_MATCH;
            YY_CURRENT_BUFFER_LVALUE->yy_buffer_status =
            YY_BUFFER_EOF_PENDING;
        }
    }
    
    else
        ret_val = EOB_ACT_CONTINUE_SCAN;
    
    if ((yy_size_t) ((yy_n_chars) + number_to_move) > YY_CURRENT_BUFFER_LVALUE->yy_buf_size) {
        /* Extend the array by 50%, plus the number we really need. */
        yy_size_t new_size = (yy_n_chars) + number_to_move + ((yy_n_chars) >> 1);
        YY_CURRENT_BUFFER_LVALUE->yy_ch_buf = (char *) LESSrealloc((void *) YY_CURRENT_BUFFER_LVALUE->yy_ch_buf,new_size  );
        if ( ! YY_CURRENT_BUFFER_LVALUE->yy_ch_buf )
            YY_FATAL_ERROR( "out of dynamic memory in yy_get_next_buffer()" );
    }
    
    (yy_n_chars) += number_to_move;
    YY_CURRENT_BUFFER_LVALUE->yy_ch_buf[(yy_n_chars)] = YY_END_OF_BUFFER_CHAR;
    YY_CURRENT_BUFFER_LVALUE->yy_ch_buf[(yy_n_chars) + 1] = YY_END_OF_BUFFER_CHAR;
    
    (yytext_ptr) = &YY_CURRENT_BUFFER_LVALUE->yy_ch_buf[0];
    
    return ret_val;
}

/* yy_get_previous_state - get the state just before the EOB char was reached */

static yy_state_type yy_get_previous_state (void)
{
    register yy_state_type yy_current_state;
    register char *yy_cp;
    
    yy_current_state = (yy_start);
    
    for ( yy_cp = (yytext_ptr) + YY_MORE_ADJ; yy_cp < (yy_c_buf_p); ++yy_cp )
    {
        register YY_CHAR yy_c = (*yy_cp ? yy_ec[YY_SC_TO_UI(*yy_cp)] : 1);
        if ( yy_accept[yy_current_state] )
        {
            (yy_last_accepting_state) = yy_current_state;
            (yy_last_accepting_cpos) = yy_cp;
        }
        while ( yy_chk[yy_base[yy_current_state] + yy_c] != yy_current_state )
        {
            yy_current_state = (int) yy_def[yy_current_state];
            if ( yy_current_state >= 292 )
                yy_c = yy_meta[(unsigned int) yy_c];
        }
        yy_current_state = yy_nxt[yy_base[yy_current_state] + (unsigned int) yy_c];
    }
    
    return yy_current_state;
}

/* yy_try_NUL_trans - try to make a transition on the NUL character
 *
 * synopsis
 *	next_state = yy_try_NUL_trans( current_state );
 */
static yy_state_type yy_try_NUL_trans  (yy_state_type yy_current_state )
{
    register int yy_is_jam;
    register char *yy_cp = (yy_c_buf_p);
    
    register YY_CHAR yy_c = 1;
    if ( yy_accept[yy_current_state] )
    {
        (yy_last_accepting_state) = yy_current_state;
        (yy_last_accepting_cpos) = yy_cp;
    }
    while ( yy_chk[yy_base[yy_current_state] + yy_c] != yy_current_state )
    {
        yy_current_state = (int) yy_def[yy_current_state];
        if ( yy_current_state >= 292 )
            yy_c = yy_meta[(unsigned int) yy_c];
    }
    yy_current_state = yy_nxt[yy_base[yy_current_state] + (unsigned int) yy_c];
    yy_is_jam = (yy_current_state == 291);
    
    return yy_is_jam ? 0 : yy_current_state;
}

#ifndef YY_NO_INPUT
#ifdef __cplusplus
static int yyinput (void)
#else
static int input  (void)
#endif

{
    int c;
    
    *(yy_c_buf_p) = (yy_hold_char);
    
    if ( *(yy_c_buf_p) == YY_END_OF_BUFFER_CHAR )
    {
        /* yy_c_buf_p now points to the character we want to return.
         * If this occurs *before* the EOB characters, then it's a
         * valid NUL; if not, then we've hit the end of the buffer.
         */
        if ( (yy_c_buf_p) < &YY_CURRENT_BUFFER_LVALUE->yy_ch_buf[(yy_n_chars)] )
        /* This was really a NUL. */
            *(yy_c_buf_p) = '\0';
        
        else
        { /* need more input */
            yy_size_t offset = (yy_c_buf_p) - (yytext_ptr);
            ++(yy_c_buf_p);
            
            switch ( yy_get_next_buffer(  ) )
            {
                case EOB_ACT_LAST_MATCH:
                    /* This happens because yy_g_n_b()
                     * sees that we've accumulated a
                     * token and flags that we need to
                     * try matching the token before
                     * proceeding.  But for input(),
                     * there's no matching to consider.
                     * So convert the EOB_ACT_LAST_MATCH
                     * to EOB_ACT_END_OF_FILE.
                     */
                    
                    /* Reset buffer status. */
                    LESSrestart(LESSin );
                    
                    /*FALLTHROUGH*/
                    
                case EOB_ACT_END_OF_FILE:
                {
                    if ( LESSwrap( ) )
                        return 0;
                    
                    if ( ! (yy_did_buffer_switch_on_eof) )
                        YY_NEW_FILE;
#ifdef __cplusplus
                    return yyinput();
#else
                    return input();
#endif
                }
                    
                case EOB_ACT_CONTINUE_SCAN:
                    (yy_c_buf_p) = (yytext_ptr) + offset;
                    break;
            }
        }
    }
    
    c = *(unsigned char *) (yy_c_buf_p);	/* cast for 8-bit char's */
    *(yy_c_buf_p) = '\0';	/* preserve LESStext */
    (yy_hold_char) = *++(yy_c_buf_p);
    
    return c;
}
#endif	/* ifndef YY_NO_INPUT */

/** Immediately switch to a different input stream.
 * @param input_file A readable stream.
 *
 * @note This function does not reset the start condition to @c INITIAL .
 */
void LESSrestart  (FILE * input_file )
{
    
    if ( ! YY_CURRENT_BUFFER ){
        LESSensure_buffer_stack ();
        YY_CURRENT_BUFFER_LVALUE =
        refl_create_buffer(LESSin,YY_BUF_SIZE );
    }
    
    refl_init_buffer(YY_CURRENT_BUFFER,input_file );
    refl_load_buffer_state( );
}

/** Switch to a different input buffer.
 * @param new_buffer The new input buffer.
 *
 */
void refl_switch_to_buffer  (YY_BUFFER_STATE  new_buffer )
{
    
    /* TODO. We should be able to replace this entire function body
     * with
     *		LESSpop_buffer_state();
     *		LESSpush_buffer_state(new_buffer);
     */
    LESSensure_buffer_stack ();
    if ( YY_CURRENT_BUFFER == new_buffer )
        return;
    
    if ( YY_CURRENT_BUFFER )
    {
        /* Flush out information for old buffer. */
        *(yy_c_buf_p) = (yy_hold_char);
        YY_CURRENT_BUFFER_LVALUE->yy_buf_pos = (yy_c_buf_p);
        YY_CURRENT_BUFFER_LVALUE->yy_n_chars = (yy_n_chars);
    }
    
    YY_CURRENT_BUFFER_LVALUE = new_buffer;
    refl_load_buffer_state( );
    
    /* We don't actually know whether we did this switch during
     * EOF (LESSwrap()) processing, but the only time this flag
     * is looked at is after LESSwrap() is called, so it's safe
     * to go ahead and always set it.
     */
    (yy_did_buffer_switch_on_eof) = 1;
}

static void refl_load_buffer_state  (void)
{
    (yy_n_chars) = YY_CURRENT_BUFFER_LVALUE->yy_n_chars;
    (yytext_ptr) = (yy_c_buf_p) = YY_CURRENT_BUFFER_LVALUE->yy_buf_pos;
    LESSin = YY_CURRENT_BUFFER_LVALUE->yy_input_file;
    (yy_hold_char) = *(yy_c_buf_p);
}

/** Allocate and initialize an input buffer state.
 * @param file A readable stream.
 * @param size The character buffer size in bytes. When in doubt, use @c YY_BUF_SIZE.
 *
 * @return the allocated buffer state.
 */
YY_BUFFER_STATE refl_create_buffer  (FILE * file, int  size )
{
    YY_BUFFER_STATE b;
    
    b = (YY_BUFFER_STATE) LESSalloc(sizeof( struct yy_buffer_state )  );
    if ( ! b )
        YY_FATAL_ERROR( "out of dynamic memory in refl_create_buffer()" );
    
    b->yy_buf_size = size;
    
    /* yy_ch_buf has to be 2 characters longer than the size given because
     * we need to put in 2 end-of-buffer characters.
     */
    b->yy_ch_buf = (char *) LESSalloc(b->yy_buf_size + 2  );
    if ( ! b->yy_ch_buf )
        YY_FATAL_ERROR( "out of dynamic memory in refl_create_buffer()" );
    
    b->yy_is_our_buffer = 1;
    
    refl_init_buffer(b,file );
    
    return b;
}

/** Destroy the buffer.
 * @param b a buffer created with refl_create_buffer()
 *
 */
void refl_delete_buffer (YY_BUFFER_STATE  b )
{
    
    if ( ! b )
        return;
    
    if ( b == YY_CURRENT_BUFFER ) /* Not sure if we should pop here. */
        YY_CURRENT_BUFFER_LVALUE = (YY_BUFFER_STATE) 0;
    
    if ( b->yy_is_our_buffer )
        LESSfree((void *) b->yy_ch_buf  );
    
    LESSfree((void *) b  );
}

#ifndef __cplusplus
extern int isatty (int );
#endif /* __cplusplus */

/* Initializes or reinitializes a buffer.
 * This function is sometimes called more than once on the same buffer,
 * such as during a LESSrestart() or at EOF.
 */
static void refl_init_buffer  (YY_BUFFER_STATE  b, FILE * file )

{
    int oerrno = errno;
    
    refl_flush_buffer(b );
    
    b->yy_input_file = file;
    b->yy_fill_buffer = 1;
    
    /* If b is the current buffer, then refl_init_buffer was _probably_
     * called from LESSrestart() or through yy_get_next_buffer.
     * In that case, we don't want to reset the lineno or column.
     */
    if (b != YY_CURRENT_BUFFER){
        b->yy_bs_lineno = 1;
        b->yy_bs_column = 0;
    }
    
    b->yy_is_interactive = file ? (isatty( fileno(file) ) > 0) : 0;
    
    errno = oerrno;
}

/** Discard all buffered characters. On the next scan, YY_INPUT will be called.
 * @param b the buffer state to be flushed, usually @c YY_CURRENT_BUFFER.
 *
 */
void refl_flush_buffer (YY_BUFFER_STATE  b )
{
    if ( ! b )
        return;
    
    b->yy_n_chars = 0;
    
    /* We always need two end-of-buffer characters.  The first causes
     * a transition to the end-of-buffer state.  The second causes
     * a jam in that state.
     */
    b->yy_ch_buf[0] = YY_END_OF_BUFFER_CHAR;
    b->yy_ch_buf[1] = YY_END_OF_BUFFER_CHAR;
    
    b->yy_buf_pos = &b->yy_ch_buf[0];
    
    b->yy_at_bol = 1;
    b->yy_buffer_status = YY_BUFFER_NEW;
    
    if ( b == YY_CURRENT_BUFFER )
        refl_load_buffer_state( );
}

/** Pushes the new state onto the stack. The new state becomes
 *  the current state. This function will allocate the stack
 *  if necessary.
 *  @param new_buffer The new state.
 *
 */
void LESSpush_buffer_state (YY_BUFFER_STATE new_buffer )
{
    if (new_buffer == NULL)
        return;
    
    LESSensure_buffer_stack();
    
    /* This block is copied from refl_switch_to_buffer. */
    if ( YY_CURRENT_BUFFER )
    {
        /* Flush out information for old buffer. */
        *(yy_c_buf_p) = (yy_hold_char);
        YY_CURRENT_BUFFER_LVALUE->yy_buf_pos = (yy_c_buf_p);
        YY_CURRENT_BUFFER_LVALUE->yy_n_chars = (yy_n_chars);
    }
    
    /* Only push if top exists. Otherwise, replace top. */
    if (YY_CURRENT_BUFFER)
        (yy_buffer_stack_top)++;
    YY_CURRENT_BUFFER_LVALUE = new_buffer;
    
    /* copied from refl_switch_to_buffer. */
    refl_load_buffer_state( );
    (yy_did_buffer_switch_on_eof) = 1;
}

/** Removes and deletes the top of the stack, if present.
 *  The next element becomes the new top.
 *
 */
void LESSpop_buffer_state (void)
{
    if (!YY_CURRENT_BUFFER)
        return;
    
    refl_delete_buffer(YY_CURRENT_BUFFER );
    YY_CURRENT_BUFFER_LVALUE = NULL;
    if ((yy_buffer_stack_top) > 0)
        --(yy_buffer_stack_top);
    
    if (YY_CURRENT_BUFFER) {
        refl_load_buffer_state( );
        (yy_did_buffer_switch_on_eof) = 1;
    }
}

/* Allocates the stack if it does not exist.
 *  Guarantees space for at least one push.
 */
static void LESSensure_buffer_stack (void)
{
    yy_size_t num_to_alloc;
    
    if (!(yy_buffer_stack)) {
        
        /* First allocation is just for 2 elements, since we don't know if this
         * scanner will even need a stack. We use 2 instead of 1 to avoid an
         * immediate realloc on the next call.
         */
        num_to_alloc = 1;
        (yy_buffer_stack) = (struct yy_buffer_state**)LESSalloc
								(num_to_alloc * sizeof(struct yy_buffer_state*)
                                 );
        if ( ! (yy_buffer_stack) )
            YY_FATAL_ERROR( "out of dynamic memory in LESSensure_buffer_stack()" );
        
        memset((yy_buffer_stack), 0, num_to_alloc * sizeof(struct yy_buffer_state*));
        
        (yy_buffer_stack_max) = num_to_alloc;
        (yy_buffer_stack_top) = 0;
        return;
    }
    
    if ((yy_buffer_stack_top) >= ((yy_buffer_stack_max)) - 1){
        
        /* Increase the buffer to prepare for a possible push. */
        int grow_size = 8 /* arbitrary grow size */;
        
        num_to_alloc = (yy_buffer_stack_max) + grow_size;
        (yy_buffer_stack) = (struct yy_buffer_state**)LESSrealloc
								((yy_buffer_stack),
                                 num_to_alloc * sizeof(struct yy_buffer_state*)
                                 );
        if ( ! (yy_buffer_stack) )
            YY_FATAL_ERROR( "out of dynamic memory in LESSensure_buffer_stack()" );
        
        /* zero only the new slots.*/
        memset((yy_buffer_stack) + (yy_buffer_stack_max), 0, grow_size * sizeof(struct yy_buffer_state*));
        (yy_buffer_stack_max) = num_to_alloc;
    }
}

/** Setup the input buffer state to scan directly from a user-specified character buffer.
 * @param base the character buffer
 * @param size the size in bytes of the character buffer
 *
 * @return the newly allocated buffer state object.
 */
YY_BUFFER_STATE refl_scan_buffer  (char * base, yy_size_t  size )
{
    YY_BUFFER_STATE b;
    
    if ( size < 2 ||
        base[size-2] != YY_END_OF_BUFFER_CHAR ||
        base[size-1] != YY_END_OF_BUFFER_CHAR )
    /* They forgot to leave room for the EOB's. */
        return 0;
    
    b = (YY_BUFFER_STATE) LESSalloc(sizeof( struct yy_buffer_state )  );
    if ( ! b )
        YY_FATAL_ERROR( "out of dynamic memory in refl_scan_buffer()" );
    
    b->yy_buf_size = size - 2;	/* "- 2" to take care of EOB's */
    b->yy_buf_pos = b->yy_ch_buf = base;
    b->yy_is_our_buffer = 0;
    b->yy_input_file = 0;
    b->yy_n_chars = b->yy_buf_size;
    b->yy_is_interactive = 0;
    b->yy_at_bol = 1;
    b->yy_fill_buffer = 0;
    b->yy_buffer_status = YY_BUFFER_NEW;
    
    refl_switch_to_buffer(b  );
    
    return b;
}

/** Setup the input buffer state to scan a string. The next call to LESSlex() will
 * scan from a @e copy of @a str.
 * @param yystr a NUL-terminated string to scan
 * 
 * @return the newly allocated buffer state object.
 * @note If you want to scan bytes that may contain NUL values, then use
 *       refl_scan_bytes() instead.
 */
YY_BUFFER_STATE refl_scan_string (yyconst char * yystr )
{
    
    return refl_scan_bytes(yystr,strlen(yystr) );
}

/** Setup the input buffer state to scan the given bytes. The next call to LESSlex() will
 * scan from a @e copy of @a bytes.
 * @param bytes the byte buffer to scan
 * @param len the number of bytes in the buffer pointed to by @a bytes.
 * 
 * @return the newly allocated buffer state object.
 */
YY_BUFFER_STATE refl_scan_bytes  (yyconst char * yybytes, yy_size_t  _yybytes_len )
{
    YY_BUFFER_STATE b;
    char *buf;
    yy_size_t n, i;
    
    /* Get memory for full buffer, including space for trailing EOB's. */
    n = _yybytes_len + 2;
    buf = (char *) LESSalloc(n  );
    if ( ! buf )
        YY_FATAL_ERROR( "out of dynamic memory in refl_scan_bytes()" );
    
    for ( i = 0; i < _yybytes_len; ++i )
        buf[i] = yybytes[i];
    
    buf[_yybytes_len] = buf[_yybytes_len+1] = YY_END_OF_BUFFER_CHAR;
    
    b = refl_scan_buffer(buf,n );
    if ( ! b )
        YY_FATAL_ERROR( "bad buffer in refl_scan_bytes()" );
    
    /* It's okay to grow etc. this buffer, and we should throw it
     * away when we're done.
     */
    b->yy_is_our_buffer = 1;
    
    return b;
}

#ifndef YY_EXIT_FAILURE
#define YY_EXIT_FAILURE 2
#endif

static void yy_fatal_error (yyconst char* msg )
{
    (void) fprintf( stderr, "%s\n", msg );
    exit( YY_EXIT_FAILURE );
}

/* Redefine yyless() so it works in section 3 code. */

#undef yyless
#define yyless(n) \
do \
{ \
/* Undo effects of setting up LESStext. */ \
int yyrefl_macro_arg = (n); \
YY_refl_LINENO(yyrefl_macro_arg);\
LESStext[LESSleng] = (yy_hold_char); \
(yy_c_buf_p) = LESStext + yyrefl_macro_arg; \
(yy_hold_char) = *(yy_c_buf_p); \
*(yy_c_buf_p) = '\0'; \
LESSleng = yyrefl_macro_arg; \
} \
while ( 0 )

/* Accessor  methods (get/set functions) to struct members. */

/** Get the current line number.
 * 
 */
int LESSget_lineno  (void)
{
    
    return LESSlineno;
}

/** Get the input stream.
 * 
 */
FILE *LESSget_in  (void)
{
    return LESSin;
}

/** Get the output stream.
 * 
 */
FILE *LESSget_out  (void)
{
    return LESSout;
}

/** Get the length of the current token.
 * 
 */
yy_size_t LESSget_leng  (void)
{
    return LESSleng;
}

/** Get the current token.
 * 
 */

char *LESSget_text  (void)
{
    return LESStext;
}

/** Set the current line number.
 * @param line_number
 * 
 */
void LESSset_lineno (int  line_number )
{
    
    LESSlineno = line_number;
}

/** Set the input stream. This does not discard the current
 * input buffer.
 * @param in_str A readable stream.
 * 
 * @see refl_switch_to_buffer
 */
void LESSset_in (FILE *  in_str )
{
    LESSin = in_str ;
}

void LESSset_out (FILE *  out_str )
{
    LESSout = out_str ;
}

int LESSget_debug  (void)
{
    return refl_flex_debug;
}

void LESSset_debug (int  bdebug )
{
    refl_flex_debug = bdebug ;
}

static int yy_init_globals (void)
{
    /* Initialization is the same as for the non-reentrant scanner.
     * This function is called from LESSlex_destroy(), so don't allocate here.
     */
    
    (yy_buffer_stack) = 0;
    (yy_buffer_stack_top) = 0;
    (yy_buffer_stack_max) = 0;
    (yy_c_buf_p) = (char *) 0;
    (yy_init) = 0;
    (yy_start) = 0;
    
    /* Defined in main.c */
#ifdef YY_STDINIT
    LESSin = stdin;
    LESSout = stdout;
#else
    LESSin = (FILE *) 0;
    LESSout = (FILE *) 0;
#endif
    
    /* For future reference: Set errno on error, since we are called by
     * LESSlex_init()
     */
    return 0;
}

/* LESSlex_destroy is for both reentrant and non-reentrant scanners. */
int LESSlex_destroy  (void)
{
    
    /* Pop the buffer stack, destroying each element. */
    while(YY_CURRENT_BUFFER){
        refl_delete_buffer(YY_CURRENT_BUFFER  );
        YY_CURRENT_BUFFER_LVALUE = NULL;
        LESSpop_buffer_state();
    }
    
    /* Destroy the stack itself. */
    LESSfree((yy_buffer_stack) );
    (yy_buffer_stack) = NULL;
    
    /* Reset the globals. This is important in a non-reentrant scanner so the next time
     * LESSlex() is called, initialization will occur. */
    yy_init_globals( );
    
    return 0;
}

/*
 * Internal utility routines.
 */

#ifndef yytext_ptr
static void yy_flex_strncpy (char* s1, yyconst char * s2, int n )
{
    register int i;
    for ( i = 0; i < n; ++i )
        s1[i] = s2[i];
}
#endif

#ifdef YY_NEED_STRLEN
static int yy_flex_strlen (yyconst char * s )
{
    register int n;
    for ( n = 0; s[n]; ++n )
        ;
    
    return n;
}
#endif

void *LESSalloc (yy_size_t  size )
{
    return (void *) malloc( size );
}

void *LESSrealloc  (void * ptr, yy_size_t  size )
{
    /* The cast to (char *) in the following accommodates both
     * implementations that use char* generic pointers, and those
     * that use void* generic pointers.  It works with the latter
     * because both ANSI C and C++ allow castless assignment from
     * any pointer type to void*, and deal with argument conversions
     * as though doing an assignment.
     */
    return (void *) realloc( (char *) ptr, size );
}

void LESSfree (void * ptr )
{
    free( (char *) ptr );	/* see LESSrealloc() for (char *) cast */
}

#define YYTABLES_NAME "yytables"

#line 87 "LESS.l"



