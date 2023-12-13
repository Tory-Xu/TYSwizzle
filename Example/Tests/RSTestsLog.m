#import "RSTestsLog.h"

@import XCTest;

@implementation RSTestsLog

static NSMutableString *_logString = nil;

+ (void)log:(NSString *)string {
    if (!_logString) {
        _logString = [NSMutableString new];
    }
    [_logString appendString:string];
    NSLog(@"%@", string);
}

+ (void)clear {
    _logString = nil;
}

+ (BOOL)is:(NSString *)compareString {
    if (compareString == nil && _logString == nil) {
        return YES;
    }
    return [compareString isEqualToString:_logString];
}

+ (NSString *)logString {
    return _logString;
}

@end

@interface RSTestsLogTests : XCTestCase
@end

@implementation RSTestsLogTests

- (void)testLog {
    [RSTestsLog clear];
    RSTestsLog(@"A");
    RSTestsLog(@"B");
    RSTestsLog(@"C");
    XCTAssertTrue([[RSTestsLog logString] isEqualToString:@"ABC"], @"%@", [RSTestsLog logString]);
    CLEAR_LOG();
}

- (void)testAssertLogIs {
    [RSTestsLog clear];
    RSTestsLog(@"A");
    RSTestsLog(@"C");
    ASSERT_LOG_IS(@"AC");
    CLEAR_LOG();
}

@end
