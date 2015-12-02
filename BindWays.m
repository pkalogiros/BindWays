//
//  Created by Pantelis Kalogiros on 26/11/15
//

#import "BindWays.h"
#import <objc/runtime.h>

@interface BindWayStorage : NSObject

@property void *CTX;

+ (id) getInstance;

@end

@implementation BindWayStorage
{
    NSMutableDictionary *bindict_;
}

+ (id)getInstance
{
    static BindWayStorage *instance = nil;
    static dispatch_once_t once;

    dispatch_once (&once, ^{
        instance = [[self alloc] init];
    });

    return (instance);
}

- (BindWayStorage *)init
{
    static void *CTX = &CTX;
    self.CTX = CTX;
    bindict_ = [NSMutableDictionary dictionary];

    return (self);
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)source
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context
{
    NSMutableDictionary *target_dict = [bindict_ objectForKey:mem_address (source)];
    if (!target_dict) return ;
    
    NSPointerArray *events_arr = [target_dict objectForKey:keyPath];
    if (!events_arr) return  ;

    UInt16 l = (UInt16)events_arr.count;

    for (int i = 0; i < l; i += 2)
    {
        id target = [events_arr pointerAtIndex:i];
        NSString *key = [events_arr pointerAtIndex:i + 1];

        if ([target valueForKey:key] != [source valueForKey:keyPath])
            [target setValue:[source valueForKey:keyPath] forKey:key];
    }
}

- (void)setUpFor:(id) source
             and:(id) target
         withKey:(NSString *)key_source
          andKey:(NSString *)key_target
{
    NSString *address = mem_address (source);

    if (!key_target) key_target = key_source;
    
    NSMutableDictionary *events_dict = [bindict_ objectForKey:address];
    if (!events_dict)
    {
        events_dict = [NSMutableDictionary dictionary];
        [bindict_ setObject:events_dict forKey:address];
        
        [self attachToDealloc:source];
    }

    NSPointerArray *events_arr = [events_dict objectForKey:key_source];
    if (!events_arr)
    {
        events_arr = [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsWeakMemory];
        [events_dict setObject:events_arr forKey:key_source];
    }
    else
        clean_array_from_nil (events_arr);

    [events_arr addPointer:(__bridge void * _Nullable)(target)];
    [events_arr addPointer:(__bridge void * _Nullable)(key_target)];
}

- (void)attachToDealloc:(id)obj
{
    Class class = [obj class];
        
    SEL dealloc_sel = NSSelectorFromString (@"dealloc");
    Method dealloc_meth = class_getInstanceMethod (class, dealloc_sel);
    IMP dealloc_imp = method_getImplementation (dealloc_meth);

    IMP dealloc_imp_swizz = imp_implementationWithBlock (^(void *el) {
        @autoreleasepool
        {
            [self unbindAll:(__bridge id)el];
            ((void (*)(void *, SEL))dealloc_imp) (el, dealloc_sel);
        }
    });
        
    class_replaceMethod(class,
                        dealloc_sel,
                        dealloc_imp_swizz,
                        method_getTypeEncoding (dealloc_meth));
}

- (void)unbindAll:(id)obj
{
    NSString *address = mem_address (obj);
    NSDictionary *dict = [bindict_ objectForKey:address];
    for (NSString * key in dict)
        [obj removeObserver:self forKeyPath:key context:self.CTX];
    
    [bindict_ removeObjectForKey:address];
}

- (void)unbindAll:(id)obj ofProperty:(NSString *)property
{
    NSString *address = mem_address (obj);
    NSMutableDictionary *dict = [bindict_ objectForKey:address];

    [dict removeObjectForKey:property];
    [obj removeObserver:self forKeyPath:property context:self.CTX];
}

static inline NSString * mem_address (id o)
{
    return ([NSString stringWithFormat:@"%p", o]);
}

static inline void clean_array_from_nil (NSPointerArray *arr)
{
    int l = (int)arr.count - 2;
    if (l < 1) return ;

    for (;l > 0;l -= 2)
    {
        if ([arr pointerAtIndex:l] == nil)
        {
            [arr removePointerAtIndex:l];
            [arr removePointerAtIndex:l];
        }
    }
}

@end

@implementation OneWay

+ (void)bind:(__weak NSString *)property of:(__weak id)source to:(__weak id)parent
{
    [OneWay bind:property of:source to:nil of:parent];
}

+ (void)bind:(__weak NSString *)prop of:(__weak id)source to:(__weak NSString *)property of:(__weak id)target
{
    BindWayStorage *storage = [BindWayStorage getInstance];
    if (!property) property = prop;

    [source addObserver:storage
             forKeyPath:prop
                options:NSKeyValueObservingOptionNew
                context:storage.CTX];
    [storage setUpFor:source and:target withKey:prop andKey:property];
}

+ (void)unbindAll:(__weak id)source
{
    BindWayStorage *storage = [BindWayStorage getInstance];
    [storage unbindAll:source];
}

+ (void)unbindAll:(__weak id)source ofProperty:(NSString *)property
{
    BindWayStorage *storage = [BindWayStorage getInstance];
    [storage unbindAll:source ofProperty:property];
}

@end


@implementation TwoWay

+ (void)bind:(__weak NSString *)property of:(__weak id)source to:(__weak id)parent
{
    [TwoWay bind:property of:source to:nil of:parent];
}

+ (void)bind:(__weak NSString *)prop of:(__weak id)source to:(__weak NSString *)property of:(__weak id)target
{
    BindWayStorage *storage = [BindWayStorage getInstance];
    if (!property) property = prop;

    [source addObserver:storage
             forKeyPath:prop
                options:NSKeyValueObservingOptionNew
                context:storage.CTX];
    [storage setUpFor:source and:target withKey:prop andKey:property];

    [target addObserver:storage
             forKeyPath:property
                options:NSKeyValueObservingOptionNew
                context:storage.CTX];
    [storage setUpFor:target and:source withKey:property andKey:prop];
}
// @todo finish the unbind methods for 2 way
+ (void)unbindAll:(__weak id)source
{
}
// unbind all listeners between 2 objects
+ (void)unbindAll:(__weak id)source and:(__weak id)target
{
}
// unbind all listeners between 2 objects with specified property
+ (void)unbindAll:(__weak id)source ofProperty:(NSString *)property
{
}

@end