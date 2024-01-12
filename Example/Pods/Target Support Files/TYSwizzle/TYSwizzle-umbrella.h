#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "NSObject+TYSwizzle.h"
#import "TYLoggerManager.h"

FOUNDATION_EXPORT double TYSwizzleVersionNumber;
FOUNDATION_EXPORT const unsigned char TYSwizzleVersionString[];

