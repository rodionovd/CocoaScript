//
//  COSelector.h
//  Cocoa Script Editor
//
//  Created by Chris Davis on 07/06/2019.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface COSelector : NSObject

+ (SEL)findMatchingSelector:(NSString *)propertyName with:(NSObject *)object;

@end

NS_ASSUME_NONNULL_END
