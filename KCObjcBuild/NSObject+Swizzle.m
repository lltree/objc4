//
//  NSObject+Swizzle.m
//  KCObjcBuild
//
//  Created by lltree on 2021/7/19.
//

#import "NSObject+Swizzle.h"
#import <objc/runtime.h>

@implementation NSObject (Swizzle)

- (void)oneSwizzleInstanceMethod:(SEL)origSelector withMethod:(SEL)newSelector {
    Class cls = [self class];
    Method originalMethod = class_getInstanceMethod(cls, origSelector);
    Method swizzledMethod = class_getInstanceMethod(cls, newSelector);

    IMP previousIMP = class_replaceMethod(cls,
                                          origSelector,
                                          method_getImplementation(swizzledMethod),
                                          method_getTypeEncoding(swizzledMethod));

    class_replaceMethod(cls,
                        newSelector,
                        previousIMP,
                        method_getTypeEncoding(originalMethod));
}

- (void)twoSwizzleInstanceMethod:(SEL)origSelector withMethod:(SEL)newSelector {

    Class cls = [self class];
    Method originalMethod = class_getInstanceMethod(cls, origSelector);
    Method swizzledMethod = class_getInstanceMethod(cls, newSelector);
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

@end
