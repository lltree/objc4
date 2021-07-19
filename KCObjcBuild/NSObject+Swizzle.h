//
//  NSObject+Swizzle.h
//  KCObjcBuild
//
//  Created by lltree on 2021/7/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (Swizzle)

- (void)oneSwizzleInstanceMethod:(SEL)origSelector withMethod:(SEL)newSelector;

- (void)twoSwizzleInstanceMethod:(SEL)origSelector withMethod:(SEL)newSelector;

@end

NS_ASSUME_NONNULL_END
