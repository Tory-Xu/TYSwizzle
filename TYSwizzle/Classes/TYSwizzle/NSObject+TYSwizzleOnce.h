//
//  NSObject+TYSwizzleOnce.h
//  Method_swizzle
//
//  Created by Tory on 2019/9/13.
//  Copyright © 2019 Tory. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (TYSwizzleOnce)

- (BOOL)ty_swizzleInstanceMethod:(SEL)selector
                         inClass:(Class)classToSwizzle
                             imp:(IMP)imp
                           types:(const char *)types;

@end

NS_ASSUME_NONNULL_END
