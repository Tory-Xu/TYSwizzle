//
//  TYViewController.m
//  TYSwizzle
//
//  Created by 756165690@qq.com on 09/19/2019.
//  Copyright (c) 2019 756165690@qq.com. All rights reserved.
//

#import "SwizzleClasses.h"
#import "TYViewController.h"
#import <TYSwizzle/NSObject+TYSwizzle.h>

@interface TYViewController ()

@property (nonatomic, strong) UICustomView *testView;
@property (nonatomic, strong) UIBuleView *buleView;

@end

@implementation TYViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    //    NSLog(@"\n\n\n did end viewDidLoad ===== self.testView.class: %@, superclass: %@", self.testView.class, self.testView.superclass);
    //
    //    [self.testView hookColor];
    //    [self.testView hookBorder];
    //    [self.testView hookCornerRadius];
    //
    //    [self.view addSubview:self.testView];
    //    self.testView.frame = CGRectMake(100, 100, 100, 100);
    //
    //    NSLog(@"\n\n\n did end viewDidLoad ===== self.testView.class: %@, superclass: %@", self.testView.class, self.testView.superclass);
    //
    //    NSLog(@"self.testView.frame: %@", NSStringFromCGRect(self.testView.frame));
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self test3];
}

#pragma mark - 场景：测试重复创建视图场景

- (void)test1 {
    [self.testView removeFromSuperview];

    static CGFloat changeY = 0;
    static NSInteger tag = 0;

    UICustomView *testView = [[UICustomView alloc] init];
    self.testView = testView;
    testView.backgroundColor = [UIColor greenColor];

    if (tag == 0) { // 1 2 3
        [self.testView hookColor];
        [self.testView hookBorder];
        [self.testView hookCornerRadius];
    } else if (tag == 1) { // 1 3 2
        [self.testView hookColor];
        [self.testView hookCornerRadius];
        [self.testView hookBorder];
    } else if (tag == 2) { // 2 3 1
        [self.testView hookBorder];
        [self.testView hookCornerRadius];
        [self.testView hookColor];
    } else if (tag == 3) { // 2 1 3
        [self.testView hookBorder];
        [self.testView hookColor];
        [self.testView hookCornerRadius];
    } else if (tag == 4) {
        [self.testView hookBorder];

        [self.testView hookCornerRadius0];
        [self.testView hookCornerRadius1];
        [self.testView hookCornerRadius2];
        [self.testView hookCornerRadius3];

        [self.testView hookColor];
    }

    [self.view addSubview:self.testView];
    self.testView.frame = CGRectMake(100, 100 + changeY, 100, 100);

    NSLog(@"\n\n\n tag: %ld ===== self.testView.class: %@, ty_realClass: %@", tag, self.testView.class, [self.testView ty_realClass]);
    NSLog(@"\n\n\n ===== self.testView.frame: %@", NSStringFromCGRect(self.testView.frame));

    changeY += 10;
    tag = (tag + 1) % 6;
}

- (void)test3 {
    [self.buleView removeFromSuperview];

    static CGFloat changeY = 0;
    static NSInteger tag = 0;

    UIBuleView *testView = [[UIBuleView alloc] init];
    self.buleView = testView;
    testView.backgroundColor = [UIColor greenColor];

    if (tag == 0) { // 1 2 3
        [self.buleView hookColor];
        [self.buleView hookBorder];
        [self.buleView hookCornerRadius];
    } else if (tag == 1) { // 1 3 2
        [self.buleView hookColor];
        [self.buleView hookCornerRadius];
        [self.buleView hookBorder];
    } else if (tag == 2) { // 2 3 1
        [self.buleView hookBorder];
        [self.buleView hookCornerRadius];
        [self.buleView hookColor];
    } else if (tag == 3) { // 2 1 3
        [self.buleView hookBorder];
        [self.buleView hookColor];
        [self.buleView hookCornerRadius];
    } else if (tag == 4) {
        [self.buleView hookBorder];

        [self.buleView hookCornerRadius0];
        [self.buleView hookCornerRadius1];
        [self.buleView hookCornerRadius2];
        [self.buleView hookCornerRadius3];

        [self.buleView hookColor];
    }

    [self.view addSubview:self.buleView];
    self.buleView.frame = CGRectMake(100, 100 + changeY, 100, 100);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.buleView.originSetFrame) {
            self.buleView.originSetFrame(CGRectMake(100, 100 + changeY, 100, 100));
        }
    });

    NSLog(@"\n\n\n tag: %ld ===== self.buleView.class: %@, ty_realClass: %@", tag, self.buleView.class, [self.buleView ty_realClass]);
    NSLog(@"\n\n\n ===== self.buleView.frame: %@", NSStringFromCGRect(self.testView.frame));

    changeY += 10;
    tag = (tag + 1) % 6;
}

#pragma mark - 场景：测试不按照继承顺序替换方法

- (void)test2 {
    UICustomView *testView = [[UICustomView alloc] init];
    testView.backgroundColor = [UIColor greenColor];
    self.testView = testView;
    [self.view addSubview:self.testView];
    self.testView.frame = CGRectMake(100, 100, 100, 100);

    [self.testView classA];
    [self.testView classB];
    [self.testView classC];
    [self.testView classD];
    [self.testView classE];

    [self combination2];

    // !!!: 错误用法
    {
        UICustomView *testView = [[UICustomView alloc] init];
        testView.backgroundColor = [UIColor greenColor];
        [testView classA];
        [testView classB];
        [testView classC];
        [testView classD];
        [self.view addSubview:testView];
        testView.frame = CGRectMake(100, 100, 100, 100);
    }
}

- (void)combination1 {
    /**
     classELayoutSubviews
     classDLayoutSubviews
     classCLayoutSubviews
     classBLayoutSubviews
     classALayoutSubviews
     */
    [self.testView classALayoutSubviews];
    [self.testView classBLayoutSubviews];
    [self.testView classCLayoutSubviews];
    [self.testView classDLayoutSubviews];
    [self.testView classELayoutSubviews];
}

- (void)combination2 {
    /**
     classDLayoutSubviews
     classELayoutSubviews
     classCLayoutSubviews
     classBLayoutSubviews
     classALayoutSubviews
     */
    [self.testView classALayoutSubviews];
    [self.testView classBLayoutSubviews];
    [self.testView classCLayoutSubviews];
    [self.testView classELayoutSubviews];
    [self.testView classDLayoutSubviews];
}

- (void)combination3 {
    /**
     classELayoutSubviews
     classCLayoutSubviews
     classDLayoutSubviews
     classBLayoutSubviews
     classALayoutSubviews
     */
    [self.testView classALayoutSubviews];
    [self.testView classBLayoutSubviews];
    [self.testView classDLayoutSubviews];
    [self.testView classCLayoutSubviews];
    [self.testView classELayoutSubviews];
}

- (void)combination4 {
    /**
     classCLayoutSubviews
     classELayoutSubviews
     classDLayoutSubviews
     classBLayoutSubviews
     classALayoutSubviews
     */
    [self.testView classALayoutSubviews];
    [self.testView classBLayoutSubviews];
    [self.testView classDLayoutSubviews];
    [self.testView classELayoutSubviews];
    [self.testView classCLayoutSubviews];
}

- (void)combination5 {
    /**
     classDLayoutSubviews
     classCLayoutSubviews
     classELayoutSubviews
     classBLayoutSubviews
     classALayoutSubviews
     */
    [self.testView classALayoutSubviews];
    [self.testView classBLayoutSubviews];
    [self.testView classELayoutSubviews];
    [self.testView classCLayoutSubviews];
    [self.testView classDLayoutSubviews];
}

- (void)combination6 {
    /**
     classCLayoutSubviews
     classDLayoutSubviews
     classELayoutSubviews
     classBLayoutSubviews
     classALayoutSubviews
     */
    [self.testView classALayoutSubviews];
    [self.testView classBLayoutSubviews];
    [self.testView classELayoutSubviews];
    [self.testView classDLayoutSubviews];
    [self.testView classCLayoutSubviews];
}

#pragma mark -

- (UICustomView *)testView {
    if (_testView == nil) {
        _testView = [[UICustomView alloc] init];
    }
    return _testView;
}

@end
