//  Created by Mathieu Dutour on 14/02/2019.
//  

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface COCacheBox : NSObject
@property (assign, readonly) JSValueRef jsValueRef;

- (instancetype)initWithJSValueRef:(JSValueRef)jsValue inContext:(JSGlobalContextRef)context;
- (void)cleanup;
@end

NS_ASSUME_NONNULL_END
