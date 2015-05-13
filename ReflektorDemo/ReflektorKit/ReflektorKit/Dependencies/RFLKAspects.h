//
// RFLKAspects.h
// RFLKAspects - A delightful, simple library for aspect oriented programming.
//
// Copyright (c) 2014 Peter Steinberger. Licensed under the MIT license.
// Forked from https://github.com/steipete/RFLKAspects
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, RFLKAspectOptions) {
    RFLKAspectPositionAfter   = 0,            ///Called after the original implementation (default)
    RFLKAspectPositionInstead = 1,            ///Will replace the original implementation.
    RFLKAspectPositionBefore  = 2,            ///Called before the original implementation.
    
    RFLKAspectOptionAutomaticRemoval = 1 << 3 ///Will remove the hook after the first execution.
};

///Opaque RFLKAspect Token that allows to deregister the hook.
@protocol RFLKAspectToken <NSObject>

///Deregisters an aspect.
///@return YES if deregistration is successful, otherwise NO.
- (BOOL)remove;

@end

///The RFLKAspectInfo protocol is the first parameter of our block syntax.
@protocol RFLKAspectInfo <NSObject>

///The instance that is currently hooked.
- (id)instance;

///The original invocation of the hooked method.
- (NSInvocation *)originalInvocation;

///All method arguments, boxed. This is lazily evaluated.
- (NSArray *)arguments;

@end

/**
 RFLKAspects uses Objective-C message forwarding to hook into messages. This will create some overhead. Don't add aspects to methods that are called a lot. RFLKAspects is meant for view/controller code that is not called a 1000 times per second.

 Adding aspects returns an opaque token which can be used to deregister again. All calls are thread safe.
 */
@interface NSObject (RFLKAspects)

///Adds a block of code before/instead/after the current `selector` for a specific class.
///
///@param block RFLKAspects replicates the type signature of the method being hooked.
///The first parameter will be `id<RFLKAspectInfo>`, followed by all parameters of the method.
///These parameters are optional and will be filled to match the block signature.
///You can even use an empty block, or one that simple gets `id<RFLKAspectInfo>`.
///
///@note Hooking static methods is not supported.
///@return A token which allows to later deregister the aspect.
+ (id<RFLKAspectToken>)rflkAspect_hookSelector:(SEL)selector
                           withOptions:(RFLKAspectOptions)options
                            usingBlock:(id)block
                                 error:(NSError **)error;

///Adds a block of code before/instead/after the current `selector` for a specific instance.
- (id<RFLKAspectToken>)rflkAspect_hookSelector:(SEL)selector
                           withOptions:(RFLKAspectOptions)options
                            usingBlock:(id)block
                                 error:(NSError **)error;

@end


typedef NS_ENUM(NSUInteger, RFLKAspectErrorCode) {
    RFLKAspectErrorSelectorBlacklisted,                   ///Selectors like release, retain, autorelease are blacklisted.
    RFLKAspectErrorDoesNotRespondToSelector,              ///Selector could not be found.
    RFLKAspectErrorSelectorDeallocPosition,               ///When hooking dealloc, only RFLKAspectPositionBefore is allowed.
    RFLKAspectErrorSelectorAlreadyHookedInClassHierarchy, ///Statically hooking the same method in subclasses is not allowed.
    RFLKAspectErrorFailedToAllocateClassPair,             ///The runtime failed creating a class pair.
    RFLKAspectErrorMissingBlockSignature,                 ///The block misses compile time signature info and can't be called.
    RFLKAspectErrorIncompatibleBlockSignature,            ///The block signature does not match the method or is too large.

    RFLKAspectErrorRemoveObjectAlreadyDeallocated = 100   ///(for removing) The object hooked is already deallocated.
};

extern NSString *const RFLKAspectErrorDomain;
