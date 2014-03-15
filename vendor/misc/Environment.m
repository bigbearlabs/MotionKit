//
//  Environment.m
//  WebBuddy
//
//  Created by Park Andy on 05/06/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "Environment.h"

@implementation Environment

@synthesize values;

- (id)init
{
	self = [super init];
	if (self) {
		id dict = [NSMutableDictionary dictionary];
		
		// build configuration
		#ifdef DEBUG  // defined in the build settings for the build configuration
			[dict setObject:@"DEBUG" forKey:@"build_configuration"];
		#else
			[dict setObject:@"RELEASE" forKey:@"build_configuration"];
		#endif

		values = dict;
		
	}
	return self;
}

// for compatibility with other languages without scripting bridge metadata,
// return an NSNumber.
-(NSNumber*) isDebugBuild {
	// return [NSNumber numberWithBool:[[self.values objectForKey:@"build_configuration"] isEqual:@"DEBUG"]];
	return [NSNumber numberWithBool:NO];
}

-(void) breakpoint:(id)object {
	// we can put a breakpoint here and call in from modules written in other languages.
	if ( [[self isDebugBuild] boolValue] ) {
		NSLog(@"at breakpoint: %@", object);
		;
	}
}


+(id) instance {
	static Environment* instance;
	if (instance == nil)
		instance = [[Environment alloc] init];
	return instance;
}

@end
