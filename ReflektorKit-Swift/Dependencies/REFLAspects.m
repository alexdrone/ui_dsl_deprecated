//
// REFLAspects.m
// REFLAspects - A delightful, simple library for aspect oriented programming.
//
// Copyright (c) 2014 Peter Steinberger. Licensed under the MIT license.
// Forked from https://github.com/steipete/REFLAspects
//

#import "REFLAspects.h"
#import <libkern/OSAtomic.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define REFLAspectLog(...)
//#define REFLAspectLog(...) do { NSLog(__VA_ARGS__); }while(0)
#define REFLAspectLogError(...) do { NSLog(__VA_ARGS__); }while(0)

//Block internals.
typedef NS_OPTIONS(int, REFLAspectBlockFlags) {
	REFLAspectBlockFlagsHasCopyDisposeHelpers = (1 << 25),
	REFLAspectBlockFlagsHasSignature          = (1 << 30)
};
typedef struct _REFLAspectBlock {
	__unused Class isa;
	REFLAspectBlockFlags flags;
	__unused int reserved;
	void (__unused *invoke)(struct _REFLAspectBlock *block, ...);
	struct {
		unsigned long int reserved;
		unsigned long int size;
		//requires REFLAspectBlockFlagsHasCopyDisposeHelpers
		void (*copy)(void *dst, const void *src);
		void (*dispose)(const void *);
		//requires REFLAspectBlockFlagsHasSignature
		const char *signature;
		const char *layout;
	} *descriptor;
	//imported variables
} *REFLAspectBlockRef;

@interface REFLAspectInfo : NSObject <REFLAspectInfo>
- (id)initWithInstance:(__unsafe_unretained id)instance invocation:(NSInvocation *)invocation;
@property (nonatomic, unsafe_unretained, readonly) id instance;
@property (nonatomic, strong, readonly) NSArray *arguments;
@property (nonatomic, strong, readonly) NSInvocation *originalInvocation;
@end

//Tracks a single aspect.
@interface REFLAspectIdentifier : NSObject
+ (instancetype)identifierWithSelector:(SEL)selector object:(id)object options:(REFLAspectOptions)options block:(id)block error:(NSError **)error;
- (BOOL)invokeWithInfo:(id<REFLAspectInfo>)info;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, strong) id block;
@property (nonatomic, strong) NSMethodSignature *blockSignature;
@property (nonatomic, weak) id object;
@property (nonatomic, assign) REFLAspectOptions options;
@end

//Tracks all aspects for an object/class.
@interface REFLAspectsContainer : NSObject
- (void)addREFLAspect:(REFLAspectIdentifier *)aspect withOptions:(REFLAspectOptions)injectPosition;
- (BOOL)removeREFLAspect:(id)aspect;
- (BOOL)hasREFLAspects;
@property (atomic, copy) NSArray *beforeREFLAspects;
@property (atomic, copy) NSArray *insteadREFLAspects;
@property (atomic, copy) NSArray *afterREFLAspects;
@end

@interface REFLAspectTracker : NSObject
- (id)initWithTrackedClass:(Class)trackedClass parent:(REFLAspectTracker *)parent;
@property (nonatomic, strong) Class trackedClass;
@property (nonatomic, strong) NSMutableSet *selectorNames;
@property (nonatomic, weak) REFLAspectTracker *parentEntry;
@end

@interface NSInvocation (REFLAspects)
- (NSArray *)aspects_arguments;
@end

#define REFLAspectPositionFilter 0x07

#define REFLAspectError(errorCode, errorDescription) do { \
REFLAspectLogError(@"REFLAspects: %@", errorDescription); \
if (error) { *error = [NSError errorWithDomain:REFLAspectErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey: errorDescription}]; }}while(0)

NSString *const REFLAspectErrorDomain = @"REFLAspectErrorDomain";
static NSString *const REFLAspectsSubclassSuffix = @"_REFLAspects_";
static NSString *const REFLAspectsMessagePrefix = @"aspects_";

@implementation NSObject (REFLAspects)

- (NSString*)refl_className
{
    return NSStringFromClass(self.class);
}

- (Class)refl_class
{
    return self.class;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public REFLAspects API

+ (id<REFLAspectToken>)REFLAspect_hookSelector:(SEL)selector
                      withOptions:(REFLAspectOptions)options
                       usingBlock:(id)block
                            error:(NSError **)error {
    return REFLAspect_add((id)self, selector, options, block, error);
}

///@return A token which allows to later deregister the aspect.
- (id<REFLAspectToken>)REFLAspect_hookSelector:(SEL)selector
                      withOptions:(REFLAspectOptions)options
                       usingBlock:(id)block
                            error:(NSError **)error {
    return REFLAspect_add(self, selector, options, block, error);
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private Helper

static id REFLAspect_add(id self, SEL selector, REFLAspectOptions options, id block, NSError **error) {
    NSCParameterAssert(self);
    NSCParameterAssert(selector);
    NSCParameterAssert(block);

    __block REFLAspectIdentifier *identifier = nil;
    REFLAspect_performLocked(^{
        if (REFLAspect_isSelectorAllowedAndTrack(self, selector, options, error)) {
            REFLAspectsContainer *aspectContainer = REFLAspect_getContainerForObject(self, selector);
            identifier = [REFLAspectIdentifier identifierWithSelector:selector object:self options:options block:block error:error];
            if (identifier) {
                [aspectContainer addREFLAspect:identifier withOptions:options];

                //Modify the class to allow message interception.
                REFLAspect_prepareClassAndHookSelector(self, selector, error);
            }
        }
    });
    return identifier;
}

static BOOL REFLAspect_remove(REFLAspectIdentifier *aspect, NSError **error) {
    NSCAssert([aspect isKindOfClass:REFLAspectIdentifier.class], @"Must have correct type.");

    __block BOOL success = NO;
    REFLAspect_performLocked(^{
        id self = aspect.object; //strongify
        if (self) {
            REFLAspectsContainer *aspectContainer = REFLAspect_getContainerForObject(self, aspect.selector);
            success = [aspectContainer removeREFLAspect:aspect];

            REFLAspect_cleanupHookedClassAndSelector(self, aspect.selector);
            //destroy token
            aspect.object = nil;
            aspect.block = nil;
            aspect.selector = NULL;
        }else {
            NSString *errrorDesc = [NSString stringWithFormat:@"Unable to deregister hook. Object already deallocated: %@", aspect];
            REFLAspectError(REFLAspectErrorRemoveObjectAlreadyDeallocated, errrorDesc);
        }
    });
    return success;
}

static void REFLAspect_performLocked(dispatch_block_t block) {
    static OSSpinLock REFLAspect_lock = OS_SPINLOCK_INIT;
    OSSpinLockLock(&REFLAspect_lock);
    block();
    OSSpinLockUnlock(&REFLAspect_lock);
}

static SEL REFLAspect_aliasForSelector(SEL selector) {
    NSCParameterAssert(selector);
	return NSSelectorFromString([REFLAspectsMessagePrefix stringByAppendingFormat:@"_%@", NSStringFromSelector(selector)]);
}

static NSMethodSignature *REFLAspect_blockMethodSignature(id block, NSError **error) {
    REFLAspectBlockRef layout = (__bridge void *)block;
	if (!(layout->flags & REFLAspectBlockFlagsHasSignature)) {
        NSString *description = [NSString stringWithFormat:@"The block %@ doesn't contain a type signature.", block];
        REFLAspectError(REFLAspectErrorMissingBlockSignature, description);
        return nil;
    }
	void *desc = layout->descriptor;
	desc += 2 * sizeof(unsigned long int);
	if (layout->flags & REFLAspectBlockFlagsHasCopyDisposeHelpers) {
		desc += 2 * sizeof(void *);
    }
	if (!desc) {
        NSString *description = [NSString stringWithFormat:@"The block %@ doesn't has a type signature.", block];
        REFLAspectError(REFLAspectErrorMissingBlockSignature, description);
        return nil;
    }
	const char *signature = (*(const char **)desc);
	return [NSMethodSignature signatureWithObjCTypes:signature];
}

static BOOL REFLAspect_isCompatibleBlockSignature(NSMethodSignature *blockSignature, id object, SEL selector, NSError **error) {
    NSCParameterAssert(blockSignature);
    NSCParameterAssert(object);
    NSCParameterAssert(selector);

    BOOL signaturesMatch = YES;
    NSMethodSignature *methodSignature = [[object class] instanceMethodSignatureForSelector:selector];
    if (blockSignature.numberOfArguments > methodSignature.numberOfArguments) {
        signaturesMatch = NO;
    }else {
        if (blockSignature.numberOfArguments > 1) {
            const char *blockType = [blockSignature getArgumentTypeAtIndex:1];
            if (blockType[0] != '@') {
                signaturesMatch = NO;
            }
        }
        //Argument 0 is self/block, argument 1 is SEL or id<REFLAspectInfo>. We start comparing at argument 2.
        //The block can have less arguments than the method, that's ok.
        if (signaturesMatch) {
            for (NSUInteger idx = 2; idx < blockSignature.numberOfArguments; idx++) {
                const char *methodType = [methodSignature getArgumentTypeAtIndex:idx];
                const char *blockType = [blockSignature getArgumentTypeAtIndex:idx];
                //Only compare parameter, not the optional type data.
                if (!methodType || !blockType || methodType[0] != blockType[0]) {
                    signaturesMatch = NO; break;
                }
            }
        }
    }

    if (!signaturesMatch) {
        NSString *description = [NSString stringWithFormat:@"Block signature %@ doesn't match %@.", blockSignature, methodSignature];
        REFLAspectError(REFLAspectErrorIncompatibleBlockSignature, description);
        return NO;
    }
    return YES;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Class + Selector Preparation

static BOOL REFLAspect_isMsgForwardIMP(IMP impl) {
    return impl == _objc_msgForward
#if !defined(__arm64__)
    || impl == (IMP)_objc_msgForward_stret
#endif
    ;
}

static IMP REFLAspect_getMsgForwardIMP(NSObject *self, SEL selector) {
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    //As an ugly internal runtime implementation detail in the 32bit runtime, we need to determine of the method we hook returns a struct or anything larger than id.
    //https://developer.apple.com/library/mac/documentation/DeveloperTools/Conceptual/LowLevelABI/000-Introduction/introduction.html
    //https://github.com/ReactiveCocoa/ReactiveCocoa/issues/783
    //http://infocenter.arm.com/help/topic/com.arm.doc.ihi0042e/IHI0042E_aapcs.pdf (Section 5.4)
    Method method = class_getInstanceMethod(self.class, selector);
    const char *encoding = method_getTypeEncoding(method);
    BOOL methodReturnsStructValue = encoding[0] == _C_STRUCT_B;
    if (methodReturnsStructValue) {
        @try {
            NSUInteger valueSize = 0;
            NSGetSizeAndAlignment(encoding, &valueSize, NULL);

            if (valueSize == 1 || valueSize == 2 || valueSize == 4 || valueSize == 8) {
                methodReturnsStructValue = NO;
            }
        } @catch (__unused NSException *e) {}
    }
    if (methodReturnsStructValue) {
        msgForwardIMP = (IMP)_objc_msgForward_stret;
    }
#endif
    return msgForwardIMP;
}

static void REFLAspect_prepareClassAndHookSelector(NSObject *self, SEL selector, NSError **error) {
    NSCParameterAssert(selector);
    Class klass = REFLAspect_hookClass(self, error);
    Method targetMethod = class_getInstanceMethod(klass, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    if (!REFLAspect_isMsgForwardIMP(targetMethodIMP)) {
        //Make a method alias for the existing method implementation, it not already copied.
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        SEL aliasSelector = REFLAspect_aliasForSelector(selector);
        if (![klass instancesRespondToSelector:aliasSelector]) {
            __unused BOOL addedAlias = class_addMethod(klass, aliasSelector, method_getImplementation(targetMethod), typeEncoding);
            NSCAssert(addedAlias, @"Original implementation for %@ is already copied to %@ on %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), klass);
        }

        //We use forwardInvocation to hook in.
        class_replaceMethod(klass, selector, REFLAspect_getMsgForwardIMP(self, selector), typeEncoding);
        REFLAspectLog(@"REFLAspects: Installed hook for -[%@ %@].", klass, NSStringFromSelector(selector));
    }
}

//Will undo the runtime changes made.
static void REFLAspect_cleanupHookedClassAndSelector(NSObject *self, SEL selector) {
    NSCParameterAssert(self);
    NSCParameterAssert(selector);

	Class klass = object_getClass(self);
    BOOL isMetaClass = class_isMetaClass(klass);
    if (isMetaClass) {
        klass = (Class)self;
    }

    //Check if the method is marked as forwarded and undo that.
    Method targetMethod = class_getInstanceMethod(klass, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    if (REFLAspect_isMsgForwardIMP(targetMethodIMP)) {
        //Restore the original method implementation.
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        SEL aliasSelector = REFLAspect_aliasForSelector(selector);
        Method originalMethod = class_getInstanceMethod(klass, aliasSelector);
        IMP originalIMP = method_getImplementation(originalMethod);
        NSCAssert(originalMethod, @"Original implementation for %@ not found %@ on %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), klass);

        class_replaceMethod(klass, selector, originalIMP, typeEncoding);
        REFLAspectLog(@"REFLAspects: Removed hook for -[%@ %@].", klass, NSStringFromSelector(selector));
    }

    //Deregister global tracked selector
    REFLAspect_deregisterTrackedSelector(self, selector);

    //Get the aspect container and check if there are any hooks remaining. Clean up if there are not.
    REFLAspectsContainer *container = REFLAspect_getContainerForObject(self, selector);
    if (!container.hasREFLAspects) {
        //Destroy the container
        REFLAspect_destroyContainerForObject(self, selector);

        //Figure out how the class was modified to undo the changes.
        NSString *className = NSStringFromClass(klass);
        if ([className hasSuffix:REFLAspectsSubclassSuffix]) {
            Class originalClass = NSClassFromString([className stringByReplacingOccurrencesOfString:REFLAspectsSubclassSuffix withString:@""]);
            NSCAssert(originalClass != nil, @"Original class must exist");
            object_setClass(self, originalClass);
            REFLAspectLog(@"REFLAspects: %@ has been restored.", NSStringFromClass(originalClass));

            //We can only dispose the class pair if we can ensure that no instances exist using our subclass.
            //Since we don't globally track this, we can't ensure this - but there's also not much overhead in keeping it around.
            //objc_disposeClassPair(object.class);
        }else {
            //Class is most likely swizzled in place. Undo that.
            if (isMetaClass) {
                REFLAspect_undoSwizzleClassInPlace((Class)self);
            }else if (self.class != klass) {
            	REFLAspect_undoSwizzleClassInPlace(klass);
            }
        }
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Hook Class

static Class REFLAspect_hookClass(NSObject *self, NSError **error) {
    NSCParameterAssert(self);
	Class statedClass = self.class;
	Class baseClass = object_getClass(self);
	NSString *className = NSStringFromClass(baseClass);

    //Already subclassed
	if ([className hasSuffix:REFLAspectsSubclassSuffix]) {
		return baseClass;

        //We swizzle a class object, not a single object.
	}else if (class_isMetaClass(baseClass)) {
        return REFLAspect_swizzleClassInPlace((Class)self);
        //Probably a KVO'ed class. Swizzle in place. Also swizzle meta classes in place.
    }else if (statedClass != baseClass) {
        return REFLAspect_swizzleClassInPlace(baseClass);
    }

    //Default case. Create dynamic subclass.
	const char *subclassName = [className stringByAppendingString:REFLAspectsSubclassSuffix].UTF8String;
	Class subclass = objc_getClass(subclassName);

	if (subclass == nil) {
		subclass = objc_allocateClassPair(baseClass, subclassName, 0);
		if (subclass == nil) {
            NSString *errrorDesc = [NSString stringWithFormat:@"objc_allocateClassPair failed to allocate class %s.", subclassName];
            REFLAspectError(REFLAspectErrorFailedToAllocateClassPair, errrorDesc);
            return nil;
        }

		REFLAspect_swizzleForwardInvocation(subclass);
		REFLAspect_hookedGetClass(subclass, statedClass);
		REFLAspect_hookedGetClass(object_getClass(subclass), statedClass);
		objc_registerClassPair(subclass);
	}

	object_setClass(self, subclass);
	return subclass;
}

static NSString *const REFLAspectsForwardInvocationSelectorName = @"__aspects_forwardInvocation:";
static void REFLAspect_swizzleForwardInvocation(Class klass) {
    NSCParameterAssert(klass);
    //If there is no method, replace will act like class_addMethod.
    IMP originalImplementation = class_replaceMethod(klass, @selector(forwardInvocation:), (IMP)__ASPECTS_ARE_BEING_CALLED__, "v@:@");
    if (originalImplementation) {
        class_addMethod(klass, NSSelectorFromString(REFLAspectsForwardInvocationSelectorName), originalImplementation, "v@:@");
    }
    REFLAspectLog(@"REFLAspects: %@ is now aspect aware.", NSStringFromClass(klass));
}

static void REFLAspect_undoSwizzleForwardInvocation(Class klass) {
    NSCParameterAssert(klass);
    Method originalMethod = class_getInstanceMethod(klass, NSSelectorFromString(REFLAspectsForwardInvocationSelectorName));
    Method objectMethod = class_getInstanceMethod(NSObject.class, @selector(forwardInvocation:));
    //There is no class_removeMethod, so the best we can do is to retore the original implementation, or use a dummy.
    IMP originalImplementation = method_getImplementation(originalMethod ?: objectMethod);
    class_replaceMethod(klass, @selector(forwardInvocation:), originalImplementation, "v@:@");

    REFLAspectLog(@"REFLAspects: %@ has been restored.", NSStringFromClass(klass));
}

static void REFLAspect_hookedGetClass(Class class, Class statedClass) {
    NSCParameterAssert(class);
    NSCParameterAssert(statedClass);
	Method method = class_getInstanceMethod(class, @selector(class));
	IMP newIMP = imp_implementationWithBlock(^(id self) {
		return statedClass;
	});
	class_replaceMethod(class, @selector(class), newIMP, method_getTypeEncoding(method));
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Swizzle Class In Place

static void _REFLAspect_modifySwizzledClasses(void (^block)(NSMutableSet *swizzledClasses)) {
    static NSMutableSet *swizzledClasses;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        swizzledClasses = [NSMutableSet new];
    });
    @synchronized(swizzledClasses) {
        block(swizzledClasses);
    }
}

static Class REFLAspect_swizzleClassInPlace(Class klass) {
    NSCParameterAssert(klass);
    NSString *className = NSStringFromClass(klass);

    _REFLAspect_modifySwizzledClasses(^(NSMutableSet *swizzledClasses) {
        if (![swizzledClasses containsObject:className]) {
            REFLAspect_swizzleForwardInvocation(klass);
            [swizzledClasses addObject:className];
        }
    });
    return klass;
}

static void REFLAspect_undoSwizzleClassInPlace(Class klass) {
    NSCParameterAssert(klass);
    NSString *className = NSStringFromClass(klass);

    _REFLAspect_modifySwizzledClasses(^(NSMutableSet *swizzledClasses) {
        if ([swizzledClasses containsObject:className]) {
            REFLAspect_undoSwizzleForwardInvocation(klass);
            [swizzledClasses removeObject:className];
        }
    });
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - REFLAspect Invoke Point

//This is a macro so we get a cleaner stack trace.
#define REFLAspect_invoke(aspects, info) \
for (REFLAspectIdentifier *aspect in aspects) {\
    [aspect invokeWithInfo:info];\
    if (aspect.options & REFLAspectOptionAutomaticRemoval) { \
        aspectsToRemove = [aspectsToRemove?:@[] arrayByAddingObject:aspect]; \
    } \
}

//This is the swizzled forwardInvocation: method.
static void __ASPECTS_ARE_BEING_CALLED__(__unsafe_unretained NSObject *self, SEL selector, NSInvocation *invocation) {
    NSCParameterAssert(self);
    NSCParameterAssert(invocation);
    SEL originalSelector = invocation.selector;
	SEL aliasSelector = REFLAspect_aliasForSelector(invocation.selector);
    invocation.selector = aliasSelector;
    REFLAspectsContainer *objectContainer = objc_getAssociatedObject(self, aliasSelector);
    REFLAspectsContainer *classContainer = REFLAspect_getContainerForClass(object_getClass(self), aliasSelector);
    REFLAspectInfo *info = [[REFLAspectInfo alloc] initWithInstance:self invocation:invocation];
    NSArray *aspectsToRemove = nil;

    //Before hooks.
    REFLAspect_invoke(classContainer.beforeREFLAspects, info);
    REFLAspect_invoke(objectContainer.beforeREFLAspects, info);

    //Instead hooks.
    BOOL respondsToAlias = YES;
    if (objectContainer.insteadREFLAspects.count || classContainer.insteadREFLAspects.count) {
        REFLAspect_invoke(classContainer.insteadREFLAspects, info);
        REFLAspect_invoke(objectContainer.insteadREFLAspects, info);
    }else {
        Class klass = object_getClass(invocation.target);
        do {
            if ((respondsToAlias = [klass instancesRespondToSelector:aliasSelector])) {
                [invocation invoke];
                break;
            }
        }while (!respondsToAlias && (klass = class_getSuperclass(klass)));
    }

    //After hooks.
    REFLAspect_invoke(classContainer.afterREFLAspects, info);
    REFLAspect_invoke(objectContainer.afterREFLAspects, info);

    //If no hooks are installed, call original implementation (usually to throw an exception)
    if (!respondsToAlias) {
        invocation.selector = originalSelector;
        SEL originalForwardInvocationSEL = NSSelectorFromString(REFLAspectsForwardInvocationSelectorName);
        if ([self respondsToSelector:originalForwardInvocationSEL]) {
            ((void( *)(id, SEL, NSInvocation *))objc_msgSend)(self, originalForwardInvocationSEL, invocation);
        }else {
            [self doesNotRecognizeSelector:invocation.selector];
        }
    }

    //Remove any hooks that are queued for deregistration.
    [aspectsToRemove makeObjectsPerformSelector:@selector(remove)];
}
#undef REFLAspect_invoke

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - REFLAspect Container Management

//Loads or creates the aspect container.
static REFLAspectsContainer *REFLAspect_getContainerForObject(NSObject *self, SEL selector) {
    NSCParameterAssert(self);
    SEL aliasSelector = REFLAspect_aliasForSelector(selector);
    REFLAspectsContainer *aspectContainer = objc_getAssociatedObject(self, aliasSelector);
    if (!aspectContainer) {
        aspectContainer = [REFLAspectsContainer new];
        objc_setAssociatedObject(self, aliasSelector, aspectContainer, OBJC_ASSOCIATION_RETAIN);
    }
    return aspectContainer;
}

static REFLAspectsContainer *REFLAspect_getContainerForClass(Class klass, SEL selector) {
    NSCParameterAssert(klass);
    REFLAspectsContainer *classContainer = nil;
    do {
        classContainer = objc_getAssociatedObject(klass, selector);
        if (classContainer.hasREFLAspects) break;
    }while ((klass = class_getSuperclass(klass)));

    return classContainer;
}

static void REFLAspect_destroyContainerForObject(id<NSObject> self, SEL selector) {
    NSCParameterAssert(self);
    SEL aliasSelector = REFLAspect_aliasForSelector(selector);
    objc_setAssociatedObject(self, aliasSelector, nil, OBJC_ASSOCIATION_RETAIN);
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Selector Blacklist Checking

static NSMutableDictionary *REFLAspect_getSwizzledClassesDict() {
    static NSMutableDictionary *swizzledClassesDict;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        swizzledClassesDict = [NSMutableDictionary new];
    });
    return swizzledClassesDict;
}

static BOOL REFLAspect_isSelectorAllowedAndTrack(NSObject *self, SEL selector, REFLAspectOptions options, NSError **error) {
    static NSSet *disallowedSelectorList;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        disallowedSelectorList = [NSSet setWithObjects:@"retain", @"release", @"autorelease", @"forwardInvocation:", nil];
    });

    //Check against the blacklist.
    NSString *selectorName = NSStringFromSelector(selector);
    if ([disallowedSelectorList containsObject:selectorName]) {
        NSString *errorDescription = [NSString stringWithFormat:@"Selector %@ is blacklisted.", selectorName];
        REFLAspectError(REFLAspectErrorSelectorBlacklisted, errorDescription);
        return NO;
    }

    //Additional checks.
    REFLAspectOptions position = options&REFLAspectPositionFilter;
    if ([selectorName isEqualToString:@"dealloc"] && position != REFLAspectPositionBefore) {
        NSString *errorDesc = @"REFLAspectPositionBefore is the only valid position when hooking dealloc.";
        REFLAspectError(REFLAspectErrorSelectorDeallocPosition, errorDesc);
        return NO;
    }

    if (![self respondsToSelector:selector] && ![self.class instancesRespondToSelector:selector]) {
        NSString *errorDesc = [NSString stringWithFormat:@"Unable to find selector -[%@ %@].", NSStringFromClass(self.class), selectorName];
        REFLAspectError(REFLAspectErrorDoesNotRespondToSelector, errorDesc);
        return NO;
    }

    //Search for the current class and the class hierarchy IF we are modifying a class object
    if (class_isMetaClass(object_getClass(self))) {
        Class klass = [self class];
        NSMutableDictionary *swizzledClassesDict = REFLAspect_getSwizzledClassesDict();
        Class currentClass = [self class];
        do {
            REFLAspectTracker *tracker = swizzledClassesDict[currentClass];
            if ([tracker.selectorNames containsObject:selectorName]) {

                //Find the topmost class for the log.
                if (tracker.parentEntry) {
                    REFLAspectTracker *topmostEntry = tracker.parentEntry;
                    while (topmostEntry.parentEntry) {
                        topmostEntry = topmostEntry.parentEntry;
                    }
                    NSString *errorDescription = [NSString stringWithFormat:@"Error: %@ already hooked in %@. A method can only be hooked once per class hierarchy.", selectorName, NSStringFromClass(topmostEntry.trackedClass)];
                    REFLAspectError(REFLAspectErrorSelectorAlreadyHookedInClassHierarchy, errorDescription);
                    return NO;
                }else if (klass == currentClass) {
                    //Already modified and topmost!
                    return YES;
                }
            }
        }while ((currentClass = class_getSuperclass(currentClass)));

        //Add the selector as being modified.
        currentClass = klass;
        REFLAspectTracker *parentTracker = nil;
        do {
            REFLAspectTracker *tracker = swizzledClassesDict[currentClass];
            if (!tracker) {
                tracker = [[REFLAspectTracker alloc] initWithTrackedClass:currentClass parent:parentTracker];
                swizzledClassesDict[(id<NSCopying>)currentClass] = tracker;
            }
            [tracker.selectorNames addObject:selectorName];
            //All superclasses get marked as having a subclass that is modified.
            parentTracker = tracker;
        }while ((currentClass = class_getSuperclass(currentClass)));
    }

    return YES;
}

static void REFLAspect_deregisterTrackedSelector(id self, SEL selector) {
    if (!class_isMetaClass(object_getClass(self))) return;

    NSMutableDictionary *swizzledClassesDict = REFLAspect_getSwizzledClassesDict();
    NSString *selectorName = NSStringFromSelector(selector);
    Class currentClass = [self class];
    do {
        REFLAspectTracker *tracker = swizzledClassesDict[currentClass];
        if (tracker) {
            [tracker.selectorNames removeObject:selectorName];
            if (tracker.selectorNames.count == 0) {
                [swizzledClassesDict removeObjectForKey:tracker];
            }
        }
    }while ((currentClass = class_getSuperclass(currentClass)));
}

@end

@implementation REFLAspectTracker

- (id)initWithTrackedClass:(Class)trackedClass parent:(REFLAspectTracker *)parent {
    if (self = [super init]) {
        _trackedClass = trackedClass;
        _parentEntry = parent;
        _selectorNames = [NSMutableSet new];
    }
    return self;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %@, trackedClass: %@, selectorNames:%@, parent:%p>", self.class, self, NSStringFromClass(self.trackedClass), self.selectorNames, self.parentEntry];
}

@end

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSInvocation (REFLAspects)

@implementation NSInvocation (REFLAspects)

//Thanks to the ReactiveCocoa team for providing a generic solution for this.
- (id)REFLAspect_argumentAtIndex:(NSUInteger)index {
	const char *argType = [self.methodSignature getArgumentTypeAtIndex:index];
	//Skip const type qualifier.
	if (argType[0] == _C_CONST) argType++;

#define WRAP_AND_RETURN(type) do { type val = 0; [self getArgument:&val atIndex:(NSInteger)index]; return @(val); } while (0)
	if (strcmp(argType, @encode(id)) == 0 || strcmp(argType, @encode(Class)) == 0) {
		__autoreleasing id returnObj;
		[self getArgument:&returnObj atIndex:(NSInteger)index];
		return returnObj;
	} else if (strcmp(argType, @encode(SEL)) == 0) {
        SEL selector = 0;
        [self getArgument:&selector atIndex:(NSInteger)index];
        return NSStringFromSelector(selector);
    } else if (strcmp(argType, @encode(Class)) == 0) {
        __autoreleasing Class theClass = Nil;
        [self getArgument:&theClass atIndex:(NSInteger)index];
        return theClass;
        //Using this list will box the number with the appropriate constructor, instead of the generic NSValue.
	} else if (strcmp(argType, @encode(char)) == 0) {
		WRAP_AND_RETURN(char);
	} else if (strcmp(argType, @encode(int)) == 0) {
		WRAP_AND_RETURN(int);
	} else if (strcmp(argType, @encode(short)) == 0) {
		WRAP_AND_RETURN(short);
	} else if (strcmp(argType, @encode(long)) == 0) {
		WRAP_AND_RETURN(long);
	} else if (strcmp(argType, @encode(long long)) == 0) {
		WRAP_AND_RETURN(long long);
	} else if (strcmp(argType, @encode(unsigned char)) == 0) {
		WRAP_AND_RETURN(unsigned char);
	} else if (strcmp(argType, @encode(unsigned int)) == 0) {
		WRAP_AND_RETURN(unsigned int);
	} else if (strcmp(argType, @encode(unsigned short)) == 0) {
		WRAP_AND_RETURN(unsigned short);
	} else if (strcmp(argType, @encode(unsigned long)) == 0) {
		WRAP_AND_RETURN(unsigned long);
	} else if (strcmp(argType, @encode(unsigned long long)) == 0) {
		WRAP_AND_RETURN(unsigned long long);
	} else if (strcmp(argType, @encode(float)) == 0) {
		WRAP_AND_RETURN(float);
	} else if (strcmp(argType, @encode(double)) == 0) {
		WRAP_AND_RETURN(double);
	} else if (strcmp(argType, @encode(BOOL)) == 0) {
		WRAP_AND_RETURN(BOOL);
	} else if (strcmp(argType, @encode(bool)) == 0) {
		WRAP_AND_RETURN(BOOL);
	} else if (strcmp(argType, @encode(char *)) == 0) {
		WRAP_AND_RETURN(const char *);
	} else if (strcmp(argType, @encode(void (^)(void))) == 0) {
		__unsafe_unretained id block = nil;
		[self getArgument:&block atIndex:(NSInteger)index];
		return [block copy];
	} else {
		NSUInteger valueSize = 0;
		NSGetSizeAndAlignment(argType, &valueSize, NULL);

		unsigned char valueBytes[valueSize];
		[self getArgument:valueBytes atIndex:(NSInteger)index];

		return [NSValue valueWithBytes:valueBytes objCType:argType];
	}
	return nil;
#undef WRAP_AND_RETURN
}

- (NSArray *)aspects_arguments {
	NSMutableArray *argumentsArray = [NSMutableArray array];
	for (NSUInteger idx = 2; idx < self.methodSignature.numberOfArguments; idx++) {
		[argumentsArray addObject:[self REFLAspect_argumentAtIndex:idx] ?: NSNull.null];
	}
	return [argumentsArray copy];
}

@end

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - REFLAspectIdentifier

@implementation REFLAspectIdentifier

+ (instancetype)identifierWithSelector:(SEL)selector object:(id)object options:(REFLAspectOptions)options block:(id)block error:(NSError **)error {
    NSCParameterAssert(block);
    NSCParameterAssert(selector);
    NSMethodSignature *blockSignature = REFLAspect_blockMethodSignature(block, error); //TODO: check signature compatibility, etc.
    if (!REFLAspect_isCompatibleBlockSignature(blockSignature, object, selector, error)) {
        return nil;
    }

    REFLAspectIdentifier *identifier = nil;
    if (blockSignature) {
        identifier = [REFLAspectIdentifier new];
        identifier.selector = selector;
        identifier.block = block;
        identifier.blockSignature = blockSignature;
        identifier.options = options;
        identifier.object = object; //weak
    }
    return identifier;
}

- (BOOL)invokeWithInfo:(id<REFLAspectInfo>)info {
    NSInvocation *blockInvocation = [NSInvocation invocationWithMethodSignature:self.blockSignature];
    NSInvocation *originalInvocation = info.originalInvocation;
    NSUInteger numberOfArguments = self.blockSignature.numberOfArguments;

    //Be extra paranoid. We already check that on hook registration.
    if (numberOfArguments > originalInvocation.methodSignature.numberOfArguments) {
        REFLAspectLogError(@"Block has too many arguments. Not calling %@", info);
        return NO;
    }

    //The `self` of the block will be the REFLAspectInfo. Optional.
    if (numberOfArguments > 1) {
        [blockInvocation setArgument:&info atIndex:1];
    }
    
	void *argBuf = NULL;
    for (NSUInteger idx = 2; idx < numberOfArguments; idx++) {
        const char *type = [originalInvocation.methodSignature getArgumentTypeAtIndex:idx];
		NSUInteger argSize;
		NSGetSizeAndAlignment(type, &argSize, NULL);
        
		if (!(argBuf = reallocf(argBuf, argSize))) {
            REFLAspectLogError(@"Failed to allocate memory for block invocation.");
			return NO;
		}
        
		[originalInvocation getArgument:argBuf atIndex:idx];
		[blockInvocation setArgument:argBuf atIndex:idx];
    }
    
    [blockInvocation invokeWithTarget:self.block];
    
    if (argBuf != NULL) {
        free(argBuf);
    }
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, SEL:%@ object:%@ options:%tu block:%@ (#%tu args)>", self.class, self, NSStringFromSelector(self.selector), self.object, self.options, self.block, self.blockSignature.numberOfArguments];
}

- (BOOL)remove {
    return REFLAspect_remove(self, NULL);
}

@end

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - REFLAspectsContainer

@implementation REFLAspectsContainer

- (BOOL)hasREFLAspects {
    return self.beforeREFLAspects.count > 0 || self.insteadREFLAspects.count > 0 || self.afterREFLAspects.count > 0;
}

- (void)addREFLAspect:(REFLAspectIdentifier *)aspect withOptions:(REFLAspectOptions)options {
    NSParameterAssert(aspect);
    NSUInteger position = options&REFLAspectPositionFilter;
    switch (position) {
        case REFLAspectPositionBefore:  self.beforeREFLAspects  = [(self.beforeREFLAspects ?:@[]) arrayByAddingObject:aspect]; break;
        case REFLAspectPositionInstead: self.insteadREFLAspects = [(self.insteadREFLAspects?:@[]) arrayByAddingObject:aspect]; break;
        case REFLAspectPositionAfter:   self.afterREFLAspects   = [(self.afterREFLAspects  ?:@[]) arrayByAddingObject:aspect]; break;
    }
}

- (BOOL)removeREFLAspect:(id)aspect {
    for (NSString *aspectArrayName in @[NSStringFromSelector(@selector(beforeREFLAspects)),
                                        NSStringFromSelector(@selector(insteadREFLAspects)),
                                        NSStringFromSelector(@selector(afterREFLAspects))]) {
        NSArray *array = [self valueForKey:aspectArrayName];
        NSUInteger index = [array indexOfObjectIdenticalTo:aspect];
        if (array && index != NSNotFound) {
            NSMutableArray *newArray = [NSMutableArray arrayWithArray:array];
            [newArray removeObjectAtIndex:index];
            [self setValue:newArray forKey:aspectArrayName];
            return YES;
        }
    }
    return NO;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, before:%@, instead:%@, after:%@>", self.class, self, self.beforeREFLAspects, self.insteadREFLAspects, self.afterREFLAspects];
}

@end

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - REFLAspectInfo

@implementation REFLAspectInfo

@synthesize arguments = _arguments;

- (id)initWithInstance:(__unsafe_unretained id)instance invocation:(NSInvocation *)invocation {
    NSCParameterAssert(instance);
    NSCParameterAssert(invocation);
    if (self = [super init]) {
        _instance = instance;
        _originalInvocation = invocation;
    }
    return self;
}

- (NSArray *)arguments {
    //Lazily evaluate arguments, boxing is expensive.
    if (!_arguments) {
        _arguments = self.originalInvocation.aspects_arguments;
    }
    return _arguments;
}

@end
