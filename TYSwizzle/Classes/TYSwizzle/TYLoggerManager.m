//
//  TYLoggerManager.m
//  TYSwizzle
//
//  Created by xuqingming on 2023/12/19.
//

#import "TYLoggerManager.h"

static void (^customLogFunction)(NSString *) = nil;

@implementation TYLoggerManager

+ (void)setLogFunction:(void (^)(NSString *))logFunction {
    customLogFunction = logFunction;
}

+ (void)logAndAssert:(BOOL)condition message:(NSString *)message {
    NSAssert(condition, message);
    if (message && customLogFunction) {
        customLogFunction(message);
    }
}

@end
