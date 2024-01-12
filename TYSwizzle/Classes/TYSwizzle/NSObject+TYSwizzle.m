//
//  NSObject+TYSwizzle.m
//  Method_swizzle
//
//  Created by Tory on 2019/9/13.
//  Copyright © 2019 Tory. All rights reserved.
//

#import "NSObject+TYSwizzle.h"
#import "TYLoggerManager.h"

#import <objc/runtime.h>

#if !__has_feature(objc_arc)
#error This code needs ARC. Use compiler option -fobjc-arc
#endif

#if DEBUG
// #define TYLog(format, ...) printf("TIME:%s FILE:%s(%d行) FUNCTION:%s \n %s\n\n", __TIME__, [[[NSString stringWithUTF8String:__FILE__] lastPathComponent] UTF8String], __LINE__, __PRETTY_FUNCTION__, [[NSString stringWithFormat:(format), ##__VA_ARGS__] UTF8String])
#define TYLog(format, ...)
#else
#define TYLog(format, ...)
#endif

NS_INLINE NSString *TYKeyStr(const void *key) {
    char buffer[20];
    sprintf(buffer, "%p", key);
    return [NSString stringWithUTF8String:buffer];
}

/// 类名中功能key之间的分隔符
static NSString *const kDelimiter = @"|";
/// KVO 类型关键字
static NSString *const kKVOClassKeyword = @"NSKVONotifying_";

static NSString *const kYES = @"YES";

/// KVO 中 keyPath 和 options 获取规则
static NSString *const kGetKeyPathAndOptionsRule = @"Keypath:(\\w+),Options:<New:(\\w+),Old:(\\w+),Prior:(\\w+)>";

static const char *kObserver = "_observer";
static const char *kContext = "_context";
static const char *kObservances = "_observances";

/** 完成替换的方法记录字典，结构如下：
 {
    "0x1b7f0ea1c|UIView" = "{(\n    layoutSubviews\n)}";
    "0x1b7f0ea1c|UIBuleView" = "{(\n    dealloc,\n    \"setFrame:\"\n)}";
    "0x10422ee6b|0x1b7f0ea1c|UIBuleView" = "{(\n    layoutSubviews\n)}";
    "0x10422ee60|0x10422ee6b|0x1b7f0ea1c|UIBuleView" = "{(\n    layoutSubviews\n)}";
    "0x104235328|0x10422ee60|0x10422ee6b|0x1b7f0ea1c|UIBuleView" = "{(\n    frame,\n    \"hitTest:withEvent:\",\n    layoutSubviews,\n    \"setFrame:\"\n)}";
}
 */
static NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *ty_swizzledClassesDictionary(void) {
    static NSMutableDictionary *swizzledClasses;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        swizzledClasses = [NSMutableDictionary new];
    });
    return swizzledClasses;
}

static NSMutableSet<NSString *> *swizzledMethods(NSString *className) {
    NSMutableDictionary *classesDictionary = ty_swizzledClassesDictionary();
    NSMutableSet<NSString *> *swizzledMethods = classesDictionary[className];
    if (!swizzledMethods) {
        swizzledMethods = [NSMutableSet new];
        classesDictionary[className] = swizzledMethods;
    }
    return swizzledMethods;
}

/** 原方法IMP记录字典，结构如下：
 {
     "0x10422ee60|0x10422ee6b|0x1b7f0ea1c|UIBuleView" =     {
         layoutSubviews = "{length = 8, bytes = 0x30026a0401000000}";
     };
     "0x10422ee6b|0x1b7f0ea1c|UIBuleView" =     {
         layoutSubviews = "{length = 8, bytes = 0x60a5220401000000}";
     };
     "0x104235328|0x10422ee60|0x10422ee6b|0x1b7f0ea1c|UIBuleView" =     {
         frame = "{length = 8, bytes = 0xd4f6220501000000}";
         "hitTest:withEvent:" = "{length = 8, bytes = 0x0cf7220501000000}";
         layoutSubviews = "{length = 8, bytes = 0x40026a0401000000}";
         "setFrame:" = "{length = 8, bytes = 0x08026a0401000000}";
     };
     "0x1b7f0ea1c|UIBuleView" =     {
         dealloc = "{length = 8, bytes = 0x04a5220401000000}";
         "setFrame:" = "{length = 8, bytes = 0xb0a5220401000000}";
     };
     "0x1b7f0ea1c|UIView" =     {
         layoutSubviews = "{length = 8, bytes = 0xc4f6220501000000}";
     };
 }
 */
static NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSValue *> *> *ty_originImpDictionary(void) {
    static NSMutableDictionary *impDictionary;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        impDictionary = [NSMutableDictionary new];
    });
    return impDictionary;
}

static NSMutableDictionary<NSString *, NSValue *> *originImpDictForClass(NSString *className) {
    NSMutableDictionary *originImpDictionary = ty_originImpDictionary();
    NSMutableDictionary<NSString *, NSValue *> *originImpDict = originImpDictionary[className];
    if (!originImpDict) {
        originImpDict = [NSMutableDictionary new];
        originImpDictionary[className] = originImpDict;
    }
    return originImpDict;
}

@interface TYObservanceInfo : NSObject

@property (nonatomic, strong) NSObject *observer;
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, assign) NSKeyValueObservingOptions options;
@property (nonatomic, strong) id _Nullable context;

@end

@implementation TYObservanceInfo

- (instancetype)initWithObserver:(NSObject *)observer
                         keyPath:(NSString *)keyPath
                         options:(NSKeyValueObservingOptions)options
                         context:(id _Nullable)context {
    self = [super init];
    if (self) {
        _observer = observer;
        _keyPath = keyPath;
        _options = options;
        _context = context;
    }
    return self;
}

@end

@implementation NSObject (TYSwizzle)

- (Class)ty_realClass {
    return object_getClass(self);
}

- (IMP _Nullable)ty_swizzleInstanceMethod:(SEL)selector
                                      key:(const void *)key
                            newImpFactory:(TYSwizzleImpFactoryBlock)factoryBlock {
    TYLog(@"\n\n\n[TYSwizzle]====== swizzle begin ======");
    if (!selector || !key || !factoryBlock) {
        NSAssert(NO, @"nil");
        return nil;
    }

    IMP originSelectorImp = nil;
    @synchronized(ty_swizzledClassesDictionary()) {
        // 获取当前真实类型
        Class isa = object_getClass(self);
        NSString *className = NSStringFromClass(isa);

        BOOL isKVOClass = NO;
        // 目前已知的 KVO 类名有两种格式：“..NSKVONotifying_NSString” 和 “NSKVONotifying_NSString”
        if ([className containsString:kKVOClassKeyword]) {
            isKVOClass = YES;
            Class superClass = class_getSuperclass(isa);
            className = NSStringFromClass(superClass);
            if ([className containsString:kKVOClassKeyword]) {
                NSString *log = [NSString stringWithFormat:@"[TYSwizzle] 父类还是 kvo 类型(%@)的情况未兼容过，查看如何兼容", object_getClass(self)];
                [TYLoggerManager logAndAssert:NO message:log];
                return nil;
            }

            isa = NSClassFromString(className);
            if (!isa) {
                NSString *log = [NSString stringWithFormat:@"[TYSwizzle] 获取不到 kvo 类型(%@)的父类", isa];
                [TYLoggerManager logAndAssert:NO message:log];
                return nil;
            }
        }

        NSString *selectorName = NSStringFromSelector(selector);
        NSString *keyStr = TYKeyStr(key);
        TYLog(@"[TYSwizzle] real class: %@, keyStr: %@, selector: %@", object_getClass(self), keyStr, selectorName);

        Class subClass = isa;
        NSString *subClassName = className;
        BOOL shouldAddMethod = NO;
        NSArray<NSString *> *keys = [className componentsSeparatedByString:kDelimiter];
        if ([keys containsObject:keyStr]) { // 类中包含功能
            if ([keys.firstObject isEqualToString:keyStr]) {
                shouldAddMethod = ![swizzledMethods(className) containsObject:selectorName];
            } else {
#if DEBUG
                // 检查使用是否异常
                NSInteger index = [keys indexOfObject:keyStr];
                NSString *classNameForKey = [[keys subarrayWithRange:NSMakeRange(index, keys.count - index)]
                    componentsJoinedByString:kDelimiter];
                NSAssert1([swizzledMethods(classNameForKey) containsObject:selectorName],
                          @"该替换功能实际是通过实现子类的方式进行实现，因此一个key(%@)对应的所有替换必须再下一次实现子类之前完成，请检查错误",
                          keyStr);
#endif
                return nil;
            }
        } else { // 使用子类
            subClassName = [NSString stringWithFormat:@"%@%@%@", keyStr, kDelimiter, className];
            subClass = NSClassFromString(subClassName);
            if (subClass) {
                shouldAddMethod = ![swizzledMethods(subClassName) containsObject:selectorName];
                TYLog(@"[TYSwizzle] %@ 的子类 %@ 已经创建， %@添加替换函数实现", className, subClassName, shouldAddMethod ? @"" : @"不");
            } else { // 创建子类
                TYLog(@"[TYSwizzle] 创建 %@ 的子类 %@", className, subClassName);
                shouldAddMethod = YES;
                subClass = [self createSubClassWithName:subClassName forClass:isa];
            }

            NSArray<TYObservanceInfo *> *observationInfos = nil;
            if (isKVOClass) { // 先移除 kvo
                observationInfos = [self getKVOObservanceInfos];
                [self removeObserverForKVO:observationInfos];
            }
            // !!!: 修改 isa 指针指向子类（将原对象类型修改为子类类型）
            TYLog(@"[TYSwizzle] isa(%@) 修改为 %@", isa, subClass);
            object_setClass(self, subClass);
            if (observationInfos.count) { // 再添加 kvo
                [self addObserverForKVO:observationInfos];
            }
        }

        if (shouldAddMethod) { // 添加新的函数实现
            originSelectorImp = [self createNewMethodForClass:subClass
                                                 subClassName:subClassName
                                                     selector:selector
                                                 selectorName:selectorName
                                                 factoryBlock:factoryBlock];
        } else {
            originSelectorImp = (IMP)[originImpDictForClass(subClassName)[selectorName] pointerValue];
            TYLog(@"[TYSwizzle] subClass(%@) 不需要添加函数实现，从记录中获取 selectorName(%@) 的 IMP(%@)", subClass, selectorName, [NSValue valueWithPointer:originSelectorImp]);
            if (!originSelectorImp) {
                [TYLoggerManager logAndAssert:NO message:@"[TYSwizzle] 未找到原方法IMP，请检查？"];
            }
        }

        TYLog(@"[TYSwizzle] 方法替换记录, ty_swizzledClassesDictionary：%@,\nty_originImpDictionary: %@", ty_swizzledClassesDictionary(), ty_originImpDictionary());
    }

    TYLog(@"[TYSwizzle]====== swizzle end ======\n\n\n");
    return originSelectorImp;
}

/// 创建子类
/// - Parameters:
///   - subClassName: 子类类名
///   - superClass: 父类类型
- (Class)createSubClassWithName:(NSString *)subClassName forClass:(Class)superClass {
    // 创建子类
    const char *name = [subClassName cStringUsingEncoding:NSUTF8StringEncoding];
    Class subClass = objc_allocateClassPair(superClass, name, 0);
    objc_registerClassPair(subClass);

    // !!!: 重写 -class 方法，返回最原始的 class 类型，不改变 class 函数获取到的类型
    Class class = self.class;
    TYLog(@"[TYSwizzle] -class 函数返回类型: %@", class);
    class_addMethod(subClass, @selector(class), imp_implementationWithBlock(^{
                        return class;
                    }),
                    "#@:");
    return subClass;
}

/// 为类型创建方法
/// - Parameters:
///   - class: 类型
///   - subClassName: 类名
///   - selector: 方法
///   - selectorName: 方法名
///   - factoryBlock: 外部替换方法实现block
- (IMP)createNewMethodForClass:(Class)class
                  subClassName:(NSString *)subClassName
                      selector:(SEL _Nonnull)selector
                  selectorName:(NSString *)selectorName
                  factoryBlock:(TYSwizzleImpFactoryBlock _Nonnull)factoryBlock {
    // 获取原来的函数 IMP (子类还未实现对应方法，因此获取的是父类的方法)
    IMP originSelectorImp = method_getImplementation(class_getInstanceMethod(class, selector));
    // factoryBlock 返回父类方法 IMP 给外部调用
    id newIMPBlock = factoryBlock(*originSelectorImp);
    IMP newIMP = imp_implementationWithBlock(newIMPBlock);

    // 子类添加新的函数实现
    Method method = class_getInstanceMethod(class, selector);
    const char *methodType = method_getTypeEncoding(method);
    class_addMethod(class, selector, (IMP) newIMP, methodType);

    TYLog(@"[TYSwizzle] 添加替换函数实现 subClass: %@, selector: %@, newIMP: %@, originSelectorImp: %@", subClassName, selectorName, [NSValue valueWithPointer:newIMP], [NSValue valueWithPointer:originSelectorImp]);
    // 记录子类实现的方法
    [swizzledMethods(subClassName) addObject:selectorName];
    // 记录子类实现方法对应的原方法
    originImpDictForClass(subClassName)[selectorName] = [NSValue valueWithPointer:*originSelectorImp];
    return originSelectorImp;
}

#pragma mark - kvo

- (void)addObserverForKVO:(NSArray<TYObservanceInfo *> *)observationInfos {
    if (observationInfos.count == 0) {
        return;
    }

    for (TYObservanceInfo *observationInfo in observationInfos) {
        [self addObserver:observationInfo.observer
               forKeyPath:observationInfo.keyPath
                  options:observationInfo.options
                  context:(__bridge void *_Nullable) (observationInfo.context)];
    }
}

- (void)removeObserverForKVO:(NSArray<TYObservanceInfo *> *)observationInfos {
    if (observationInfos.count == 0) {
        return;
    }

    for (TYObservanceInfo *observationInfo in observationInfos) {
        [self removeObserver:observationInfo.observer
                  forKeyPath:observationInfo.keyPath
                     context:(__bridge void *_Nullable) (observationInfo.context)];
    }
}

/// 获取当前实例的 kvo 信息
- (NSArray<TYObservanceInfo *> *)getKVOObservanceInfos {
    id observationInfo = [self observationInfo];
    if (!observationInfo) {
        return @[];
    }

    NSArray<id> *observances = [self getIvar:kObservances from:observationInfo];
    NSInteger count = observances.count;
    NSMutableArray<TYObservanceInfo *> *observanceInfoList = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; i++) {
        // [observance description]:  <NSKeyValueObservance 0x600000c87f60: Observer: 0x106007e90, Key path: name, Options: <New: YES, Old: NO, Prior: NO> Context: 0x106007e90, Property: 0x600000c87f00>
        id observance = observances[i];
        NSString *observanceInfo = [[observance description] stringByReplacingOccurrencesOfString:@" " withString:@""];

        NSString *keyPath = nil;
        NSKeyValueObservingOptions options = NSNotFound;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:kGetKeyPathAndOptionsRule
                                                                               options:0
                                                                                 error:nil];
        NSTextCheckingResult *result = [regex firstMatchInString:observanceInfo
                                                         options:0
                                                           range:NSMakeRange(0, [observanceInfo length])];
        if (result && result.numberOfRanges == 5) {
            NSRange keyPathRange = [result rangeAtIndex:1];
            NSRange newRange = [result rangeAtIndex:2];
            NSRange oldRange = [result rangeAtIndex:3];
            NSRange priorRange = [result rangeAtIndex:4];

            keyPath = [observanceInfo substringWithRange:keyPathRange];
            NSString *newValue = [observanceInfo substringWithRange:newRange];
            NSString *oldValue = [observanceInfo substringWithRange:oldRange];
            NSString *priorValue = [observanceInfo substringWithRange:priorRange];

            if ([newValue isEqualToString:kYES]) {
                options = options == NSNotFound ? NSKeyValueObservingOptionNew : options | NSKeyValueObservingOptionNew;
            }
            if ([oldValue isEqualToString:kYES]) {
                options = options == NSNotFound ? NSKeyValueObservingOptionOld : options | NSKeyValueObservingOptionOld;
            }
            if ([priorValue isEqualToString:kYES]) {
                options = options == NSNotFound ? NSKeyValueObservingOptionPrior : options | NSKeyValueObservingOptionPrior;
            }
        } else {
            [TYLoggerManager logAndAssert:NO message:@"[TYSwizzle] 找不到对应 keyPath 和 options，请检查"];
            continue;
        }

        NSObject *observer = [self getIvar:kObserver from:observance];
        id context = [self getIvar:kContext from:observance];
        if (observer) {
            [observanceInfoList addObject:[[TYObservanceInfo alloc] initWithObserver:observer
                                                                             keyPath:keyPath
                                                                             options:options
                                                                             context:context]];
        } else {
            [TYLoggerManager logAndAssert:NO message:@"[TYSwizzle] 找不到对应 observer，请检查"];
        }
    }

    return observanceInfoList.copy;
}

- (id _Nullable)getIvar:(const char *)ivarName from:(id)object {
    Ivar ivar = class_getInstanceVariable([object class], ivarName);
    if (ivar) {
        return object_getIvar(object, ivar);
    }
    return nil;
}

@end
