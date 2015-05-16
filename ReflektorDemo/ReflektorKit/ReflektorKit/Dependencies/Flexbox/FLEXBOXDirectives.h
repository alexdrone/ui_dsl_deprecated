//
//  FLEXBOXDirectives.h
//  ReflektorKit
//
//  Created by Alex Usbergo on 16/05/15.
//  Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

@import UIKit;

#ifndef ReflektorKit_FLEXBOXDirectives_h
#define ReflektorKit_FLEXBOXDirectives_h

extern id FLEXBOX_parseCSSValue(NSString* cssValue)
{
    NSDictionary *mapping = @{
                              
                              @"row": @(FLEXBOXFlexDirectionRow),
                              @"row-reverse": @(FLEXBOXFlexDirectionRowReverse),
                              @"column": @(FLEXBOXFlexDirectionColumn),
                              @"column-reverse": @(FLEXBOXFlexDirectionColumnReverse),
                              
                              @"wrap": @(YES),
                              @"nowrap": @(NO),
                              
                              @"flex-start": @(FLEXBOXJustificationFlexStart),
                              @"center": @(FLEXBOXJustificationCenter),
                              @"flex-end": @(FLEXBOXJustificationFlexEnd),
                              @"space-between": @(FLEXBOXJustificationSpaceBetween),
                              @"space-around": @(FLEXBOXJustificationSpaceAround),
                              
                              @"auto": @(FLEXBOXAlignmentAuto),
                              @"stretch": @(FLEXBOXAlignmentStretch)
                              };
    
    return mapping[cssValue];
}


#endif
