//
//  NSObject+TYSwizzle.h
//  Method_swizzle
//
//  Created by Tory on 2019/9/13.
//  Copyright © 2019 Tory. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Macros Based API

/// 原方法返回类型：如：TYSWReturnType(void) TYSWReturnType(NSString *)
#define TYSWReturnType(type) type

/// 原方法定义中的参数，如：TYSWArguments(CGRect frame)   TYSWArguments(NSString *name, int age, BOOL isFemale)
#define TYSWArguments(arguments...) _TYSWArguments(arguments)
/// block 中需要传入的参数，如：TYSWBlockArguments(frame)   TYSWCallOriginal(name, age, isFemale)
#define TYSWBlockArguments(arguments...) _TYSWArguments(arguments)

/// 调用原方法
/// - Parameters:
///   - arguments: 原函数的参数，如：TYSWCallOriginal(frame)  TYSWCallOriginal(name, age, isFemale)
#define TYSWCallOriginal(arguments...) _TYSWCallOriginal(arguments)

/// 替换的方法实现内容
/// 案例：
///    TYSWReplacement({
///        NSLog(@"UICustomView swizzled setFrame: %@", NSStringFromCGRect(frame));
///
///        TYSWCallOriginal(frame);
///    })
#define TYSWReplacement(code...) code

/// block 调用
/// 案例：TYSWCallBlock(self.lj_originFrame, frame);
#define TYSWCallBlock(blockName, ...) \
    { !blockName ?: blockName(__VA_ARGS__); }

/// 关联 block 属性，调用 getter 使用时注意判空
/// - Parameters:
///   - blockName: getter 方法名
///   - blockName: setter 方法名
///   - TYSWArguments: block 中的参数
/// 案例：TYSWAssociatedBlockGetter(lj_originFrame, Lj_originFrame, TYSWArguments(CGRect));
#define TYSWAssociatedBlockGetter(blockName, blockSetterName, TYSWArguments)                    \
    -(nullable void (^)(_TYSWDel1Arg(TYSWArguments))) blockName {                               \
        return objc_getAssociatedObject(self, _cmd);                                            \
    }                                                                                           \
    -(void) set##blockSetterName : (nullable void (^)(_TYSWDel1Arg(TYSWArguments))) blockName { \
        objc_setAssociatedObject(self,                                                          \
                                 @selector(blockName),                                          \
                                 blockName,                                                     \
                                 OBJC_ASSOCIATION_COPY);                                        \
    }

#pragma mark - Swizzle Instance Method

/// 替换 -dealloc 方法，在实现代码后调用 TYSWCallOriginal() 释放
/// - Parameters:
///   - object: 需要替换方法的实例
///   - key: 作为标识功能的唯一值，使用和 runtime 中关联属性的 key 一样。
///          方法1：可以使用对应功能函数 @selector(setFrame:)
///          方法2：定义 static char kFunctionKey; 使用时传入 &kFunctionKey
///   - TYSWReplacement: 需要替换的函数实现
/// 案例代码：
///     TYSwizzleDealloc(
///         self,
///         @selector(lj_suspend_swizzleMethod),
///         TYSWReplacement({
///             [self lj_suspend_dealloc];
///             TYSWCallOriginal();
///         }));
#define TYSwizzleDealloc(object,                         \
                         KEY,                            \
                         TYSWReplacement)                \
    {                                                    \
        SEL selector = NSSelectorFromString(@"dealloc"); \
        TYSwizzle(                                       \
            object,                                      \
            selector,                                    \
            TYSWReturnType(void),                        \
            TYSWArguments(),                             \
            KEY,                                         \
            TYSWReplacement);                            \
    }

/// 替换实例对应的方法实现，返回 IMP 为 nil 时表示替换失败，否则成功。如果外部需要调用原方法，使用 TYSwizzleGetOriginImp 宏
/// - Parameters:
///   - object: 需要替换方法的实例
///   - selector: 需要进行替换的方法
///   - TYSWReturnType: 替换方法的返回类型，如：TYSWReturnType(void)  TYSWReturnType(NSString *)
///   - TYSWArguments: 替换方法的参数类型。如：没有参数： TYSWArguments()   有参数：TYSWArguments(NSString *name)   TYSWArguments(CGRect frame)
///   - key: 作为标识功能的唯一值，使用和 runtime 中关联属性的 key 一样。
///          方法1：可以使用对应功能函数 @selector(setFrame:)
///          方法2：定义 static char kFunctionKey; 使用时传入 &kFunctionKey
///   - TYSWReplacement: 需要替换的函数实现
///   案例：
///     - (void)testRepeateSwizzleMethodWithDifferentKey {
///        RSSwizzleTestClass_A *objectA = [RSSwizzleTestClass_A new];
///        TYSwizzle(
///            objectA,
///            @selector(repeatSwizzleMethodWithDifferentKey),
///            TYSWReturnType(BOOL),
///            TYSWArguments(),
///            @selector(testRepeateSwizzleMethodWithDifferentKey),
///            TYSWReplacement({
///                RSTestsLog(@"1");
///                return TYSWCallOriginal();
///            }));
///      }
#define TYSwizzle(object,                                                                                                       \
                  selector,                                                                                                     \
                  TYSWReturnType,                                                                                               \
                  TYSWArguments,                                                                                                \
                  KEY,                                                                                                          \
                  TYSWReplacement)                                                                                              \
    [object ty_swizzleInstanceMethod:selector                                                                                   \
                                 key:KEY                                                                                        \
                       newImpFactory:^id(IMP _Nonnull superSelectorImp) {                                                       \
                           TYSWReturnType (*originalImplementation_)(_TYSWDel3Arg(__unsafe_unretained id, SEL, TYSWArguments)); \
                           SEL selector_ = selector;                                                                            \
                           return ^TYSWReturnType(_TYSWDel2Arg(__unsafe_unretained typeof(object) self,                         \
                                                               TYSWArguments)) {                                                \
                               TYSWReplacement                                                                                  \
                           };                                                                                                   \
                       }];

/// 替换实例对应的方法实现，并且通过 originImpBlock 获取原方法提供外部调用
/// - Parameters:
///   - originImpBlock: 原方法调用 block
///   - TYSWBlockArguments: originImpBlock 中的参数，如：TYSWBlockArguments(frame)  TYSWBlockArguments(name, age, isFemale)
///   - object: 需要替换方法的实例
///   - selector: 需要进行替换的方法
///   - TYSWReturnType: 替换方法的返回类型，如：TYSWReturnType(void)  TYSWReturnType(NSString *)
///   - TYSWArguments: 替换方法的参数类型。如：没有参数： TYSWArguments()   有参数：TYSWArguments(NSString *name)   TYSWArguments(CGRect frame)
///   - key: 作为标识功能的唯一值，使用和 runtime 中关联属性的 key 一样。
///          方法1：可以使用对应功能函数 @selector(setFrame:)
///          方法2：定义 static char kFunctionKey; 使用时传入 &kFunctionKey
///   - TYSWReplacement: 需要替换的函数实现
///   案例：
///        TYSwizzleGetOriginImp(
///            self.originSetFrame,
///            TYSWBlockArguments(frame),
///            self,
///            @selector(setFrame:),
///            TYSWReturnType(void),
///            TYSWArguments(CGRect frame),
///            @selector(setFrame:),
///            TYSWReplacement({
///                NSLog(@"UICustomView swizzled setFrame: %@", NSStringFromCGRect(frame));
///                TYSWCallOriginal(frame);
///            }));
#define TYSwizzleGetOriginImp(originImpBlock,                                                                                 \
                              TYSWBlockArguments,                                                                             \
                              object,                                                                                         \
                              selector,                                                                                       \
                              TYSWReturnType,                                                                                 \
                              TYSWArguments,                                                                                  \
                              KEY,                                                                                            \
                              TYSWReplacement)                                                                                \
    {                                                                                                                         \
        TYSWReturnType (*originalImplementation_)(_TYSWDel3Arg(__unsafe_unretained id, SEL, TYSWArguments));                  \
        IMP originImp = [object ty_swizzleInstanceMethod:selector                                                             \
                                                     key:KEY                                                                  \
                                           newImpFactory:^id(IMP _Nonnull superSelectorImp) {                                 \
                                               SEL selector_ = selector;                                                      \
                                               return ^TYSWReturnType(_TYSWDel2Arg(__unsafe_unretained typeof(object) self,   \
                                                                                   TYSWArguments)) {                          \
                                                   TYSWReplacement                                                            \
                                               };                                                                             \
                                           }];                                                                                \
        typeof(object) __weak weakObjcet = object;                                                                            \
        originImpBlock = ^TYSWReturnType(_TYSWDel1Arg(TYSWArguments)) {                                                       \
            typeof(weakObjcet) __strong strongObjcet = weakObjcet;                                                            \
            return ((__typeof(originalImplementation_)) originImp)(_TYSWDel3Arg(strongObjcet, selector, TYSWBlockArguments)); \
        };                                                                                                                    \
    }

#pragma mark - Implementation details

#define _TYSWCallOriginal(arguments...) \
    ((__typeof(originalImplementation_)) superSelectorImp)(self, selector_, ##arguments)

#define _TYSWWrapArg(args...) args

#define _TYSWDel1Arg(a1, args...) args
#define _TYSWDel2Arg(a1, a2, args...) a1, ##args
#define _TYSWDel3Arg(a1, a2, a3, args...) a1, a2, ##args

#define _TYSWArguments(arguments...) DEL, ##arguments

typedef id _Nonnull (^TYSwizzleImpFactoryBlock)(IMP originSelectorImp);

@interface NSObject (TYSwizzle)

/// 获取真实类型
- (Class)ty_realClass;

/// 替换实例对应的方法实现，返回 IMP 为 nil 时表示替换失败，否则成功。通过 IMP，外部也可以调用替换前的方法。
/// 注意：不要直接使用这个函数，通过上面的宏定义进行使用
/// - Parameters:
///   - selector: 需要进行替换的方法
///   - key: 作为标识功能的唯一值，使用和 runtime 中关联属性的 key 一样。
///          方法1：可以使用对应功能函数 @selector(setFrame:)
///          方法2：定义 static char kFunctionKey; 使用时传入 &kFunctionKey
///   - factoryBlock: 需要替换的函数实现
- (IMP _Nullable)ty_swizzleInstanceMethod:(SEL)selector
                                      key:(const void *)key
                            newImpFactory:(TYSwizzleImpFactoryBlock)factoryBlock;

@end

NS_ASSUME_NONNULL_END
