//
//  Base.h
//  KCObjcBuild
//
//  Created by lltree on 2021/7/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@interface Base : NSObject
- (void)print:(NSString *)msg;
- (void)hookPrint:(NSString *)msg;
@end



//A只实现了print方法，没有实现hookPrint方法。
@interface A : Base
@end


//B啥都没实现。
@interface B : Base
@end


NS_ASSUME_NONNULL_END
