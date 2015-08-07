//
// REFLAspects.h
// REFLAspects - A delightful, simple library for aspect oriented programming.
//
// Copyright (c) 2014 Peter Steinberger. Licensed under the MIT license.
// Forked from https://github.com/steipete/Aspects
//

@import UIKit;

typedef NS_OPTIONS(NSUInteger, REFLAspectOptions) {
    REFLAspectPositionAfter   = 0,            ///Called after the original implementation (default)
    REFLAspectPositionInstead = 1,            ///Will replace the original implementation.
    REFLAspectPositionBefore  = 2,            ///Called before the original implementation.
    
    REFLAspectOptionAutomaticRemoval = 1 << 3 ///Will remove the hook after the first execution.
};

///Opaque REFLAspect Token that allows to deregister the hook.
@protocol REFLAspectToken <NSObject>

///Deregisters an aspect.
///@return YES if deregistration is successful, otherwise NO.
- (BOOL)remove;

@end

///The REFLAspectInfo protocol is the first parameter of our block syntax.
@protocol REFLAspectInfo <NSObject>

///The instance that is currently hooked.
- (id)instance;

///The original invocation of the hooked method.
- (NSInvocation *)originalInvocation;

///All method arguments, boxed. This is lazily evaluated.
- (NSArray *)arguments;

@end

/**
 REFLAspects uses Objective-C message forwarding to hook into messages. This will create some overhead. Don't add aspects to methods that are called a lot. REFLAspects is meant for view/controller code that is not called a 1000 times per second.

 Adding aspects returns an opaque token which can be used to deregister again. All calls are thread safe.
 */
@interface NSObject (REFLAspects)

///Adds a block of code before/instead/after the current `selector` for a specific class.
///
///@param block REFLAspects replicates the type signature of the method being hooked.
///The first parameter will be `id<REFLAspectInfo>`, followed by all parameters of the method.
///These parameters are optional and will be filled to match the block signature.
///You can even use an empty block, or one that simple gets `id<REFLAspectInfo>`.
///
///@note Hooking static methods is not supported.
///@return A token which allows to later deregister the aspect.
+ (id<REFLAspectToken>)REFLAspect_hookSelector:(SEL)selector
                           withOptions:(REFLAspectOptions)options
                            usingBlock:(id)block
                                 error:(NSError **)error;

///Adds a block of code before/instead/after the current `selector` for a specific instance.
- (id<REFLAspectToken>)REFLAspect_hookSelector:(SEL)selector
                           withOptions:(REFLAspectOptions)options
                            usingBlock:(id)block
                                 error:(NSError **)error;

@end


typedef NS_ENUM(NSUInteger, REFLAspectErrorCode) {
    REFLAspectErrorSelectorBlacklisted,                   ///Selectors like release, retain, autorelease are blacklisted.
    REFLAspectErrorDoesNotRespondToSelector,              ///Selector could not be found.
    REFLAspectErrorSelectorDeallocPosition,               ///When hooking dealloc, only REFLAspectPositionBefore is allowed.
    REFLAspectErrorSelectorAlreadyHookedInClassHierarchy, ///Statically hooking the same method in subclasses is not allowed.
    REFLAspectErrorFailedToAllocateClassPair,             ///The runtime failed creating a class pair.
    REFLAspectErrorMissingBlockSignature,                 ///The block misses compile time signature info and can't be called.
    REFLAspectErrorIncompatibleBlockSignature,            ///The block signature does not match the method or is too large.

    REFLAspectErrorRemoveObjectAlreadyDeallocated = 100   ///(for removing) The object hooked is already deallocated.
};

extern NSString *const REFLAspectErrorDomain;
