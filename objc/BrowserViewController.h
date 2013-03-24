//
//  BrowserViewController.h
//
//  Created by ilo-robbie on 29/06/2012.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface BrowserViewController : MotionViewController {
    IBOutlet id web_view;
}
- (IBAction)handle_input_changed:(id)sender;
@end
