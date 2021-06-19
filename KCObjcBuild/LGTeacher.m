//
//  LGTeacher.m
//  KCObjcBuild
//
//  Created by cooci on 2021/2/20.
//

#import "LGTeacher.h"

@implementation LGTeacher
- (instancetype)init{
    if (self == [super init]) {
        NSLog(@"我来了: %@",self);
        return self;
    }
    return nil;
}

- (void)teacherSay{
    NSLog(@"%s",__func__);
}

@end
