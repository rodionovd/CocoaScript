//
//  JSTalk.m
//  jstalk
//
//  Created by August Mueller on 1/15/09.
//  Copyright 2009 Flying Meat Inc. All rights reserved.
//

#import "COScript.h"
#import "COSListener.h"
#import "COSPreprocessor.h"
#import "COScript+Fiber.h"
#import "COScript+Interval.h"

#import <ScriptingBridge/ScriptingBridge.h>
#import "MochaRuntime.h"
#import "MOMethod.h"
#import "MOUndefined.h"
#import "MOBridgeSupportController.h"

#import <stdarg.h>

extern int *_NSGetArgc(void);
extern char ***_NSGetArgv(void);

static BOOL JSTalkShouldLoadJSTPlugins = YES;
static NSMutableArray *JSTalkPluginList;
static NSMutableDictionary* coreModuleScriptCache; // we are keeping the core modules' script in memory as they are required very often

static id<CODebugController> CODebugController = nil;

@interface Mocha (Private)
- (JSValueRef)setObject:(id)object withName:(NSString *)name;
- (BOOL)removeObjectWithName:(NSString *)name;
- (JSValueRef)callJSFunction:(JSObjectRef)jsFunction withArgumentsInArray:(NSArray *)arguments;
- (id)objectForJSValue:(JSValueRef)value;
@end

@interface COScript (Private)

@end

void COScriptDebug(NSString* format, ...) {
    va_list args;
    va_start(args, format);
    if (CODebugController == nil) {
        NSLogv(format, args);
    } else {
        [CODebugController output:format args:args];
    }

    va_end(args);
}

@implementation COScript

+ (id)setDebugController:(id)debugController {
    id oldController = CODebugController;
    CODebugController = debugController;
    return oldController;
}

+ (void)listen {
    [COSListener listen];
}

+ (void)setShouldLoadExtras:(BOOL)b {
    JSTalkShouldLoadJSTPlugins = b;
}

+ (void)setShouldLoadJSTPlugins:(BOOL)b {
    JSTalkShouldLoadJSTPlugins = b;
}


- (id)init {
    return [self initWithCoreModules:@{} andName:nil];
}

- (instancetype)initWithCoreModules:(NSDictionary*)coreModules andName:(NSString*)name {
    self = [super init];
    if ((self != nil)) {
        _mochaRuntime = [[Mocha alloc] initWithName:name ? name : @"Untitled"];
        
        self.coreModuleMap = coreModules;
        if (!coreModuleScriptCache) {
            coreModuleScriptCache = [NSMutableDictionary dictionary];
        }
        self.moduleCache = [NSMutableDictionary dictionary];
        
        [self setEnv:[NSMutableDictionary dictionary]];
        [self setShouldPreprocess:YES];
        
        [self addExtrasToRuntime];
    }
    
    return self;
}

- (void)dealloc {
    debug(@"%s:%d", __FUNCTION__, __LINE__);
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)cleanup {
    // clean up fibers to shut everything down nicely
    [self cleanupFibers];
    
    // clean up the global object that we injected in the runtime
    [self deleteObjectWithName:@"jstalk"];
    [self deleteObjectWithName:@"coscript"];
    [self deleteObjectWithName:@"print"];
    [self deleteObjectWithName:@"log"];
    [self deleteObjectWithName:@"require"];
    if ([self.coreModuleMap objectForKey:@"console"]) {
        [self deleteObjectWithName:@"console"];
    }
    
    // clean up mocha
    [_mochaRuntime shutdown];
    _mochaRuntime = nil;
}

- (void)garbageCollect {
    
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    [_mochaRuntime garbageCollect];
    
    debug(@"gc took %f seconds", [NSDate timeIntervalSinceReferenceDate] - start); (void)start;
}

- (BOOL)shouldKeepRunning {
    if (_shouldKeepAround) {
        return YES;
    }
    if (_activeFibers != nil) {
        return [_activeFibers count] > 0;
    }
    return NO;
}


- (JSGlobalContextRef)context {
    return [_mochaRuntime context];
}

- (void)addExtrasToRuntime {
    
    [self pushObject:self withName:@"jstalk"];
    [self pushObject:self withName:@"coscript"];
    
    [_mochaRuntime evalString:@"var nil=null;\n"];
    [_mochaRuntime setValue:[MOMethod methodWithTarget:self selector:@selector(print:)] forKey:@"print"];
    [_mochaRuntime setValue:[MOMethod methodWithTarget:self selector:@selector(print:)] forKey:@"log"];
    [_mochaRuntime setValue:[MOMethod methodWithTarget:self selector:@selector(require:)] forKey:@"require"];
    
    [_mochaRuntime loadFrameworkWithName:@"AppKit"];
    [_mochaRuntime loadFrameworkWithName:@"Foundation"];

    // if there is a console module, use it to polyfill the console global
    if ([self.coreModuleMap objectForKey:@"console"]) {
        [self pushObject:[self executeString:@"(function() { var Console = require('console'); var console = Console(); var dict = NSMutableDictionary.dictionaryWithCapacity(Object.keys(console).length); Object.keys(console).forEach(function(k) {dict[k] = console[k]}); return dict; })()"] withName:@"console"];
    }
}

+ (void)loadExtraAtPath:(NSString*)fullPath {
    
    Class pluginClass;
    
    @try {
        
        NSBundle *pluginBundle = [NSBundle bundleWithPath:fullPath];
        if (!pluginBundle) {
            return;
        }
        
        NSString *principalClassName = [[pluginBundle infoDictionary] objectForKey:@"NSPrincipalClass"];
        
        if (principalClassName && NSClassFromString(principalClassName)) {
            NSLog(@"The class %@ is already loaded, skipping the load of %@", principalClassName, fullPath);
            return;
        }
        
        [principalClassName class]; // force loading of it.
        
        NSError *err = nil;
        [pluginBundle loadAndReturnError:&err];
        
        if (err) {
            NSLog(@"Error loading plugin at %@", fullPath);
            NSLog(@"%@", err);
        }
        else if ((pluginClass = [pluginBundle principalClass])) {
            
            // do we want to actually do anything with em' at this point?
            
            NSString *bridgeSupportName = [[pluginBundle infoDictionary] objectForKey:@"BridgeSuportFileName"];
            
            if (bridgeSupportName) {
                NSString *bridgeSupportPath = [pluginBundle pathForResource:bridgeSupportName ofType:nil];
                
                NSError *outErr = nil;
                if (![[MOBridgeSupportController sharedController] loadBridgeSupportAtURL:[NSURL fileURLWithPath:bridgeSupportPath] error:&outErr]) {
                    NSLog(@"Could not load bridge support file at %@", bridgeSupportPath);
                }
            }
        }
        else {
            //debug(@"Could not load the principal class of %@", fullPath);
            //debug(@"infoDictionary: %@", [pluginBundle infoDictionary]);
        }
        
    }
    @catch (NSException * e) {
        NSLog(@"EXCEPTION: %@: %@", [e name], e);
    }
    
}

+ (void)resetPlugins {
    JSTalkPluginList = nil;
}

+ (void)loadPlugins {
    
    // install plugins that were passed via the command line
    int i = 0;
    char **argv = *_NSGetArgv();
    for (i = 0; argv[i] != NULL; ++i) {
        
        NSString *a = [NSString stringWithUTF8String:argv[i]];
        
        if ([@"-jstplugin" isEqualToString:a] || [@"-cosplugin" isEqualToString:a]) {
            i++;
            NSLog(@"Loading plugin at: [%@]", [NSString stringWithUTF8String:argv[i]]);
            [self loadExtraAtPath:[NSString stringWithUTF8String:argv[i]]];
        }
    }
    
    JSTalkPluginList = [NSMutableArray array];
    
    NSString *appSupport = @"Library/Application Support/JSTalk/Plug-ins";
    NSString *appPath    = [[NSBundle mainBundle] builtInPlugInsPath];
    NSString *sysPath    = [@"/" stringByAppendingPathComponent:appSupport];
    NSString *userPath   = [NSHomeDirectory() stringByAppendingPathComponent:appSupport];
    
    
    // only make the JSTalk dir if we're JSTalkEditor.
    // or don't ever make it, since you'll get rejected from the App Store. *sigh*
    /*
    if (![[NSFileManager defaultManager] fileExistsAtPath:userPath]) {
        
        NSString *mainBundleId = [[NSBundle mainBundle] bundleIdentifier];
        
        if ([@"org.jstalk.JSTalkEditor" isEqualToString:mainBundleId]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:userPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    */
    
    for (NSString *folder in [NSArray arrayWithObjects:appPath, sysPath, userPath, nil]) {
        
        for (NSString *bundle in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:nil]) {
            
            if (!([bundle hasSuffix:@".jstplugin"] || [bundle hasSuffix:@".cosplugin"])) {
                continue;
            }
            
            [self loadExtraAtPath:[folder stringByAppendingPathComponent:bundle]];
        }
    }
    
    if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"org.jstalk.JSTalkEditor"]) {
        
        NSURL *jst = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"org.jstalk.JSTalkEditor"];
        
        if (jst) {
            
            NSURL *folder = [[jst URLByAppendingPathComponent:@"Contents"] URLByAppendingPathComponent:@"PlugIns"];
            
            for (NSString *bundle in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[folder path] error:nil]) {
                
                if (!([bundle hasSuffix:@".jstplugin"])) {
                    continue;
                }
                
                [self loadExtraAtPath:[[folder path] stringByAppendingPathComponent:bundle]];
            }
        }
    }
}

+ (void)loadBridgeSupportFileAtURL:(NSURL*)url {
    NSError *outErr = nil;
    if (![[MOBridgeSupportController sharedController] loadBridgeSupportAtURL:url error:&outErr]) {
        NSLog(@"Could not load bridge support file at %@", url);
    }
}

NSString *currentCOScriptThreadIdentifier = @"org.jstalk.currentCOScriptHack";

// FIXME: Change currentCOScript and friends to use a stack in the thread dictionary, instead of just overwriting what might already be there."

+ (NSMutableArray*)currentCOSThreadStack {
    
    NSMutableArray *ar = [[[NSThread currentThread] threadDictionary] objectForKey:currentCOScriptThreadIdentifier];
    
    if (!ar) {
        ar = [NSMutableArray array];
        [[[NSThread currentThread] threadDictionary] setObject:ar forKey:currentCOScriptThreadIdentifier];
    }
    
    return ar;
}

+ (COScript*)currentCOScript {
    
    return [[self currentCOSThreadStack] lastObject];
}

- (void)pushAsCurrentCOScript {
    [[[self class] currentCOSThreadStack] addObject:self];
}

- (void)popAsCurrentCOScript {
    
    if ([[[self class] currentCOSThreadStack] count]) {
        [[[self class] currentCOSThreadStack] removeLastObject];
    }
    else {
        NSLog(@"popAsCurrentCOScript - currentCOSThreadStack is empty");
    }
}

- (void)pushObject:(id)obj withName:(NSString*)name  {
    [_mochaRuntime setObject:obj withName:name];
}

- (void)deleteObjectWithName:(NSString*)name {
    [_mochaRuntime removeObjectWithName:name];
}

- (id)require:(NSString *)module {
    if (self.moduleCache[module]) {
        return self.moduleCache[module];
    }
    
    // store the current script URL so that we can put it back after requiring the module
    NSURL* currentURL = [_env objectForKey:@"scriptURL"];
    
    // we never want to preprocess the modules - it shouldn't use Cocoascript syntax.
    BOOL savedPreprocess = self.shouldPreprocess;
    self.shouldPreprocess = NO;
    
    id result = nil;
    
    if ([module characterAtIndex:0] == '.') { // relative path
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString* modulePath = module;
        
        // path/to/module/index.js
        NSURL* moduleDirectoryURL = [NSURL URLWithString:[module stringByAppendingPathComponent:@"index.js"] relativeToURL:currentURL];
        
        if ([module.pathExtension isEqualToString:@""]) {
            modulePath = [modulePath stringByAppendingPathExtension:@"js"];
        }
        
        // path/to/module.js
        NSURL* moduleURL = [NSURL URLWithString:modulePath relativeToURL:currentURL];
        
        if ([fileManager fileExistsAtPath:moduleURL.path]) {
            result = [self executeModuleAtURL:moduleURL];
        } else if ([fileManager fileExistsAtPath:moduleDirectoryURL.path]) {
            result = [self executeModuleAtURL:moduleDirectoryURL];
        } else {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Cannot find module %@ from package %@", module, currentURL.path] userInfo:nil];
        }
    } else {
        if (self.coreModuleMap[module]) {
            // we set `isRequiringCore` in the environment so that if a core module is requiring other file,
            // we know that it's still a core module and should be cached as such
            [_env setObject:@"true" forKey:@"isRequiringCore"];
            
            result = [self executeModuleAtURL:self.coreModuleMap[module]];
            
            [_env setObject:@"false" forKey:@"isRequiringCore"];
        } else {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%@ is not a core package", module] userInfo:nil];
        }
    }
    
    // go back to previous settings
    self.shouldPreprocess = savedPreprocess;
    if (currentURL) {
        [_env setObject:currentURL forKey:@"scriptURL"];
    }
    
    // cache the module so it keeps it state if required again
    [self.moduleCache setObject:result forKey:module];
    
    return result;
}

- (id)executeModuleAtURL:(NSURL*)scriptURL {
    id result = nil;
    if (scriptURL) {
        NSError* error;
        NSString* script;
        if (coreModuleScriptCache[scriptURL]) {
            script = coreModuleScriptCache[scriptURL];
        } else {
            script = [NSString stringWithContentsOfURL:scriptURL encoding:NSUTF8StringEncoding error:&error];
            if ([[_env objectForKey:@"isRequiringCore"] isEqualToString:@"true"]) {
                // cache the core module's so that we don't need to read it from disk again
                [coreModuleScriptCache setObject:script forKey:scriptURL];
            }
        }
        if (script) {
            NSString* module = [NSString stringWithFormat:@"(function() { var module = { exports : {} }; var exports = module.exports; %@ ; return module.exports; })()", script];
            result = [self executeString:module baseURL:scriptURL];
        } else if (error) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Cannot find module %@", scriptURL.path] userInfo:nil];
        }
    }
    return result;
}


- (id)executeString:(NSString*)str {
    return [self executeString:str baseURL:nil];
}

- (id)executeString:(NSString*)str baseURL:(NSURL*)base {
    
    if (!JSTalkPluginList && JSTalkShouldLoadJSTPlugins) {
        [COScript loadPlugins];
    }
    
    if (base) {
        [_env setObject:base forKey:@"scriptURL"];
    }
    
    if (!base && [[_env objectForKey:@"scriptURL"] isKindOfClass:[NSURL class]]) {
        base = [_env objectForKey:@"scriptURL"];
    }
    
    if ([self shouldPreprocess]) {
        
        str = [COSPreprocessor preprocessCode:str withBaseURL:base];
    }
    self.processedSource = str;

    [self pushAsCurrentCOScript];
    
    id resultObj = nil;
    
    @try {

        resultObj = [_mochaRuntime evalString:str atURL:base];

        if (resultObj == [MOUndefined undefined]) {
            resultObj = nil;
        }
    }
    @catch (NSException *e) {
        
        NSDictionary *d = [e userInfo];
        if ([d objectForKey:@"line"]) {
            if ([_errorController respondsToSelector:@selector(coscript:hadError:onLineNumber:atSourceURL:)]) {
                [_errorController coscript:self hadError:[e reason] onLineNumber:[[d objectForKey:@"line"] integerValue] atSourceURL:base];
            }
        }
        
        NSLog(@"Exception: %@", [e userInfo]);
        [self printException:e];
    }
    @finally {
        //
    }
    
    [self popAsCurrentCOScript];
    
    return resultObj;
}

- (BOOL)hasFunctionNamed:(NSString*)name {
    
    JSValueRef exception = nil;
    JSStringRef jsFunctionName = JSStringCreateWithUTF8CString([name UTF8String]);
    JSValueRef jsFunctionValue = JSObjectGetProperty([_mochaRuntime context], JSContextGetGlobalObject([_mochaRuntime context]), jsFunctionName, &exception);
    JSStringRelease(jsFunctionName);
    
    
    return jsFunctionValue && (JSValueGetType([_mochaRuntime context], jsFunctionValue) == kJSTypeObject);
}

- (id)callFunctionNamed:(NSString*)name withArguments:(NSArray*)args {
    
    id returnValue = nil;
    
    @try {
        
        [self pushAsCurrentCOScript];
        
        returnValue = [_mochaRuntime callFunctionWithName:name withArgumentsInArray:args];
        
        if (returnValue == [MOUndefined undefined]) {
            returnValue = nil;
        }
    }
    @catch (NSException * e) {
        NSLog(@"Exception: %@", e);
        [self printException:e];
    }
    
    [self popAsCurrentCOScript];
    
    return returnValue;
}


- (id)callJSFunction:(JSObjectRef)jsFunction withArgumentsInArray:(NSArray *)arguments {
    [self pushAsCurrentCOScript];
    
    //[self garbageCollect];
    
    JSValueRef r = nil;
    @try {
        r = [_mochaRuntime callJSFunction:jsFunction withArgumentsInArray:arguments];
    }
    @catch (NSException * e) {
        NSLog(@"Exception: %@", e);
        NSLog(@"Info: %@", [e userInfo]);
        [self printException:e];
    }
    
    [self popAsCurrentCOScript];
    
    if (r) {
        return [_mochaRuntime objectForJSValue:r];
    }
    
    return nil;
}

- (void)unprotect:(id)o {
    
    
    
    JSValueRef value = [_mochaRuntime JSValueForObject:o];
    
    assert(value);
    
    if (value) {
        
        JSObjectRef jsObject = JSValueToObject([_mochaRuntime context], value, NULL);
        id private = (__bridge id)JSObjectGetPrivate(jsObject);
        
        assert([private representedObject] == o);
        
        debug(@"COS unprotecting %@", o);
        JSValueUnprotect([_mochaRuntime context], value);
    }
}

- (void)protect:(id)o {
    
    
    JSValueRef value = [_mochaRuntime JSValueForObject:o];
    
    
    assert(value);
    
    if (value) {
        
        JSObjectRef jsObject = JSValueToObject([_mochaRuntime context], value, NULL);
        
        
        debug(@"COS protecting %@ / v: %p o: %p", o, value, jsObject);
        
        id private = (__bridge id)JSObjectGetPrivate(jsObject);
        
        assert([private representedObject] == o);
        
        JSValueProtect([_mochaRuntime context], value);
    }
}

// JavaScriptCore isn't safe for recursion.  So calling this function from
// within a script is a really bad idea.  Of couse, that's what it was written
// for, so it really needs to be taken out.

- (void)include:(NSString*)fileName {
    
    if (![fileName hasPrefix:@"/"] && [_env objectForKey:@"scriptURL"]) {
        NSString *parentDir = [[[_env objectForKey:@"scriptURL"] path] stringByDeletingLastPathComponent];
        fileName = [parentDir stringByAppendingPathComponent:fileName];
    }
    
    NSURL *scriptURL = [NSURL fileURLWithPath:fileName];
    NSError *err = nil;
    NSString *str = [NSString stringWithContentsOfURL:scriptURL encoding:NSUTF8StringEncoding error:&err];
    
    if (!str) {
        NSLog(@"Could not open file '%@'", scriptURL);
        NSLog(@"Error: %@", err);
        return;
    }
    
    if (_shouldPreprocess) {
        str = [COSPreprocessor preprocessCode:str];
    }
    self.processedSource = str;
    
    [_mochaRuntime evalString:str];
}

- (void)printException:(NSException*)e {
    
    NSMutableString *s = [NSMutableString string];
    
    [s appendFormat:@"%@\n", e];
    
    NSDictionary *d = [e userInfo];
    
    for (id o in [d allKeys]) {
        [s appendFormat:@"%@: %@\n", o, [d objectForKey:o]];
    }
    
    [self print:s];
}

- (void)print:(NSString*)s {
    
    if (_printController && [_printController respondsToSelector:@selector(print:)]) {
        [_printController print:s];
    }
    else {
        if (![s isKindOfClass:[NSString class]]) {
            s = [s description];
        }
        
        printf("%s\n", [s UTF8String]);
    }
}


+ (id)applicationOnPort:(NSString*)port {
    
    NSConnection *conn  = nil;
    NSUInteger tries    = 0;
    
    while (!conn && tries < 10) {
        
        conn = [NSConnection connectionWithRegisteredName:port host:nil];
        tries++;
        if (!conn) {
            debug(@"Sleeping, waiting for %@ to open", port);
            sleep(1);
        }
    }
    
    if (!conn) {
        NSBeep();
        NSLog(@"Could not find a JSTalk connection to %@", port);
    }
    
    return [conn rootProxy];
}

+ (id)application:(NSString*)app {
    
    NSString *appPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:app];
    
    if (!appPath) {
        NSLog(@"Could not find application '%@'", app);
        // fixme: why are we returning a bool?
        return [NSNumber numberWithBool:NO];
    }
    
    NSBundle *appBundle = [NSBundle bundleWithPath:appPath];
    NSString *bundleId  = [appBundle bundleIdentifier];
    
    // make sure it's running
	NSArray *runningApps = [[NSWorkspace sharedWorkspace] runningApplications];
    
    BOOL found = NO;
    
    for (NSRunningApplication *rapp in runningApps) {
        
        if ([[rapp bundleIdentifier] isEqualToString:bundleId]) {
            found = YES;
            break;
        }
        
    }
    
	if (!found) {
        BOOL launched = [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:bundleId
                                                                             options:NSWorkspaceLaunchWithoutActivation | NSWorkspaceLaunchAsync
                                                      additionalEventParamDescriptor:nil
                                                                    launchIdentifier:nil];
        if (!launched) {
            NSLog(@"Could not open up %@", appPath);
            return nil;
        }
    }
    
    
    return [self applicationOnPort:[NSString stringWithFormat:@"%@.JSTalk", bundleId]];
}

+ (id)app:(NSString*)app {
    return [self application:app];
}

+ (id)proxyForApp:(NSString*)app {
    return [self application:app];
}


@end



@implementation JSTalk

@end
