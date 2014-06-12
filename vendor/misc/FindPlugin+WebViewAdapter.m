//
//  FindPlugin+WebViewAdapter.m
//  
//
//  Created by ilo-robbie on 11/06/2014.
//
//

#import "FindPlugin+WebViewAdapter.h"

@implementation WebViewAdapter

// wrap some messages sent to WebView to facilitate text matching.
-(void) markText:(NSString*)find_input forWebView:(id)web_view {
  [web_view unmarkAllTextMatches];
  [web_view markAllMatchesForText:find_input caseSensitive:NO highlight:NO limit:0];
}

@end
