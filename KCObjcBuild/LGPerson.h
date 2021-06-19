//
//  LGPerson.h
//  KCObjcBuild
//
//  Created by cooci on 2021/1/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LGPerson : NSObject{
    NSString *hobby;
}

@property (nonatomic, copy) NSString *name;
@property (nonatomic) int age;

// 方法 - + OC  C/C++ 函数
// 元类
- (void)saySomething;
+ (void)sayNB;

@end

NS_ASSUME_NONNULL_END
