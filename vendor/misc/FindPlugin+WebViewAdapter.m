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

  // IT1 inducing find indicator
  // [web_view markAllMatchesForText:find_input caseSensitive:NO highlight:NO limit:0];
  // # NOTE this only returns rects within viewable area.

  // IT2
  id range = [web_view selectedDOMRange];
  if ( ! range) {
    NSLog(@"can't mark due to nil range");
    return;
  }

  NSInteger options = NSCaseInsensitiveSearch;
  [web_view countMatchesForText:find_input inDOMRange:range options:options highlight:NO limit:0 markMatches:YES];
  // CASE case sensitivity setting
  // CASE no selection
}

// finds and selects a string. 
// NOTE crucial to the find integration puzzle because find indicator rendering depends indirectly on the selecting.
-(void) findString:(NSString*)string forward:(NSNumber*)forward caseSensitive:(NSNumber*)caseSensitive wrap:(NSNumber*)wrap inWebView:(id)web_view {
  [web_view searchFor:string direction:[forward boolValue] caseSensitive:[caseSensitive boolValue] wrap:[wrap boolValue] startInSelection:YES];
}
// TODO contains / starts with / full word
// 

@end
