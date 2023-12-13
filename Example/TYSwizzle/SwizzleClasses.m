//
//  SwizzleClasses.m
//  Swizzle
//
//  Created by 徐徐徐 on 2023/12/4.
//

#import "SwizzleClasses.h"
#import <TYSwizzle/NSObject+TYSwizzle.h>
#import <objc/runtime.h>

@implementation UICustomView

@end

@implementation UIBuleView

/**
 /// 添加关联属性
 TYSWAssociatedBlockGetter(lj_originFrame, Lj_originFrame, TYSWArguments(CGRect));
 TYSWCallBlock(weakSelf.lj_originFrame, frame);
 */

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubview:self.blueView];
        self.blueView.frame = CGRectMake(10, 10, 40, 40);

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

        TYSwizzle(
            self.blueView,
            @selector(layoutSubviews),
            TYSWReturnType(void),
            TYSWArguments(),
            @selector(setFrame:),
            TYSWReplacement({
                NSLog(@"red view");

                TYSWCallOriginal();

                self.backgroundColor = [UIColor blueColor];
            }));

        // dealloc 替换
        TYSwizzleDealloc(
            self,
            @selector(setFrame:), TYSWReplacement({
                NSLog(@"[dealloc] self(%@) dealloc 被释放", self);
                TYSWCallOriginal();
            }));
    }
    return self;
}

- (void)dealloc {
    NSLog(@"[dealloc] origin dealloc(%@)  被释放", self);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    NSLog(@"🌹🌹🌹 origin layoutSubviews 🌹🌹🌹");
}

- (void)setFrame:(CGRect)frame {
    NSLog(@"UICustomView origin setFrame: %@", NSStringFromCGRect(frame));
    [super setFrame:frame];
}

- (UIView *)blueView {
    if (_blueView == nil) {
        _blueView = [[UIView alloc] init];
    }
    return _blueView;
}

@end

@implementation UIView (Test)

static char kFunctionKey;

- (void)hookColor {
    TYSwizzle(
        self,
        @selector(layoutSubviews),
        TYSWReturnType(void),
        TYSWArguments(),
        @selector(hookColor),
        TYSWReplacement({
            NSLog(@"hookColor");

            TYSWCallOriginal();

            self.backgroundColor = [UIColor grayColor];
        }));
}

- (void)hookBorder {
    TYSwizzle(
        self,
        @selector(layoutSubviews),
        TYSWReturnType(void),
        TYSWArguments(),
        @selector(hookBorder),
        TYSWReplacement({
            NSLog(@"hookBorder");

            TYSWCallOriginal();

            self.layer.borderWidth = 2;
            self.layer.borderColor = UIColor.redColor.CGColor;
        }));
}

- (void)hookCornerRadius {
    [self hookCornerRadius0];
    [self hookCornerRadius1];
    [self hookCornerRadius2];
    [self hookCornerRadius3];
}

- (void)hookCornerRadius0 {
    TYSwizzle(
        self,
        @selector(layoutSubviews),
        TYSWReturnType(void),
        TYSWArguments(),
        &kFunctionKey,
        TYSWReplacement({
            NSLog(@"hookCornerRadius");

            TYSWCallOriginal();

            self.layer.cornerRadius = 10;
        }));
}

- (void)hookCornerRadius1 {
    TYSwizzle(
        self,
        @selector(setFrame:),
        TYSWReturnType(void),
        TYSWArguments(CGRect frame),
        &kFunctionKey,
        TYSWReplacement({
            NSLog(@"UIView swizzled setFrame: %@", NSStringFromCGRect(frame));
            CGRect newFrame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width + 40, frame.size.height + 10);
            TYSWCallOriginal(newFrame);
        }));
}

- (void)hookCornerRadius2 {
    TYSwizzle(
        self,
        @selector(frame),
        TYSWReturnType(CGRect),
        TYSWArguments(),
        &kFunctionKey,
        TYSWReplacement({
            CGRect frame = TYSWCallOriginal();
            return CGRectMake(frame.origin.x, frame.origin.y, frame.size.width - 40, frame.size.height - 10);
        }));
}

- (void)hookCornerRadius3 {
    TYSwizzle(
        self,
        @selector(hitTest:withEvent:),
        TYSWReturnType(UIView *),
        TYSWArguments(CGPoint point, UIEvent * event),
        &kFunctionKey,
        TYSWReplacement({
            UIView *view = TYSWCallOriginal(point, event);

            NSLog(@"----- test hitTest:withEvent:  -> view: %@", view);
            NSLog(@"----- test hitTest:withEvent:  -> class: %@", [self class]);

            return view;
        }));
}

- (void)classA {
    TYSwizzle(
        self,
        @selector(frame),
        TYSWReturnType(CGRect),
        TYSWArguments(),
        @selector(classA),
        TYSWReplacement({
            return TYSWCallOriginal();
        }));
}

- (void)classALayoutSubviews {
    TYSwizzle(
        self,
        @selector(layoutSubviews),
        TYSWReturnType(void),
        TYSWArguments(),
        @selector(classA),
        TYSWReplacement({
            NSLog(@"classALayoutSubviews");
            TYSWCallOriginal();
        }));
}

- (void)classB {
    TYSwizzle(
        self,
        @selector(frame),
        TYSWReturnType(CGRect),
        TYSWArguments(),
        @selector(classB),
        TYSWReplacement({
            return TYSWCallOriginal();
        }));
}

- (void)classBLayoutSubviews {
    TYSwizzle(
        self,
        @selector(layoutSubviews),
        TYSWReturnType(void),
        TYSWArguments(),
        @selector(classB),
        TYSWReplacement({
            NSLog(@"classBLayoutSubviews");
            TYSWCallOriginal();
        }));
}

- (void)classC {
    TYSwizzle(
        self,
        @selector(frame),
        TYSWReturnType(CGRect),
        TYSWArguments(),
        @selector(classC),
        TYSWReplacement({
            return TYSWCallOriginal();
        }));
}

- (void)classCLayoutSubviews {
    TYSwizzle(
        self,
        @selector(layoutSubviews),
        TYSWReturnType(void),
        TYSWArguments(),
        @selector(classC),
        TYSWReplacement({
            NSLog(@"classCLayoutSubviews");
            TYSWCallOriginal();
        }));
}

- (void)classD {
    TYSwizzle(
        self,
        @selector(frame),
        TYSWReturnType(CGRect),
        TYSWArguments(),
        @selector(classD),
        TYSWReplacement({
            return TYSWCallOriginal();
        }));
}

- (void)classDLayoutSubviews {
    TYSwizzle(
        self,
        @selector(layoutSubviews),
        TYSWReturnType(void),
        TYSWArguments(),
        @selector(classD),
        TYSWReplacement({
            NSLog(@"classDLayoutSubviews");
            TYSWCallOriginal();
        }));
}

- (void)classE {
    TYSwizzle(
        self,
        @selector(frame),
        TYSWReturnType(CGRect),
        TYSWArguments(),
        @selector(classE),
        TYSWReplacement({
            return TYSWCallOriginal();
        }));
}

- (void)classELayoutSubviews {
    TYSwizzle(
        self,
        @selector(layoutSubviews),
        TYSWReturnType(void),
        TYSWArguments(),
        @selector(classE),
        TYSWReplacement({
            NSLog(@"classELayoutSubviews");
            TYSWCallOriginal();
        }));
}

@end
