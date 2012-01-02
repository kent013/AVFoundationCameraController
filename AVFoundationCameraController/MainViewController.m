//
//  MainViewController.m
//  AVFoundationCameraController
//
//  Created by Kentaro ISHITOYA on 12/01/02.
//  Copyright (c) 2012 Kentaro ISHITOYA. All rights reserved.
//

#import <CoreMedia/CoreMedia.h>
#import <ImageIO/ImageIO.h>
#import "MainViewController.h"
//-----------------------------------------------------------------------------
//Private Implementations
//-----------------------------------------------------------------------------
@interface MainViewController(PrivateImplementation)
- (void) setupInitialState:(CGRect)frame;
@end

@implementation MainViewController(PrivateImplementation)
-(void)setupInitialState:(CGRect)frame{
    self.view.frame = frame;
    NSLog(@"%@", NSStringFromCGRect(frame));
    imagePicker_ = [[AVFoundationCameraController alloc] initWithFrame:frame];
    imagePicker_.delegate = self;
    [self.view addSubview:imagePicker_.view];
}
@end

//-----------------------------------------------------------------------------
//Public Implementations
//-----------------------------------------------------------------------------
@implementation MainViewController
- (id)initWithFrame:(CGRect)frame{
    self = [super init];
    if(self){
        [self setupInitialState:frame];
    }
    return self;
}

- (void)emulatedImagePickerController:(AVFoundationCameraController *)imagePicker didScaledTo:(CGFloat)scale viewRect:(CGRect)rect{
    NSLog(@"%f, %@", scale, NSStringFromCGRect(rect));
}

- (void)emulatedImagePickerController:(AVFoundationCameraController *)imagePicker didFinishPickingImage:(UIImage *)image{
    
}
@end
