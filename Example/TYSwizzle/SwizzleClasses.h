//
//  SwizzleClasses.h
//  Swizzle
//
//  Created by 徐徐徐 on 2023/12/4.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UICustomView : UIView

@end

@interface UIBuleView : UIView

@property (nonatomic, strong) UIView *blueView;

@property (nonatomic, copy) void (^originSetFrame)(CGRect frame);

@end

@interface UIView (Test)

- (void)hookColor;

- (void)hookBorder;

- (void)hookCornerRadius;
- (void)hookCornerRadius0;
- (void)hookCornerRadius1;
- (void)hookCornerRadius2;
- (void)hookCornerRadius3;

- (void)classA;
- (void)classALayoutSubviews;
- (void)classB;
- (void)classBLayoutSubviews;
- (void)classC;
- (void)classCLayoutSubviews;
- (void)classD;
- (void)classDLayoutSubviews;
- (void)classE;
- (void)classELayoutSubviews;

@end

NS_ASSUME_NONNULL_END
