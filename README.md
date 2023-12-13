# TYSwizzle

[![CI Status](https://img.shields.io/travis/756165690@qq.com/TYSwizzle.svg?style=flat)](https://travis-ci.org/756165690@qq.com/TYSwizzle)
[![Version](https://img.shields.io/cocoapods/v/TYSwizzle.svg?style=flat)](https://cocoapods.org/pods/TYSwizzle)
[![License](https://img.shields.io/cocoapods/l/TYSwizzle.svg?style=flat)](https://cocoapods.org/pods/TYSwizzle)
[![Platform](https://img.shields.io/cocoapods/p/TYSwizzle.svg?style=flat)](https://cocoapods.org/pods/TYSwizzle)

通过动态创建子类的方式实现实例方法替换的效果，只对当前实例生效的方法替换，不影响全局

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

TYSwizzle is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'TYSwizzle'
```

## 使用教程

在 test.m 单元测试和 TYViewController.m 中案例。

### 替换 dealloc 方法

需要注意的是，调用父类 dealloc 需要放在最后，和 mrc 中重写 dealloc 是一样的道理。

```objc
        RSSwizzleTestClass_Hook *objectH = [RSSwizzleTestClass_Hook new];

        TYSwizzleDealloc(
            objectH,
            @selector(testNormalSwizzleAndTYSwizzle),
            TYSWReplacement({
                RSTestsLog(@"dealloc RSSwizzleTestClass_Hook");
                TYSWCallOriginal();
            }));

```

### 替换其它方法

对下面类型实例进行方法替换

```objective-c
RSSwizzleTestClass_A *objectA = [RSSwizzleTestClass_A new];
```

RSSwizzleTestClass_A 代码如下：

```objective-c
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
```

#### 1、无返回值无参数

```objc
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
```

#### 2、有返回值无参数

```objective-c
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
```

#### 3、有返回值有参数

```objective-c
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
```

### 外部需要调用原方法的场景

下面代码实现调用原 -string 方法的效果：

- 定义 block 属性，用于持有原方法的调用

```objective-c
@property (nonatomic, copy) NSString * (^originString)(void);
```

- 进行方法替换，比正常的方法替换多次2个参数
  - 第一个参数 originImpBlock：用于持有原方法调用的 block
  - 第二个参数 TYSWBlockArguments：原方法对应到 block 中需要传入的参数

```objective-c
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
```

- 调用原 -string 方法。这里需要注意对 block 进行判空
```objective-c
        if (self.originString) {
            NSString *str = self.originString();
        }
```

另一个调用原 setFrame: 方法的案例

```objective-c
        TYSwizzleGetOriginImp(
            self.originSetFrame,
            TYSWBlockArguments(frame),
            self,
            @selector(setFrame:),
            TYSWReturnType(void),
            TYSWArguments(CGRect frame),
            @selector(setFrame:),
            TYSWReplacement({
                NSLog(@"UICustomView swizzled setFrame: %@", NSStringFromCGRect(frame));

                TYSWCallOriginal(frame);
            }));
```

### 注意点

#### 1、替换代码块中注意点

1. 代码块中的 self 是传入的实例，比如下面代码 TYSWReplacement 代码块中的 self 是 self.blueView
2. 代码块中不要使用到代码块以外的局部变量。下面替换方法代码每次执行时，第一次完成方法替换后，后续执行时不会使用最新的代码块实现替换后的方法，因此代码块中只会持有第一次替换时代码块依赖到的数据。也是因此将代码块中的 self 设计为传入的实例，避免使用调用此代码的 self 导致结果不符合预期。

```objective-c
        TYSwizzle(
            self.blueView,
            @selector(layoutSubviews),
            TYSWReturnType(void),
            TYSWArguments(),
            @selector(setFrame:),
            TYSWReplacement({
                TYSWCallOriginal();
                self.backgroundColor = [UIColor blueColor];
            }));
```



#### 2、是否能够交叉完成不同功能中的方法替换？

答：不可以。如果你这样做，方法实现内部会通过断言报错

```objective-c
NSAssert1([swizzledMethods(classNameForKey) containsObject:selectorName],
          @"该替换功能实际是通过实现子类的方式进行实现，因此一个key(%@)对应的所有替换必须再下一次实现子类之前完成，请检查错误",
          keyStr);
```

##### 原因说明

上面介绍过本组件通过“动态实现子类，子类实现对应方法在调用父类方法”来实现方法替换的效果。比如

- A功能：需要替换 layoutSubviews 和 setFrame:

- B功能需要实现 layoutSubViews 和 setFrame:

现在，对 BaseClass 的实例进行 A 功能的 setFrame: 替换，在进行 B 功能的 layoutSubviews 和 setFrame: 替换，类的几个关系如下：

```
BaseClass -> ClassA -> ClassAB
```

此时 ClassAB 的 layoutSubviews 中调用的父类 layoutSubviews 是 BaseClass 的，因为 ClassA 未实现 layoutSubviews。

最后，在进行 A 的 layoutSubviews 替换，此时的类型是 ClassAB，需要回到父类 ClassA 中实现 layoutSubviews 并调用 BaseClass 的 layoutSubviews。

setFrame: 和 layoutSubviews 调用关系如下，这会导致调用 ClassAB 实例时不会调用到 ClassA 的 layoutSubviews 方法。

```
// setFrame:
ClassAB.setFrame: ->ClassAB.setFrame: -> BaseClass.setFrame:

// layoutSubviews
ClassAB.layoutSubviews -> BaseClass.layoutSubviews
ClassA.layoutSubviews -> BaseClass.layoutSubviews

```



## 实现思路

1.参考 KVO 的实现原理：使用 KVO 时动态创建实例的子类，并且将 isa 指针指向动态创建的子类 Class。（详细内容自行查找资料）
2.参考 RSSwizzle 中宏的使用，提供友好的接口。

因此，我们可以使用相同的思路实现方法替换的效果：
对 ClassA 的 method1 进行方法替换，可以实现子类 ClassB，并且重写 method1 并且调用 [super method1] ，这样就能够达到我们的目的。 

## 需要解决的问题
### 动态创建子类时，如何对子类进行命名？

这里需要解决命名重复、和什么时候需要创建子类的问题。

#### 第一点：什么时候需要创建子类？

方法替换的目的一般都伴随着对应的一个功能，举例：

实现扩展视图点击响应区域效果，此时就需要在分类中通过关联属性关联一个设置扩展点击区域的属性 `UIEdgeInsets lj_extension_edgeInsets`，对应这个功能点需要替换 `- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event` 和 `- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event` 这两个方法。因此，这两个方法的替换可以作为一个子类进行实现。

总结：一组方法的替换应该和一个功能相对应，这个功能就作为一次继承实现一个子类。

#### 第二点：命名规则

##### 1、一个实例进行多组方法替换的场景

如果需要实现n组不同的功能，需要完成n组方法的替换，就需要进行n次继承实现n个子类

为了便于讲解，下面命名按照如下规则命名：

- ClassA：表示具备A功能
- ClassAB：表示具备A和B的功能，ClassA 实例设置B功能时动态创建 ClassAB
- ClassABC：表示具备A、B和C的功能，ClassA 实例设置B功能时动态创建 ClassAB，ClassAB 实例设置C功能时动态创建 ClassABC
- 依次类推

```objective-c
BaseClass -> ClassA -> ClassAB -> ClassABC -> ... -> ClassABC...N
```

##### 2、不同实例实现不同方法替换的场景

A、B、C 三组功能都是基于 BaseClass 类型的实例进行实现的，因此都是基于 BaseClass 实现子类完成对应的方法替换。此时 ClassA、ClassB、ClassC 之间时没有任何关系的。

```objective-c
BaseClass -> ClassA
BaseClass -> ClassB
BaseClass -> ClassC
```

##### 3、实例按照不同顺序设置A、B功能的场景

如果 BaseClass 实例先设置A功能在设置B功能，结果如下：

```objective-c
BaseClass -> ClassA -> ClassAB
```

相反的，如果 BaseClass 实例先设置B功能在设置A功能，结果如下：

```objective-c
BaseClass -> ClassB -> ClassBA
```

#### 第三点：动态创建的子类如何命名保证唯一性？

参考关联属性的做法，关联属性时需要传入 key，通常使用下面两种方式：

1. 使用 getter 方法

```objective-c
- (void)setLj_edgeInsets:(UIEdgeInsets)lj_edgeInsets {
    objc_setAssociatedObject(self,
                             @selector(lj_edgeInsets),
                             [NSValue valueWithUIEdgeInsets:lj_edgeInsets],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
```

2. 定义静态变量

```objective-c
static char kAssociateKey;
- (void)setLj_edgeInsets:(UIEdgeInsets)lj_edgeInsets {
    objc_setAssociatedObject(self,
                             &kAssociateKey,
                             [NSValue valueWithUIEdgeInsets:lj_edgeInsets],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
```

创建子类时按照功能进行划分：

- 第一种：使用对应功能的方法 `@selector(methodName)` 
- 第二种自己第一功能 key：`static char kFunctionKey;`



## Author

756165690@qq.com, 756165690@qq.com

## License

TYSwizzle is available under the MIT license. See the LICENSE file for more info.
