//
//  TYSwizzleTests.m
//  TYSwizzleTests
//
//  Created by 756165690@qq.com on 09/19/2019.
//  Copyright (c) 2019 756165690@qq.com. All rights reserved.
//

@import XCTest;

#import "RSTestsLog.h"
#import <TYSwizzle/NSObject+TYSwizzle.h>
#import <objc/runtime.h>

@interface RSSwizzleTestClass_A : NSObject
@end
@implementation RSSwizzleTestClass_A

- (void)empty {
}

- (BOOL)methodReturningBOOL {
    return YES;
}

- (NSString *)string {
    return @"ABC";
}

- (int)calc:(int)num {
    return num;
}

- (NSNumber *)sumFloat:(float)floatSummand withDouble:(double)doubleSummand {
    return @(floatSummand + doubleSummand);
}

- (void)methodWithArgument:(id)arg {
}

- (void)repeatSwizzleMethodWithSameKey {
}

- (void)repeatSwizzleMethodWithDifferentKey {
}

- (void)methodForSwizzling1 {
}
- (void)methodForSwizzling2 {
}
- (void)methodForSwizzling3 {
}

@end

@interface RSSwizzleTestClass_B : RSSwizzleTestClass_A

@end

@implementation RSSwizzleTestClass_B

@end

@interface RSSwizzleTestClass_Hook : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSUInteger age;

@end

@implementation RSSwizzleTestClass_Hook

+ (void)load {
    [self exchangeInstance:self.class selector:@selector(string) withSwizzledSelector:@selector(hook_string)];
    [self exchangeInstance:self.class selector:@selector(calc:) withSwizzledSelector:@selector(hook_calc:)];
}

- (void)dealloc {
    NSLog(@"=============== [test] RSSwizzleTestClass_Hook dealloc ==========");
}

- (NSString *)string {
    return @"ABC";
}

- (NSString *)hook_string {
    return [[self hook_string] stringByAppendingString:@"-hook"];
}

- (int)calc:(int)num {
    return num;
}

- (int)hook_calc:(int)num {
    return [self hook_calc:num] + 1;
}

+ (BOOL)exchangeInstance:(Class)class
                selector:(SEL)originalSelector
    withSwizzledSelector:(SEL)swizzledSelector {
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

    if (!originalMethod || !swizzledMethod) {
        return NO;
    }
    // 若已经存在，则添加会失败
    BOOL didAddMethod = class_addMethod(class,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));

    // 若原来的方法并不存在，则添加即可
    if (didAddMethod) {
        class_replaceMethod(class,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }

    return YES;
}

@end

@interface RSSwizzleTestClass_Hook (Hook2)

@end

@implementation RSSwizzleTestClass_Hook (Hook2)

+ (void)load {
    [self exchangeInstance:self.class selector:@selector(string) withSwizzledSelector:@selector(hook2_string)];
}

- (NSString *)hook2_string {
    return [[self hook2_string] stringByAppendingString:@"-hook2"];
}

@end

typedef NSString * (^GetStringBlock)(void);

@interface Tests : XCTestCase

@property (nonatomic, copy) NSString * (^originString)(void);

@end

@implementation Tests

NS_INLINE NSString *TYKeyStr(const void *key) {
    char buffer[20];
    sprintf(buffer, "%p", key);
    return [NSString stringWithUTF8String:buffer];
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark - 一个功能key替换多个方法
- (void)testSwizzleMethods {
    RSSwizzleTestClass_A *objectA = [RSSwizzleTestClass_A new];
    TYSwizzle(
        objectA,
        @selector(empty),
        TYSWReturnType(void),
        TYSWArguments(),
        @selector(testSwizzleMethods),
        TYSWReplacement({
            RSTestsLog(@"1");
            TYSWCallOriginal();
        }));

    TYSwizzle(
        objectA,
        @selector(string),
        TYSWReturnType(NSString *),
        TYSWArguments(),
        @selector(testSwizzleMethods),
        TYSWReplacement({
            RSTestsLog(@"2");
            return [TYSWCallOriginal() stringByAppendingString:@"abc"];
        }));

    TYSwizzle(
        objectA,
        @selector(calc:),
        TYSWReturnType(int),
        TYSWArguments(int num),
        @selector(testSwizzleMethods),
        TYSWReplacement({
            RSTestsLog(@"3");
            return TYSWCallOriginal(num) + 2;
        }));

    TYSwizzle(
        objectA,
        @selector(sumFloat:withDouble:),
        TYSWReturnType(NSNumber *),
        TYSWArguments(float floatSummand, double doubleSummand),
        @selector(testSwizzleMethods),
        TYSWReplacement({
            RSTestsLog(@"4");
            return @(TYSWCallOriginal(floatSummand, doubleSummand).floatValue * 2);
        }));

    [objectA empty];
    NSString *str = [objectA string];
    int calcResult = [objectA calc:3];
    BOOL boolValue = [objectA methodReturningBOOL];
    NSNumber *num = [objectA sumFloat:4.5 withDouble:2.6];

    ASSERT_LOG_IS(@"1234");
    CLEAR_LOG();

    XCTAssertTrue(calcResult == 5);
    XCTAssertTrue([str isEqualToString:@"ABCabc"]);
    XCTAssertTrue(boolValue == YES);
    XCTAssertTrue(num.floatValue == 14.2f);

    NSString *className = [NSString stringWithFormat:@"%@|RSSwizzleTestClass_A", TYKeyStr(@selector(testSwizzleMethods))];
    XCTAssertTrue([className isEqualToString:NSStringFromClass([objectA ty_realClass])]);
}

#pragma mark - 同一个功能key，多次替换同一个方法
- (void)testRepeateSwizzleMethodWithSameKey {
    RSSwizzleTestClass_A *objectA = [RSSwizzleTestClass_A new];
    TYSwizzle(
        objectA,
        @selector(repeatSwizzleMethodWithSameKey),
        TYSWReturnType(BOOL),
        TYSWArguments(),
        @selector(testRepeateSwizzleMethodWithSameKey),
        TYSWReplacement({
            RSTestsLog(@"1");
            return TYSWCallOriginal();
        }));
    TYSwizzle(
        objectA,
        @selector(repeatSwizzleMethodWithSameKey),
        TYSWReturnType(BOOL),
        TYSWArguments(),
        @selector(testRepeateSwizzleMethodWithSameKey),
        TYSWReplacement({
            RSTestsLog(@"2");
            return TYSWCallOriginal();
        }));
    TYSwizzle(
        objectA,
        @selector(repeatSwizzleMethodWithSameKey),
        TYSWReturnType(BOOL),
        TYSWArguments(),
        @selector(testRepeateSwizzleMethodWithSameKey),
        TYSWReplacement({
            RSTestsLog(@"3");
            return TYSWCallOriginal();
        }));

    [objectA repeatSwizzleMethodWithSameKey];

    ASSERT_LOG_IS(@"1");
    CLEAR_LOG();

    NSString *className = [NSString stringWithFormat:@"%@|RSSwizzleTestClass_A", TYKeyStr(@selector(testRepeateSwizzleMethodWithSameKey))];
    XCTAssertTrue([className isEqualToString:NSStringFromClass([objectA ty_realClass])]);
}

#pragma mark - 不同功能key，多次替换同一个方法
- (void)testRepeateSwizzleMethodWithDifferentKey {
    static char key2;
    static char key3;

    RSSwizzleTestClass_A *objectA = [RSSwizzleTestClass_A new];
    TYSwizzle(
        objectA,
        @selector(repeatSwizzleMethodWithDifferentKey),
        TYSWReturnType(BOOL),
        TYSWArguments(),
        @selector(testRepeateSwizzleMethodWithDifferentKey),
        TYSWReplacement({
            RSTestsLog(@"1");
            return TYSWCallOriginal();
        }));
    TYSwizzle(
        objectA,
        @selector(repeatSwizzleMethodWithDifferentKey),
        TYSWReturnType(BOOL),
        TYSWArguments(),
        &key2,
        TYSWReplacement({
            RSTestsLog(@"2");
            return TYSWCallOriginal();
        }));
    TYSwizzle(
        objectA,
        @selector(repeatSwizzleMethodWithDifferentKey),
        TYSWReturnType(BOOL),
        TYSWArguments(),
        &key3,
        TYSWReplacement({
            RSTestsLog(@"3");
            return TYSWCallOriginal();
        }));

    [objectA repeatSwizzleMethodWithDifferentKey];
    ASSERT_LOG_IS(@"321");
    CLEAR_LOG();
}

#pragma mark - 多个功能key替换多个相同方法
- (void)testRepeateSwizzleMethods {
    static char key1;
    static char key2;
    static char key3;

    RSSwizzleTestClass_A *objectA = [RSSwizzleTestClass_A new];
    TYSwizzle(
        objectA,
        @selector(methodForSwizzling1),
        TYSWReturnType(BOOL),
        TYSWArguments(),
        &key1,
        TYSWReplacement({
            RSTestsLog(@"key1-m1|");
            return TYSWCallOriginal();
        }));
    TYSwizzle(
        objectA,
        @selector(methodForSwizzling2),
        TYSWReturnType(BOOL),
        TYSWArguments(),
        &key1,
        TYSWReplacement({
            RSTestsLog(@"key1-m2|");
            return TYSWCallOriginal();
        }));
    TYSwizzle(
        objectA,
        @selector(methodForSwizzling3),
        TYSWReturnType(BOOL),
        TYSWArguments(),
        &key1,
        TYSWReplacement({
            RSTestsLog(@"key1-m3|");
            return TYSWCallOriginal();
        }));

    TYSwizzle(
        objectA,
        @selector(methodForSwizzling1),
        TYSWReturnType(BOOL),
        TYSWArguments(),
        &key2,
        TYSWReplacement({
            RSTestsLog(@"key2-m1|");
            return TYSWCallOriginal();
        }));
    TYSwizzle(
        objectA,
        @selector(methodForSwizzling2),
        TYSWReturnType(BOOL),
        TYSWArguments(),
        &key2,
        TYSWReplacement({
            RSTestsLog(@"key2-m2|");
            return TYSWCallOriginal();
        }));
    TYSwizzle(
        objectA,
        @selector(methodForSwizzling3),
        TYSWReturnType(BOOL),
        TYSWArguments(),
        &key2,
        TYSWReplacement({
            RSTestsLog(@"key2-m3|");
            return TYSWCallOriginal();
        }));

    TYSwizzle(
        objectA,
        @selector(methodForSwizzling1),
        TYSWReturnType(BOOL),
        TYSWArguments(),
        &key3,
        TYSWReplacement({
            RSTestsLog(@"key3-m1|");
            return TYSWCallOriginal();
        }));
    TYSwizzle(
        objectA,
        @selector(methodForSwizzling2),
        TYSWReturnType(BOOL),
        TYSWArguments(),
        &key3,
        TYSWReplacement({
            RSTestsLog(@"key3-m2|");
            return TYSWCallOriginal();
        }));
    TYSwizzle(
        objectA,
        @selector(methodForSwizzling3),
        TYSWReturnType(BOOL),
        TYSWArguments(),
        &key3,
        TYSWReplacement({
            RSTestsLog(@"key3-m3|");
            return TYSWCallOriginal();
        }));

    [objectA methodForSwizzling1];
    ASSERT_LOG_IS(@"key3-m1|key2-m1|key1-m1|");
    CLEAR_LOG();

    [objectA methodForSwizzling2];
    ASSERT_LOG_IS(@"key3-m2|key2-m2|key1-m2|");
    CLEAR_LOG();

    [objectA methodForSwizzling3];
    ASSERT_LOG_IS(@"key3-m3|key2-m3|key1-m3|");
    CLEAR_LOG();

    NSString *className = [NSString stringWithFormat:@"%@|%@|%@|RSSwizzleTestClass_A", TYKeyStr(&key3), TYKeyStr(&key2), TYKeyStr(&key1)];
    XCTAssertTrue([className isEqualToString:NSStringFromClass([objectA ty_realClass])]);
}

#pragma mark - 测试实例方法替换后对其它实例是否影响
- (void)testSubClass {
    RSSwizzleTestClass_A *objectA = [RSSwizzleTestClass_A new];
    RSSwizzleTestClass_A *objectA2 = [RSSwizzleTestClass_A new];

    TYSwizzle(
        objectA,
        @selector(sumFloat:withDouble:),
        TYSWReturnType(NSNumber *),
        TYSWArguments(float floatSummand, double doubleSummand),
        @selector(testSwizzleMethods),
        TYSWReplacement({
            RSTestsLog(@"4");
            return @(TYSWCallOriginal(floatSummand, doubleSummand).floatValue * 2);
        }));

    [objectA empty];
    NSString *str = [objectA string];
    int calcResult = [objectA calc:3];
    NSNumber *num = [objectA sumFloat:4.5 withDouble:2.6];

    ASSERT_LOG_IS(@"4");
    CLEAR_LOG();

    XCTAssertTrue(calcResult == 3);
    XCTAssertTrue([str isEqualToString:@"ABC"]);
    XCTAssertTrue(num.floatValue == 14.2f);

    NSString *className = [NSString stringWithFormat:@"%@|RSSwizzleTestClass_A", TYKeyStr(@selector(testSwizzleMethods))];
    XCTAssertTrue([className isEqualToString:NSStringFromClass([objectA ty_realClass])]);

    // objectA 实例进行了方法替换，对 RSSwizzleTestClass_A 的其它实例不产生影响
    [objectA2 empty];
    NSString *strA2 = [objectA2 string];
    int calcResultA2 = [objectA2 calc:3];
    NSNumber *numA2 = [objectA2 sumFloat:4.5 withDouble:2.6];
    XCTAssertTrue([strA2 isEqualToString:@"ABC"]);
    XCTAssertTrue(calcResultA2 == 3);
    XCTAssertTrue(numA2.floatValue == 7.1f);

    // RSSwizzleTestClass_B 继承 RSSwizzleTestClass_A，objectA 实例进行了方法替换，对 RSSwizzleTestClass_B 实例不产生影响
    RSSwizzleTestClass_B *objectB = [RSSwizzleTestClass_B new];
    [objectB empty];
    NSString *strB2 = [objectB string];
    int calcResultB2 = [objectB calc:3];
    NSNumber *numB2 = [objectB sumFloat:4.5 withDouble:2.6];

    XCTAssertTrue([strB2 isEqualToString:@"ABC"]);
    XCTAssertTrue(calcResultB2 == 3);
    XCTAssertTrue(numB2.floatValue == 7.1f);
}

#pragma mark - 场景1：常规方法替换 + TYSwizzle 替换场景  场景2：调用原方法

- (void)testNormalSwizzleAndTYSwizzle {
    {
        RSSwizzleTestClass_Hook *objectH = [RSSwizzleTestClass_Hook new];

        TYSwizzleDealloc(
            objectH,
            @selector(testNormalSwizzleAndTYSwizzle),
            TYSWReplacement({
                RSTestsLog(@"dealloc RSSwizzleTestClass_Hook");
                TYSWCallOriginal();
            }));

        // - string 在 RSSwizzleTestClass_Hook 和它的分类中分别进行了一次方法替换
        XCTAssertTrue([[objectH string] isEqualToString:@"ABC-hook-hook2"]);
        // - calc: 仅在 RSSwizzleTestClass_Hook 进行一次方法替换
        XCTAssertTrue([objectH calc:1] == 2);

        TYSwizzleGetOriginImp(
            self.originString,
            TYSWBlockArguments(),
            objectH,
            @selector(string),
            TYSWReturnType(NSString *),
            TYSWArguments(),
            @selector(testNormalSwizzleAndTYSwizzle),
            TYSWReplacement({
                return [TYSWCallOriginal() stringByAppendingString:@"-TYSwizzle"];
            }));
        TYSwizzle(
            objectH,
            @selector(calc:),
            TYSWReturnType(int),
            TYSWArguments(int num),
            @selector(testNormalSwizzleAndTYSwizzle),
            TYSWReplacement({
                return TYSWCallOriginal(num) + 1;
            }));

        XCTAssertTrue([[objectH string] isEqualToString:@"ABC-hook-hook2-TYSwizzle"]);
        XCTAssertTrue([objectH calc:1] == 3);
        if (self.originString) {
            XCTAssertTrue([self.originString() isEqualToString:@"ABC-hook-hook2"]);
        }
    }

    // 对象离开代码块被释放
    ASSERT_LOG_IS(@"dealloc RSSwizzleTestClass_Hook");
    CLEAR_LOG();

    // 对象释放后，调用原方法返回 nil
    NSString *str = self.originString();
    XCTAssertTrue(str == nil);
}

#pragma mark - 测试 kvo 和 TYSwizzle 结合的场景
/// 1.验证 kvo 监听变化是否符合预期，包括多次方法替换生成多次子类的场景
/// 2.验证监听属性的 setter 方法被替换，kvo 是否正常工作
/// 3.验证对象释放是否正常
- (void)testKVOAndTYSwizzle {
    @autoreleasepool {
        static char kFunctionKey;
        static char kFunctionKey2;

        RSSwizzleTestClass_Hook *objectH = [RSSwizzleTestClass_Hook new];

        objectH.name = @"xiaoming";

        ASSERT_LOG_IS(nil);
        CLEAR_LOG();

        [objectH addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:nil];
        [objectH addObserver:self forKeyPath:@"age" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:(__bridge void *_Nullable) (objectH)];

        TYSwizzleDealloc(
            objectH,
            @selector(testKVOAndTYSwizzle),
            TYSWReplacement({
                RSTestsLog(@"dealloc RSSwizzleTestClass_Hook");
                TYSWCallOriginal();
            }));

        objectH.name = @"swizzle 1";
        ASSERT_LOG_IS(@"name");
        CLEAR_LOG();

        objectH.age = 1;
        ASSERT_LOG_IS(@"age");
        CLEAR_LOG();

        TYSwizzle(
            objectH,
            @selector(calc:),
            TYSWReturnType(int),
            TYSWArguments(int num),
            &kFunctionKey,
            TYSWReplacement({
                return TYSWCallOriginal(num) + 1;
            }));

        objectH.name = @"swizzle 2";
        objectH.age = 2;

        ASSERT_LOG_IS(@"nameage");
        CLEAR_LOG();

        TYSwizzle(
            objectH,
            @selector(setName:),
            TYSWReturnType(void),
            TYSWArguments(NSString * name),
            &kFunctionKey2,
            TYSWReplacement({
                TYSWCallOriginal(name);
            }));

        objectH.name = @"swizzle 3";
        objectH.age = 3;

        ASSERT_LOG_IS(@"nameage");
        CLEAR_LOG();

        NSLog(@"[kvo] class: %@, ty_realClass:%@", [objectH class], [objectH ty_realClass]);
    }

    // 对象离开代码块被释放
    ASSERT_LOG_IS(@"dealloc RSSwizzleTestClass_Hook");
    CLEAR_LOG();
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
    NSLog(@"[kvo] keyPath: %@, object: %@, change: %@, context: %@", keyPath, object, change, context);
    RSTestsLog(keyPath);
}

@end
