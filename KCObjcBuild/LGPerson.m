//
//  LGPerson.m
//  KCObjcBuild
//
//  Created by cooci on 2021/1/18.
//

#import "LGPerson.h"
#import <objc/runtime.h>

@implementation LGPerson

//+(void)load{
//
//}

//- (instancetype)init{
//    if (self = [super init]) {
//        self.name = @"Cooci";
//    }
//    return self;
//}

+ (void)sayNB{
    
}

+(BOOL)resolveInstanceMethod:(SEL)sel{
    
    if (sel == @selector(test)) {
        
        IMP saySomethingImp = class_getMethodImplementation(self,@selector(saySomething));
        
        Method meth = class_getInstanceMethod(self, @selector(saySomething));
       
        class_addMethod(self, sel, saySomethingImp,  method_getTypeEncoding(meth));
        
        
        return YES;
    }
    
    return [super resolveInstanceMethod:sel];
}

- (void)saySomething{
    
   
    NSLog(@"%s",__func__);
}

@end
