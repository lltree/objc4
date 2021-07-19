//
//  Base.m
//  KCObjcBuild
//
//  Created by lltree on 2021/7/19.
//

#import "Base.h"
@implementation Base
- (void)print:(NSString *)msg {

    NSLog(@"print-->obj %@ print say:%@", NSStringFromClass(self.class), msg);
}

- (void)hookPrint:(NSString *)msg {

    NSLog(@"hookPrin-->obj %@ print say:%@", NSStringFromClass(self.class), msg);
}

@end

@implementation A
- (void)print:(NSString *)msg {
    NSLog(@"A obj print say:%@", msg);
}

@end

@implementation B

@end
