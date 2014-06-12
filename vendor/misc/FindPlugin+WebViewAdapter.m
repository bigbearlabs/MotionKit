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
  [web_view countMatchesForText:find_input inDOMRange:range options:0 highlight:NO limit:0 markMatches:YES];
}

-(void) findString:(NSString*)string inWebView:(id)web_view {
  [web_view searchFor:string direction:YES caseSensitive:NO wrap:YES startInSelection:YES];
}
@end
