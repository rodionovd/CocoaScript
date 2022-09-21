//
//  JSTListener.h
//  jstalk
//
//  Created by August Mueller on 1/14/09.
//  Copyright 2009 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface COSListener : NSObject {
    
    CFMessagePortRef messagePort;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSConnection *_conn;
#pragma clangd diagnostic pop

}

@property (weak) id rootObject;

+ (COSListener*)sharedListener;

+ (void)listen;
+ (void)listenWithRootObject:(id)rootObject;

@end
