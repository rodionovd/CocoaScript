//  Created by Mathieu Dutour on 13/07/2018.
//  

#import "MOJSTypeChecker.h"

bool MOJSValueIsError(JSContextRef ctx, JSValueRef value) {
    if (JSValueIsObject(ctx, value))
    {
        JSStringRef errorString = JSStringCreateWithUTF8CString("Error");
        JSObjectRef errorConstructor = JSValueToObject(ctx, JSObjectGetProperty(ctx, JSContextGetGlobalObject(ctx), errorString, NULL), NULL);
        JSStringRelease(errorString);
        
        return JSValueIsInstanceOfConstructor(ctx, value, errorConstructor, NULL);
    }
    return false;
}

bool MOJSValueIsArray(JSContextRef ctx, JSValueRef value) {
    if (JSValueIsObject(ctx, value))
    {
        JSStringRef name = JSStringCreateWithUTF8CString("Array");
        
        JSObjectRef array = (JSObjectRef)JSObjectGetProperty(ctx, JSContextGetGlobalObject(ctx), name, NULL);
        
        JSStringRelease(name);
        
        name = JSStringCreateWithUTF8CString("isArray");
        JSObjectRef isArray = (JSObjectRef)JSObjectGetProperty(ctx, array, name, NULL);
        
        JSStringRelease(name);
        
        JSValueRef retval = JSObjectCallAsFunction(ctx, isArray, NULL, 1, &value, NULL);
        
        if (JSValueIsBoolean(ctx, retval))
        return JSValueToBoolean(ctx, retval);
    }
    return false;
}
