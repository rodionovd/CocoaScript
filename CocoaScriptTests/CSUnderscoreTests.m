//  Created by Chris Davis on 07/06/2019.
//  

#import <XCTest/XCTest.h>
#import <Cocoa/Cocoa.h>
#import "COSelector.h"

@interface CocoaScriptUnderscore : NSObject {

}

- (void)selector1;
- (void)selector2_finalize;
- (void)selector3:(id)arg1 withArg2:(id)arg2;
- (void)selector4:(id)arg1 with_Param:(id)arg2;
- (BOOL)isEqualToFileURL_bc:(NSURL *)someURL;

@end

@implementation CocoaScriptUnderscore {
    
}

- (void)selector1 {}
- (void)selector2_finalize {}
- (void)selector3:(id)arg1 withArg2:(id)arg2 {}
- (void)selector4:(id)arg1 with_Param:(id)arg2 {}
- (BOOL)isEqualToFileURL_bc:(NSURL *)someURL { return false; }

@end

@interface CSUnderscoreTests : XCTestCase

@end

@implementation CSUnderscoreTests

- (SEL)work:(NSString *)input {
    CocoaScriptUnderscore *object = [[CocoaScriptUnderscore alloc] init];
    
    return [COSelector findMatchingSelector:input with:object];
}

- (void)testMethod_no_arguments_no_underscores {
    // Arrange
    NSString *inMethodName = @"selector1";
    
    // Act
    SEL selector = [self work: inMethodName];
    
    // Assert
    NSString *expected = NSStringFromSelector(@selector(selector1));
    NSString *actual = NSStringFromSelector(selector);
    XCTAssertTrue([expected isEqualToString:actual], @"%@", [NSString stringWithFormat:@"Selector should match got %@ not %@", actual, expected]);
}

- (void)testMethod_no_arguments_with_underscore {
    // Arrange
    NSString *inMethodName = @"selector2_finalize";
    
    // Act
    SEL selector = [self work: inMethodName];
    
    // Assert
    NSString *expected = NSStringFromSelector(@selector(selector2_finalize));
    NSString *actual = NSStringFromSelector(selector);
    XCTAssertTrue([expected isEqualToString:actual], @"%@", [NSString stringWithFormat:@"Selector should match got %@ not %@", actual, expected]);
}

- (void)testMethod_two_arguments_with_underscores {
    // Arrange
    NSString *inMethodName = @"selector3_withArg2_";
    
    // Act
    SEL selector = [self work: inMethodName];
    
    // Assert
    NSString *expected = NSStringFromSelector(@selector(selector3:withArg2:));
    NSString *actual = NSStringFromSelector(selector);
    XCTAssertTrue([expected isEqualToString:actual], @"%@", [NSString stringWithFormat:@"Selector should match got %@ not %@", actual, expected]);
}

- (void)testMethod_two_arguments_with_underscores_and_underscore_in_name {
    // Arrange
    NSString *inMethodName = @"selector4_with_Param_";
    
    // Act
    SEL selector = [self work: inMethodName];
    
    // Assert
    NSString *expected = NSStringFromSelector(@selector(selector4:with_Param:));
    NSString *actual = NSStringFromSelector(selector);
    XCTAssertTrue([expected isEqualToString:actual], @"%@", [NSString stringWithFormat:@"Selector should match got %@ not %@", actual, expected]);
}

- (void)testMethod_one_arguments_with_underscores {
    // Arrange
    NSString *inMethodName = @"isEqualToFileURL_bc";
    
    // Act
    SEL selector = [self work: inMethodName];
    
    // Assert
    NSString *expected = NSStringFromSelector(@selector(isEqualToFileURL_bc:));
    NSString *actual = NSStringFromSelector(selector);
    XCTAssertTrue([expected isEqualToString:actual], @"%@", [NSString stringWithFormat:@"Selector should match got %@ not %@", actual, expected]);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Arrange
        NSString *inMethodName = @"selector4_with_Param_";
        
        // Act
        SEL selector = [self work: inMethodName];
        
        // Assert
        NSString *expected = NSStringFromSelector(@selector(selector4:with_Param:));
        NSString *actual = NSStringFromSelector(selector);
        XCTAssertTrue([expected isEqualToString:actual], @"%@", [NSString stringWithFormat:@"Selector should match got %@ not %@", actual, expected]);
    }];
}

@end
