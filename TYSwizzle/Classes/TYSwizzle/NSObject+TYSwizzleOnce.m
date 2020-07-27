//
//  NSObject+TYSwizzleOnce.m
//  Method_swizzle
//
//  Created by Tory on 2019/9/13.
//  Copyright © 2019 Tory. All rights reserved.
//

#import "NSObject+TYSwizzleOnce.h"
#import "objc/runtime.h"

static NSString *const kTYSwizzlePrefid = @"TYSwizzle";

@implementation NSObject (TYSwizzleOnce)

/**
 
 @{
    @"swizzle_className0": [@"swizzleMethodName0, @"swizzleMethodName0"],
    @"swizzle_className1": [@"swizzleMethodName0, @"swizzleMethodName0"]
 }
 */
static NSMutableDictionary *ty_swizzledClassesDictionary() {
    static NSMutableDictionary *swizzledClasses;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        swizzledClasses = [NSMutableDictionary new];
    });
    return swizzledClasses;
}

static NSMutableSet *swizzledMethodsForClass(Class class){
    if (!class) {
        return nil;
    }
    
    NSMutableDictionary *classesDictionary = ty_swizzledClassesDictionary();
    NSString *className = NSStringFromClass(class);
    NSMutableSet *swizzledMethods = [classesDictionary objectForKey:className];
    if (!swizzledMethods) {
        swizzledMethods = [NSMutableSet new];
        [classesDictionary setObject:swizzledMethods forKey:className];
    }
    return swizzledMethods;
}

- (BOOL)ty_swizzleInstanceMethod:(SEL)selector
                      inClass:(Class)classToSwizzle
                          imp:(IMP)imp
                        types:(const char *)types {
    if (!classToSwizzle || !selector || !imp) {
        NSAssert(NO, @"nil");
        return NO;
    }
    
    NSString *className = NSStringFromClass(classToSwizzle);
    NSString *subClassName = [NSString stringWithFormat:@"%@_%@", kTYSwizzlePrefid, className];
    Class subClass = NSClassFromString(subClassName);
    if (!subClass) { // 类对象不存在，动态创建
        NSLog(@"创建 %@ 的子类 %@", className, subClassName);
        // 子类类名
        NSString *subClassName = [NSString stringWithFormat:@"%@_%@", kTYSwizzlePrefid, className];
        const char *name = [subClassName cStringUsingEncoding:NSUTF8StringEncoding];
        
        // 创建
        subClass = objc_allocateClassPair([classToSwizzle class], name, 0);
        objc_registerClassPair(subClass);
        
        // 重写 -class 方法，返回原对象 class 类型
        class_addMethod(subClass, @selector(class), (IMP)ty_class, "#@:");
    } else {
        NSLog(@"%@ 的子类 %@ 已经创建", className, subClassName);
    }
    
    Class isa = object_getClass(self);
    if (![NSStringFromClass(isa) hasPrefix:kTYSwizzlePrefid]) {
        // 修改 isa 指针指向子类（将原对象类型修改为子类类型）
        object_setClass(self, subClass);
    }
    /**
     
     key 对应替换的方法，
     
     NSObject > TYSwi_NSObject > TYSwi_TYSwi_NSObject
     
                            class       isa
     NSObject               NSObject    NSObject
     TYSwi_NSObject         NSObject    TYSwi_NSObject
     TYSwi_TYSwi_NSObject
     */
    
    
    NSMutableSet *swizzledMethods = swizzledMethodsForClass(subClass);
    if ([swizzledMethods containsObject:NSStringFromSelector(selector)]) { // 已经 swizzle 了该方法
        NSLog(@"%@ 类型已经 swizzle 了 %@ 方法", subClass, NSStringFromSelector(selector));
        return YES;
    }

    // NSMutableSet 存储已经 Swizzle 过的方法
    class_addMethod(subClass, selector, (IMP)imp, types);
    [swizzledMethods addObject:NSStringFromSelector(selector)];
    return YES;
}



OBJC_EXPORT Class _Nullable ty_class(id self, SEL _cmd) {
//    IMP superClassMethodImp = [[self superclass] instanceMethodForSelector:_cmd];
//    NSAssert(superClassMethodImp, @"父类方法实现指针获取不到");
//    if (superClassMethodImp) {
//        ((int(*)(id,SEL))superClassMethodImp)(self, _cmd);
//    }
    
    return class_getSuperclass(object_getClass(self));
}

@end
