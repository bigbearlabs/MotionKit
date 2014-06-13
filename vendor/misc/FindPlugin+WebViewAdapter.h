//
//  FindPlugin+WebViewAdapter.h
//  
//
//  Created by ilo-robbie on 11/06/2014.
//
//

@interface WebViewAdapter : NSObject

-(void) markText:(NSString*)find_input forWebView:(id)web_view;

-(void) findString:(NSString*)string forward:(NSNumber*)forward caseSensitive:(NSNumber*)caseSensitive wrap:(NSNumber*)wrap inWebView:(id)web_view;

@end
