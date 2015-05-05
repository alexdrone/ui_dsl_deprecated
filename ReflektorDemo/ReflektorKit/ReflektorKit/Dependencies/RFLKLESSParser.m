//
//  RFLKLESSParser.m
//  Tests
//  Forked from https://github.com/tracy-e/ESCssParser
//
//

#import "RFLKLESSParser.h"
#include "RFLKLESSTokens.h"

static RFLKLESSParser *__currentParser = nil;

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

@interface RFLKLESSParser () {
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

- (void)RFLKLESSScan:(const char *)text token:(int)token;

@end

void RFLKLESS_scan(const char *text, int token) {
    [__currentParser RFLKLESSScan:text token:token];
}


@implementation RFLKLESSParser

- (instancetype)init {
    self = [super init];
    if (self) {
        _activeSelector = [[NSMutableString alloc] init];
        _styleSheet = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)RFLKLESSScan:(const char *)text token:(int)token {
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
                    printf("[%s] (%s)", text, RFLKLESSTokenName[token]);
                    break;
            }
            break;
        }
        default:
            printf("[%s] (%s)", text, RFLKLESSTokenName[token]);
            break;
    }
    _state.lastToken = token;
    
}

- (NSDictionary *)parseText:(NSString *)RFLKLESSText {
    __currentParser = self;
    RFLKLESS_parse([RFLKLESSText UTF8String]);
    return _styleSheet;
}

@end