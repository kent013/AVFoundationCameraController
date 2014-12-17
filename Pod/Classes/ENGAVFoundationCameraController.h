//
//  ENGAVFoundationCameraController.h
//  ENGAVFoundationCameraController
//
//  Created by ISHITOYA Kentaro on 12/01/02.
//  Copyright (c) 2012 ISHITOYA Kentaro. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import "ENGAVFoundationFlashButton.h"

typedef enum {
    ENGAVFoundationCameraModeNotInitialized = -2,
    ENGAVFoundationCameraModeInvalid = -1,
    ENGAVFoundationCameraModePhoto = 0,
    ENGAVFoundationCameraModeVideo
} ENGAVFoundationCameraMode;

typedef enum {
    ENGAVFoundationStillCameraMethodStandard,
    ENGAVFoundationStillCameraMethodVideoCapture
} ENGAVFoundationStillCameraMethod;

typedef enum {
    ENGAVFoundationCameraDeviceTypeFront = 0,
    ENGAVFoundationCameraDeviceTypeBack = 1
} ENGAVFoundationCameraDeviceType;

@protocol ENGAVFoundationCameraControllerDelegate;

@interface ENGAVFoundationCameraController : UIView<UIGestureRecognizerDelegate,AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate, FlashButtonDelegate,UIAccelerometerDelegate, AVAudioSessionDelegate>{
    __strong AVCaptureDevice *_device;
    __strong AVCaptureSession *_session;
    __strong AVCaptureVideoDataOutput *_videoDataOutput;
    __strong AVCaptureDeviceInput *_imageInput;
    __strong AVCaptureDeviceInput *_audioInput;
    __strong AVCaptureDeviceInput *_videoInput;
    __strong AVCaptureVideoPreviewLayer *_previewLayer;
    __strong AVCaptureMovieFileOutput *_movieFileOutput;
    __strong AVCaptureStillImageOutput *_stillImageOutput;
    __strong CALayer *_indicatorLayer;
    __strong CALayer *_squareGridLayer;
    __strong CALayer *_overlayLayer;
    __strong UIButton *_shutterButton;
    __strong ENGAVFoundationFlashButton *_flashModeButton;
    __strong UIButton *_cameraDeviceButton;    
    __strong UIView *_cameraControlView;
    
    __strong UILabel *_videoElapsedTimeLabel;
    __strong NSTimer *_videoElapsedTimer;
    
    __strong NSURL *_currentVideoURL;
    
    BOOL _isApplicationActive;

    BOOL _adjustingExposure;
    
    NSDate *_videoRecordingStartedDate;
    
    ENGAVFoundationCameraMode _lastMode;
    CGPoint _pointOfInterest;
    CGRect _defaultBounds;
    CGFloat _lastPinchScale;
    CGFloat _scale;
    CGRect _croppedViewRect;
    CGRect _layerRect;
    
    AVCaptureVideoOrientation _videoOrientation;
    UIDeviceOrientation _viewOrientation;
    UIDeviceOrientation _deviceOrientation;
    UIBackgroundTaskIdentifier _backgroundRecordingId;
    
    AVAudioPlayer *_shutterSoundPlayer;
    AVAudioPlayer *_videoBeepSoundPlayer;
    NSMutableArray *_imageDataStack;
}

@property(nonatomic, assign) id<ENGAVFoundationCameraControllerDelegate> delegate;
@property(nonatomic, assign) IBInspectable BOOL showsCameraControls;
@property(nonatomic, assign) IBInspectable BOOL showsShutterButton;
@property(nonatomic, assign) IBInspectable BOOL showsFlashModeButton;
@property(nonatomic, assign) IBInspectable BOOL showsCameraDeviceButton;
@property(nonatomic, assign) IBInspectable BOOL showsIndicator;
@property(nonatomic, assign) IBInspectable BOOL showsVideoElapsedTimeLabel;
@property(nonatomic, assign) IBInspectable BOOL showsSquareGrid;
@property(nonatomic, assign) IBInspectable BOOL useTapToFocus;
@property(nonatomic, assign) IBInspectable BOOL freezeAfterShutter;
@property(nonatomic, assign) IBInspectable BOOL drawPreview;
@property(nonatomic, assign) IBInspectable CGFloat soundVolume;
@property(nonatomic, assign) ENGAVFoundationCameraMode mode;
@property(nonatomic, assign) ENGAVFoundationCameraDeviceType cameraDeviceType;
@property(nonatomic, assign) ENGAVFoundationStillCameraMethod stillCameraMethod;
@property(nonatomic, assign) NSTimeInterval freezeInterval;
@property(nonatomic, assign) OSType pixelFormat;
@property(nonatomic, strong) NSString *photoPreset;
@property(nonatomic, strong) NSString *videoPreset;

- (id) initWithFrame:(CGRect)frame cameraMode:(ENGAVFoundationCameraMode)mode stillCameraMethod:(ENGAVFoundationStillCameraMethod)stillCameraMethod;
- (id) initWithFrame:(CGRect)frame cameraMode:(ENGAVFoundationCameraMode)mode stillCameraMethod:(ENGAVFoundationStillCameraMethod)stillCameraMethod pixelFormat:(OSType) pixelFormat;
- (void) takePicture;
- (void) startRecordingVideo;
- (void) stopRecordingVideo;
- (void) restartSession;
- (void) applyPreset;
- (void) start;

- (void) setupInitialState:(CGRect)frame cameraMode:(ENGAVFoundationCameraMode)mode stillCameraMethod:(ENGAVFoundationStillCameraMethod)stillCameraMethod pixelFormat:(OSType) pixelFormat;
@end

@protocol ENGAVFoundationCameraControllerDelegate <NSObject>
@optional
/*!
 * delegate with image and metadata
 */
- (void) cameraController:(ENGAVFoundationCameraController *)cameraController didFinishPickingImage:(UIImage *)image;
- (BOOL) cameraController:(ENGAVFoundationCameraController *)cameraController drawPreviewLayer:(AVCaptureVideoPreviewLayer *)layer sampleBuffer:(CMSampleBufferRef) sampleBuffer;
/*!
 * capture video
 */
-(void) cameraControllerDidStartRecordingVideo:(ENGAVFoundationCameraController *) controller;
-(void) cameraController:(ENGAVFoundationCameraController *)controller didFinishRecordingVideoToOutputFileURL:(NSURL *)outputFileURL error:(NSError *)error;
/*!
 * delegate raw data and metadata
 */
- (void) cameraController:(ENGAVFoundationCameraController *)cameraController didFinishPickingImageData:(NSData *)data;
- (void) cameraController:(ENGAVFoundationCameraController *)cameraController didScaledTo:(CGFloat) scale viewRect:(CGRect)rect;
- (void) didRotatedDeviceOrientation:(UIDeviceOrientation) orientation;
- (void) cameraControllerDidInitialized:(ENGAVFoundationCameraController *)cameraController;

@optional
- (void) shutterStateChanged:(BOOL)enabled;

@end