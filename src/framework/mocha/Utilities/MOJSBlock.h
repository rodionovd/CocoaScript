// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 19/03/2018.
//  All code (c) 2018 - present day, Elegant Chaos Limited.
//  For licensing terms, see http://elegantchaos.com/license/liberal/.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

#import <JavaScriptCore/JavaScriptCore.h>
#import "MOJavaScriptObject.h"
#import "MochaRuntime_Private.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MOJSBlockExports<JSExport>
+ (instancetype)blockWithSignature:(NSString*)signature function:(MOJavaScriptObject*)function runtime:(Mocha*) runtime;
@end

@interface MOJSBlock : NSObject<MOJSBlockExports, NSCopying>
@property (strong, nonatomic, readonly) MOJavaScriptObject* function;
@property (strong, nonatomic, readonly) NSMethodSignature* signature;
@property (weak, nonatomic, readonly) Mocha* runtime;

- (instancetype)initWithSignature:(const char*)signature function:(MOJavaScriptObject *)function runtime:(Mocha*) runtime;
@end

NS_ASSUME_NONNULL_END
