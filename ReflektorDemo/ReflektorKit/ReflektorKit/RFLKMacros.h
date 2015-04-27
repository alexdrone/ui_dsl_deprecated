//
//  RFLKMacros.h
//  ReflektorKit
//
//  Created by Alex Usbergo on 21/04/15.
//  Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

#ifndef ReflektorKit_RFLKMacros_h
#define ReflektorKit_RFLKMacros_h

static inline void RFLKLog(NSString* format, ...)
{
#if DEBUG
    static NSDateFormatter* timeStampFormat;
    if (!timeStampFormat) {
        timeStampFormat = [[NSDateFormatter alloc] init];
        [timeStampFormat setDateFormat:@"HH:mm:ss.SSS"];
        [timeStampFormat setTimeZone:[NSTimeZone systemTimeZone]];
    }
    
    NSString* timestamp = [timeStampFormat stringFromDate:[NSDate date]];
    
    va_list vargs;
    va_start(vargs, format);
    NSString* formattedMessage = [[NSString alloc] initWithFormat:format arguments:vargs];
    va_end(vargs);
    
    NSString* message = [NSString stringWithFormat:@"▦ %@ ▦ ⓀⓈⒹ %@", timestamp, formattedMessage];
    
    printf("%s\n", [message UTF8String]);
#endif
}

#endif
