//
//  COSelector.m
//  Cocoa Script Editor
//
//  Created by Chris Davis on 07/06/2019.
//

#import "COSelector.h"

@implementation COSelector

/**
 Finds if the property is a selector on the object, regardless of underscores
 */
+ (SEL)findMatchingSelector:(NSString *)propertyName with:(NSObject *)object {
    __block NSString *modifiedInput = [propertyName stringByReplacingOccurrencesOfString:@"_" withString:@":"];
    NSArray *arr = [COSelector findIndexes:@":" in:modifiedInput];
    
    // Early out
    if ([arr count] == 0) {
        SEL selector = NSSelectorFromString(modifiedInput);
        if ([object respondsToSelector:selector]) {
            return selector;
        }
        return nil;
    }
    
    NSString *binaryRepresentation = [@"" stringByPaddingToLength:[arr count] withString: @"1" startingAtIndex:0];
    unsigned long v = strtoul([binaryRepresentation UTF8String], nil, 2);
    
    for (int i = 0; i < v + 1; i++) {
        
        NSString *combination = [COSelector integerToBinary:i pad:[arr count]];
        
        [COSelector enumerateCharacters:combination with:^(NSString *character, NSInteger idx, bool *stop) {
            NSString *flip = [character isEqualToString:@"1"] ? @"_" : @":";
            NSRange range = NSMakeRange([arr[idx] intValue], 1);
            modifiedInput = [modifiedInput stringByReplacingCharactersInRange:range withString:flip];
        }];
        
        //NSLog(@"%d %@ %@", i, combination, modifiedInput);
        
        SEL selector = NSSelectorFromString([modifiedInput stringByAppendingString:@":"]);
        if ([object respondsToSelector:selector]) {
            return selector;
        }
        
        selector = NSSelectorFromString(modifiedInput);
        if ([object respondsToSelector:selector]) {
            return selector;
        }
    }
    
    return nil;
}

+ (NSArray *)findIndexes:(NSString *)of in:(NSString *)string {
    NSMutableArray *results = [[NSMutableArray alloc] init];
    NSRange searchRange = NSMakeRange(0, string.length);
    NSRange foundRange;
    while (searchRange.location < string.length) {
        searchRange.length = string.length-searchRange.location;
        foundRange = [string rangeOfString:of options:NSCaseInsensitiveSearch range:searchRange];
        if (foundRange.location != NSNotFound) {
            searchRange.location = foundRange.location+foundRange.length;
            [results addObject:@(searchRange.location - 1)];
        } else {
            break;
        }
    }
    return results;
}

+ (void)enumerateCharacters:(NSString *)string with:(void (^)(NSString *character, NSInteger idx, bool *stop))block {
    bool _stop = NO;
    for(NSInteger i = 0; i < [string length] && !_stop; i++) {
        NSString *character = [string substringWithRange:NSMakeRange(i, 1)];
        block(character, i, &_stop);
    }
}

+ (NSString *)integerToBinary:(NSUInteger)integer pad:(NSUInteger)padding {
    NSMutableString *str = [NSMutableString stringWithFormat:@""];
    for(NSInteger numberCopy = integer; numberCopy > 0; numberCopy >>= 1) {
        [str insertString:((numberCopy & 1) ? @"1" : @"0") atIndex:0];
    }
    return [NSString stringWithFormat:@"%0*d", (int)padding, [str intValue]];
}

@end
