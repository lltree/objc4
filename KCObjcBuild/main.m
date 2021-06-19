//
//  main.m
//  KCObjcBuild
//
//  Created by cooci on 2021/1/5.
// KC 重磅提示 调试工程很重要 源码直观就是爽
// ⚠️编译调试不能过: 请你检查以下几小点⚠️
// ①: enable hardened runtime -> NO
// ②: build phase -> denpendenice -> objc
// 爽了之后,还来一个 👍

// void _objc_autoreleasePoolPrint(void);
#import <Foundation/Foundation.h>
#import "LGPerson.h"
#import "LGTeacher.h"

void lgKindofDemo(void){
    BOOL re1 = [(id)[NSObject class] isKindOfClass:[NSObject class]];       //
    BOOL re2 = [(id)[NSObject class] isMemberOfClass:[NSObject class]];     //
    BOOL re3 = [(id)[LGPerson class] isKindOfClass:[LGPerson class]];       //
    BOOL re4 = [(id)[LGPerson class] isMemberOfClass:[LGPerson class]];     //
    NSLog(@" re1 :%hhd\n re2 :%hhd\n re3 :%hhd\n re4 :%hhd\n",re1,re2,re3,re4);

    BOOL re5 = [(id)[NSObject alloc] isKindOfClass:[NSObject class]];       //
    BOOL re6 = [(id)[NSObject alloc] isMemberOfClass:[NSObject class]];     //
    BOOL re7 = [(id)[LGPerson alloc] isKindOfClass:[LGPerson class]];       //
    BOOL re8 = [(id)[LGPerson alloc] isMemberOfClass:[LGPerson class]];     //
    NSLog(@" re5 :%hhd\n re6 :%hhd\n re7 :%hhd\n re8 :%hhd\n",re5,re6,re7,re8);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // class_data_bits_t
        LGPerson *p = [[LGPerson alloc] init];
        NSLog(@"%@",p);
    }
    return 0;
}
