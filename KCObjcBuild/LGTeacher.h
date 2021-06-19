//
//  LGTeacher.h
//  KCObjcBuild
//
//  Created by cooci on 2021/2/20.
//

#import <Foundation/Foundation.h>
#import "LGPerson.h"

NS_ASSUME_NONNULL_BEGIN

@interface LGTeacher : LGPerson
@property (nonatomic, copy) NSString *hobby;
- (void)teacherSay;
@end

NS_ASSUME_NONNULL_END
