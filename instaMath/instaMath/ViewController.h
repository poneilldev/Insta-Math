//
//  ViewController.h
//  customeCameraAV
//
//  Created by Paul O'Neill on 10/28/15.
//  Copyright © 2015 Paul O'Neill. All rights reserved.
//

#import <UIKit/UIKit.h>





@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIView *frameForCapture;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *answer;

- (IBAction)takePhoto:(id)sender;

@end

