//
//  ENGViewController.m
//  AVFoundationCameraController
//
//  Created by kent013 on 12/11/2014.
//  Copyright (c) 2014 kent013. All rights reserved.
//

#import "ENGViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface ENGViewController ()

@end

@implementation ENGViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.cameraView.delegate = self;
    self.cameraView.showsCameraControls = NO;
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)cameraController:(ENGAVFoundationCameraController *)cameraController didScaledTo:(CGFloat)scale viewRect:(CGRect)rect{
    NSLog(@"%f, %@", scale, NSStringFromCGRect(rect));
}

- (void)cameraController:(ENGAVFoundationCameraController *)cameraController didFinishPickingImage:(UIImage *)image metadata:(NSDictionary *)metadata{
    ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
    [lib writeImageToSavedPhotosAlbum:image.CGImage
                             metadata:metadata
                      completionBlock:nil];
}
- (IBAction)onCameraButtonTapped:(id)sender {
    [self.cameraView takePicture];
}
@end
