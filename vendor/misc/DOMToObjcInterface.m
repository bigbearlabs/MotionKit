//
//  DOMToObjcInterface.m
//  WebBuddy
//
//  Created by ilo-robbie on 16/01/2013.
//
//

#import "DOMToObjcInterface.h"

// an indirection to assure that method invocation succeeds from js through DOM window object to a macruby object, set as the callback handler to an instance of this class and implementing the method 'performWebkitInvokableOperation'. work around what seems to be lagging class definitions understood by webkit in commit 9847bc4.
@implementation DOMToObjcInterface

- (id)initWithCallbackHandler:(id) handler
{
	self = [super init];
	if (self) {
		self.handler = handler;
	}
	return self;
}

// FIXME exceptions thrown are not reported properly.
-(id) callback:(NSString*) callbackName {
	NSLog(@"invoking %@ on %@", callbackName, self.handler);
	id result = [self.handler performSelector:NSSelectorFromString(callbackName)];
	
	return result;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector {
	NSLog(@"webkit querying for selector %@", NSStringFromSelector(aSelector));

	// wide-open access.
	return false;
}

@end
