//
//  MainViewController.h
//  AVFoundationCameraController
//
//  Created by Kentaro ISHITOYA on 12/01/02.
//  Copyright (c) 2012 Kentaro ISHITOYA. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AVFoundationCameraController.h"

@interface MainViewController : UIViewController<AVFoundationCameraControllerDelegate>{
    AVFoundationCameraController *imagePicker_;
}
- (id)initWithFrame:(CGRect)frame;
@end
