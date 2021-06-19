//
//  LGPerson.m
//  KCObjcBuild
//
//  Created by cooci on 2021/1/18.
//

#import "LGPerson.h"

@implementation LGPerson

- (instancetype)init{
    if (self = [super init]) {
        self.name = @"Cooci";
    }
    return self;
}

+ (void)sayNB{
    
}

- (void)saySomething{
    NSLog(@"%s",__func__);
}

@end
