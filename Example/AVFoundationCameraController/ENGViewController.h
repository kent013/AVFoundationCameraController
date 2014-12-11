//
//  ENGViewController.h
//  AVFoundationCameraController
//
//  Created by kent013 on 12/11/2014.
//  Copyright (c) 2014 kent013. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ENGAVFoundationCameraController.h"

@interface ENGViewController : UIViewController<ENGAVFoundationCameraControllerDelegate>
@property (weak, nonatomic) IBOutlet ENGAVFoundationCameraController *cameraView;
@end
