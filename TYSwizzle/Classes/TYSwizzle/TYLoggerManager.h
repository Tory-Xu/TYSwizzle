//
//  TYLoggerManager.h
//  TYSwizzle
//
//  Created by xuqingming on 2023/12/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TYLoggerManager : NSObject

+ (void)setLogFunction:(void (^)(NSString *))logFunction;

+ (void)logAndAssert:(BOOL)condition message:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
