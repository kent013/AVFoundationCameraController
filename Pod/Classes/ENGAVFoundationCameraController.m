//
//  ENGAVFoundationCameraController.m
//  ENGAVFoundationCameraController
//
//  Created by ISHITOYA Kentaro on 12/01/02.
//  Copyright (c) 2012 ISHITOYA Kentaro. All rights reserved.
//

#import <CoreMedia/CoreMedia.h>
#import <ImageIO/ImageIO.h>
#import "ENGAVFoundationCameraController.h"
#import "ENGAVFoundationPreset.h"
#import "UIImage+ResizeNCrop.h"

#define INDICATOR_RECT_SIZE 50.0
#define PICKER_MAXIMUM_ZOOM_SCALE 3 
#define PICKER_PADDING_X 10
#define PICKER_PADDING_Y 10
#define PICKER_SHUTTER_BUTTON_WIDTH 60
#define PICKER_SHUTTER_BUTTON_HEIGHT 30
#define PICKER_FLASHMODE_BUTTON_WIDTH 60
#define PICKER_FLASHMODE_BUTTON_HEIGHT 30
#define PICKER_CAMERADEVICE_BUTTON_WIDTH 60
#define PICKER_CAMERADEVICE_BUTTON_HEIGHT 30
#define ACCELEROMETER_INTERVAL 0.4

NSString *kTempVideoURL = @"kTempVideoURL";

//-----------------------------------------------------------------------------
//Private Implementations
//-----------------------------------------------------------------------------
@interface ENGAVFoundationCameraController()
- (void) initCameraWithMode:(ENGAVFoundationCameraMode)mode;
- (void) handleTapGesture: (UITapGestureRecognizer *)recognizer;
- (void) handlePinchGesture: (UIPinchGestureRecognizer *)recognizer;
- (void) handleShutterButtonTapped:(UIButton *)sender;
- (void) handleCameraDeviceButtonTapped:(UIButton *)sender;
- (void) setFocus:(CGPoint)point;
- (void) setupAVFoundation:(ENGAVFoundationCameraMode)mode;
- (void) autofocus;
- (void) updateCameraControls;
- (NSData *) cropImageData:(NSData *)data withViewRect:(CGRect)viewRect andScale:(CGFloat)scale;
- (CGRect) normalizeCropRect:(CGRect)rect size:(CGSize)size;
- (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections;
- (void) onVideoRecordingTimer;
- (NSURL*) tempVideoURL;
- (void) freezeCaptureForInterval:(NSTimeInterval)interval;
- (void) unfreezeCapture;
- (void) playShutterSound;
- (void) playVideoBeepSound;
- (CGImageRef) newCGImageRefFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (int) getImageRotationAngle;

- (void) applicationWillResignActive;
- (void) applicationDidEnterBackground;
- (void) applicationDidBecomeActive;

- (void) startRecordingVideoInternal:(NSURL *)url;
- (void) disableShutterForInterval:(NSTimeInterval)interval;
- (void) enableShutter;
- (void) setDefaultValues;

@property(nonatomic, assign) BOOL hasMultipleCameraDevices;
@property(nonatomic, assign) AVCaptureDevice *backCameraDevice;
@property(nonatomic, assign) AVCaptureDevice *frontFacingCameraDevice;
@property(nonatomic, assign) AVCaptureDevice *audioDevice;
@property(nonatomic, assign) BOOL frontFacingCameraAvailable;
@property(nonatomic, assign) BOOL backCameraAvailable;
@property(nonatomic, assign) BOOL isRecordingVideo;
@property(nonatomic, assign) BOOL isVideoFrameCapturing;
@property(nonatomic, assign) CGRect squareGridRect;
@property(nonatomic, assign) BOOL canTakePicture;
@end

//-----------------------------------------------------------------------------
//Private Implementations
//-----------------------------------------------------------------------------
@implementation ENGAVFoundationCameraController
/*!
 * gesture recognizer delegate
 */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:[UIButton class]]){
        return FALSE;
    }
    return TRUE;
}

/*!
 * initialize camera
 */
-(void)initCameraWithMode:(ENGAVFoundationCameraMode)mode{
#if TARGET_IPHONE_SIMULATOR
    _mode = mode;
    return;
#endif
    if(self.cameraDeviceType == ENGAVFoundationCameraDeviceTypeBack){
        _device = self.backCameraDevice;
    }else{
        _device = self.frontFacingCameraDevice;
    }
    
    // add indicator layer
    [_indicatorLayer removeFromSuperlayer];
    _indicatorLayer = [CALayer layer];
    _indicatorLayer.borderColor = [[UIColor whiteColor] CGColor];
    _indicatorLayer.borderWidth = 1.0;
    _indicatorLayer.frame = 
    CGRectMake(self.bounds.size.width/2.0 - INDICATOR_RECT_SIZE/2.0,
               self.bounds.size.height/2.0 - INDICATOR_RECT_SIZE/2.0,
               INDICATOR_RECT_SIZE,
               INDICATOR_RECT_SIZE);
    _indicatorLayer.hidden = self.showsIndicator;
    
    //add square grid layer
    [_squareGridLayer removeFromSuperlayer];
    _squareGridLayer = [CALayer layer];
    _squareGridLayer.borderColor = [[UIColor whiteColor] CGColor];
    _squareGridLayer.borderWidth = 1.0;
    
    CGFloat h = self.bounds.size.width;
    if(self.bounds.size.height < self.bounds.size.width){
        h = self.bounds.size.height;
    }
    _squareGridLayer.frame = 
    CGRectMake((self.bounds.size.width - h) / 2.7,
               (self.bounds.size.height - h) / 2.7, h, h);
    _squareGridLayer.hidden = self.showsSquareGrid;
    
    //set mode initializes session
    [self setupAVFoundation:mode];
    
    [_device addObserver:self
              forKeyPath:@"adjustingExposure"
                 options:NSKeyValueObservingOptionNew
                 context:nil];
    _viewOrientation = UIDeviceOrientationPortrait;
    if([self.delegate respondsToSelector:@selector(cameraControllerDidInitialized:)]){
        [self.delegate cameraControllerDidInitialized:self];
    }
}

/*!
 * update camera controls
 */
- (void)updateCameraControls{
    [_shutterButton removeFromSuperview];
    [_flashModeButton removeFromSuperview];
    [_cameraDeviceButton removeFromSuperview];
    [_videoElapsedTimeLabel removeFromSuperview];
    _indicatorLayer.hidden = YES;
    _squareGridLayer.hidden = YES;
    
    CGRect f = self.frame;
    if(self.mode == ENGAVFoundationCameraModeVideo ){
        if(self.showsVideoElapsedTimeLabel && [_videoElapsedTimeLabel isDescendantOfView:self] == NO){
            CGSize size = [@"00:00" sizeWithAttributes:@{NSFontAttributeName:_videoElapsedTimeLabel.font}];
            _videoElapsedTimeLabel.frame = CGRectMake(f.size.width - size.width - PICKER_PADDING_X, PICKER_PADDING_Y, size.width, size.height);        
            [self addSubview: _videoElapsedTimeLabel];
        }
    }else{
        if(self.showsCameraControls == NO){
            return;
        }
        if(self.showsShutterButton && [_shutterButton isDescendantOfView:self] == NO){
            [_shutterButton setFrame:CGRectMake((f.size.width - PICKER_SHUTTER_BUTTON_WIDTH) / 2    , f.size.height - PICKER_SHUTTER_BUTTON_HEIGHT - PICKER_PADDING_Y, PICKER_SHUTTER_BUTTON_WIDTH, PICKER_SHUTTER_BUTTON_HEIGHT)];
            [self addSubview: _shutterButton];
        }
        if(self.showsFlashModeButton && [_flashModeButton isDescendantOfView:self] == NO){
            _flashModeButton.frame = CGRectMake(PICKER_PADDING_X, PICKER_PADDING_Y, PICKER_FLASHMODE_BUTTON_WIDTH, PICKER_FLASHMODE_BUTTON_HEIGHT);
            [self addSubview: _flashModeButton];
        }
        
        if(self.showsCameraDeviceButton && [_cameraDeviceButton isDescendantOfView:self] == NO){
            _cameraDeviceButton.frame = CGRectMake(f.size.width - PICKER_CAMERADEVICE_BUTTON_WIDTH - PICKER_PADDING_X, PICKER_PADDING_Y, PICKER_CAMERADEVICE_BUTTON_WIDTH, PICKER_CAMERADEVICE_BUTTON_HEIGHT);        
            [self addSubview: _cameraDeviceButton];
        }
        if(self.showsIndicator){
            _indicatorLayer.hidden = NO;
        }
        if(self.showsSquareGrid){
            _squareGridLayer.hidden = NO;
        }
    }
}

/*!
 * focus
 */
- (void) handleTapGesture:(UITapGestureRecognizer *)recognizer
{
    if(self.mode == ENGAVFoundationCameraModeVideo){
        return;
    }
    if(self.useTapToFocus == NO){
        return;
    }
    CGPoint point = [recognizer locationInView:self];
    
    _indicatorLayer.frame = CGRectMake(point.x - INDICATOR_RECT_SIZE /2.0,
                                       point.y - INDICATOR_RECT_SIZE /2.0,
                                       INDICATOR_RECT_SIZE,
                                       INDICATOR_RECT_SIZE);
    point.x = (point.x + fabs(_previewLayer.frame.origin.x)) / _scale;
    point.y = (point.y + fabs(_previewLayer.frame.origin.y)) / _scale;
    [self setFocus:point];
}

/*!
 * zoom
 */
- (void)handlePinchGesture:(UIPinchGestureRecognizer *)recognizer {
    if(self.mode == ENGAVFoundationCameraModeVideo){
        return;
    }
    CGFloat pinchScale = recognizer.scale;
    if(recognizer.state == UIGestureRecognizerStateBegan){
        _lastPinchScale = pinchScale;
        return;
    }
    if(_lastPinchScale == 0){
        _lastPinchScale = pinchScale;
        return;
    }
    
    //calculate zoom scale
    CGFloat diff = (pinchScale - _lastPinchScale) * 2;
    CGFloat scale = _scale;
    if(diff > 0){
        scale += 0.08;
    }else{
        scale -= 0.08;
    }
    if(scale > PICKER_MAXIMUM_ZOOM_SCALE){
        scale = PICKER_MAXIMUM_ZOOM_SCALE;
    }else if(scale < 1.0){
        scale = 1.0;
    }
    if(_scale == scale){
        return;
    }
    _scale = scale;
    
    //calcurate zoom rect
    CGAffineTransform zt = CGAffineTransformScale(CGAffineTransformIdentity, _scale, _scale);
    CGRect rect = CGRectApplyAffineTransform(_defaultBounds, zt);
    
    if(CGPointEqualToPoint(_pointOfInterest, CGPointZero) || scale == 1.0){
        rect.origin.x = 0;
        rect.origin.y = 0;
    }else{
        rect.origin.x = -((_pointOfInterest.x * _scale) - _defaultBounds.size.width / 2);
        rect.origin.y = -((_pointOfInterest.y * _scale) - _defaultBounds.size.height / 2);
    }
    if(rect.origin.x > 0){
        rect.origin.x = 0;
    }
    if(rect.origin.y > 0){
        rect.origin.y = 0;
    }
    if(rect.origin.x + rect.size.width < _defaultBounds.size.width){
        rect.origin.x = _defaultBounds.size.width - rect.size.width;
    }
    if(rect.origin.y + rect.size.height < _defaultBounds.size.height){
        rect.origin.y = _defaultBounds.size.height - rect.size.height;
    }
    _layerRect = rect;
    
    //calcurate indicator rect
    CGRect iframe = _indicatorLayer.frame;
    iframe.origin.x = (_pointOfInterest.x * _scale) - fabs(rect.origin.x) - INDICATOR_RECT_SIZE / 2.0;
    iframe.origin.y = (_pointOfInterest.y * _scale) - fabs(rect.origin.y) - INDICATOR_RECT_SIZE / 2.0;
    
    //set frame without animation
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    _previewLayer.frame = rect;    
    _indicatorLayer.frame = iframe;
    [CATransaction commit];
    _lastPinchScale = pinchScale;
    
    if(scale == 1.0){
        _croppedViewRect = CGRectZero;
    }else{
        _croppedViewRect = CGRectMake(fabsf(rect.origin.x), fabsf(rect.origin.y), _defaultBounds.size.width, _defaultBounds.size.height);
    }
    
    if([self.delegate respondsToSelector:@selector(cameraController:didScaledTo:viewRect:)]){
        [self.delegate cameraController:self didScaledTo:_scale viewRect:_croppedViewRect];
    }
}

/*!
 * autofocus
 */
- (void) autofocus{
    if (_adjustingExposure) {
        return;
    }
    NSError* error = nil;
    if ([_device lockForConfiguration:&error] == NO) {
        NSLog(@"%s|[ERROR] %@", __PRETTY_FUNCTION__, error);
    }
    if ([_device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
        _device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        
    } else if ([_device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        _device.focusMode = AVCaptureFocusModeAutoFocus;
    }
    
    if ([_device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        _device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    } else if ([_device isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
        _device.exposureMode = AVCaptureExposureModeAutoExpose;
    }
    
    if ([_device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
        _device.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
    } else if ([_device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
        _device.whiteBalanceMode = AVCaptureWhiteBalanceModeAutoWhiteBalance;
    }
    [_device unlockForConfiguration];
}

/*!
 * set focus and exposure point
 */
- (void)setFocus:(CGPoint)p
{
    CGSize viewSize = self.bounds.size;
    _pointOfInterest = p;
    CGPoint pointOfInterest = CGPointMake(p.y / viewSize.height,
                                          1.0 - p.x / viewSize.width);
    NSError* error = nil;
    if ([_device lockForConfiguration:&error] == NO) {
        NSLog(@"%s|[ERROR] %@", __PRETTY_FUNCTION__, error); 
    }
    
    if ([_device isFocusPointOfInterestSupported] &&
        [_device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        _device.focusPointOfInterest = pointOfInterest;
        _device.focusMode = AVCaptureFocusModeAutoFocus;
    }
    
    if ([_device isExposurePointOfInterestSupported] &&
        [_device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]){
        _adjustingExposure = YES;
        _device.exposurePointOfInterest = pointOfInterest;
        _device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    }
    
    [_device unlockForConfiguration];
}

/*!
 * observe
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (!_adjustingExposure) {
        return;
    }
    
	if ([keyPath isEqual:@"adjustingExposure"] == NO ||
        [[change objectForKey:NSKeyValueChangeNewKey] boolValue]) {
        return;
    }
    
    _adjustingExposure = NO;
    
    NSError *error = nil;
    if ([_device lockForConfiguration:&error]) {
        [_device setExposureMode:AVCaptureExposureModeLocked];
        [_device unlockForConfiguration];
    }
    [self performSelector:@selector(autofocus) withObject:nil afterDelay:1];
}

/*!
 * shutter tapped
 */
- (void)handleShutterButtonTapped:(UIButton *)sender{
    [self takePicture];
}

/*!
 * camera device tapped
 */
- (void)handleCameraDeviceButtonTapped:(UIButton *)sender{
    ENGAVFoundationCameraMode modebak = self.mode;
    self.mode = ENGAVFoundationCameraModeInvalid;
    if(_device.position == AVCaptureDevicePositionBack){
        self.cameraDeviceType = ENGAVFoundationCameraDeviceTypeFront;
        [self initCameraWithMode:modebak];
    }else{
        self.cameraDeviceType = ENGAVFoundationCameraDeviceTypeBack;
        [self initCameraWithMode:modebak];
    }
    [self updateCameraControls];
}

/*
 * crop image data with data
 * @param data 
 * @param rect crop rect
 */
- (NSData *)cropImageData:(NSData *)data withViewRect:(CGRect)viewRect andScale:(CGFloat)scale{
    if(CGRectEqualToRect(viewRect, CGRectZero)){
        return data;
    }
    
    UIImage *image = [UIImage  imageWithData:data];

    double centerXRate =  _pointOfInterest.x / _defaultBounds.size.width;
    double centerYRate = _pointOfInterest.y / _defaultBounds.size.height;
    int w = image.size.width / scale;
    int h = image.size.height / scale;
    int x = 0; 
    int y = 0;
    switch(_videoOrientation){
        case AVCaptureVideoOrientationPortrait:
            x = centerXRate * image.size.width - w / 2;
            y = centerYRate * image.size.height - h / 2;
            break;
        case AVCaptureVideoOrientationLandscapeRight:
            x = centerYRate * image.size.width - w / 2;
            y = image.size.height - centerXRate * image.size.height - h / 2;
            break;
        case AVCaptureVideoOrientationLandscapeLeft:
            x = image.size.width - centerYRate * image.size.width - w / 2;
            y = centerXRate * image.size.height - h / 2;
            break;
        case AVCaptureVideoOrientationPortraitUpsideDown:
            break;
    }
    if(x < 0 ) x = 0;
    if(y < 0 ) y = 0;
    if(x + w > image.size.width) x = image.size.width - w;
    if(y + y > image.size.height) y = image.size.height - h;
    CGRect rect = CGRectMake(x, y, w, h);
    
    image = [[image cropInRect:rect] resizeImageAtSize:image.size];
    NSData *croppedData = UIImageJPEGRepresentation(image, 1.0);
    if(croppedData == nil){
        return data;
    }
    CGImageSourceRef croppedImage = CGImageSourceCreateWithData((__bridge CFDataRef)croppedData, NULL);
    
    //read exif data
    CGImageSourceRef cfImage = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    NSDictionary *metadata = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(cfImage, 0, nil);
    
    //write back exif info
    CGImageSourceRef croppedCFImage = CGImageSourceCreateWithData((__bridge CFDataRef)croppedData, NULL);
    
    NSMutableDictionary *croppedMetadata = [NSMutableDictionary dictionaryWithDictionary:(__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(croppedCFImage, 0, nil)];
    NSMutableDictionary *exifMetadata = [metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary];
    [croppedMetadata setValue:exifMetadata forKey:(NSString *)kCGImagePropertyExifDictionary];
	CGImageDestinationRef dest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)croppedData, CGImageSourceGetType(croppedImage), 1, NULL);
	CGImageDestinationAddImageFromSource(dest, croppedImage, 0, (__bridge CFDictionaryRef)croppedMetadata);
	CGImageDestinationFinalize(dest);
    
    //release 
	CFRelease(cfImage);
    CFRelease(croppedCFImage);
    CFRelease(croppedImage);
	CFRelease(dest);
    return croppedData;   
}

/*!
 * normalize crop rect
 * @param rect target rect
 * @return CGRect
 */
- (CGRect)normalizeCropRect:(CGRect)rect size:(CGSize)size{
    CGRect rotatedRect = rect;
    if((_viewOrientation == UIDeviceOrientationPortrait && 
              _videoOrientation == AVCaptureVideoOrientationLandscapeLeft) ||
             (_viewOrientation == UIDeviceOrientationPortraitUpsideDown &&
              _videoOrientation == AVCaptureVideoOrientationLandscapeRight)){
        rotatedRect.origin.x = size.height - rect.origin.y;
        rotatedRect.origin.y = rect.origin.x;
    }else if((_viewOrientation == UIDeviceOrientationPortrait && 
              _videoOrientation == AVCaptureVideoOrientationLandscapeRight) ||
             (_viewOrientation == UIDeviceOrientationPortraitUpsideDown &&
              _videoOrientation == AVCaptureVideoOrientationLandscapeLeft)){
        rotatedRect.origin.x = rect.origin.y;
        rotatedRect.origin.y = size.height - rect.origin.x;
    }
    
    if(rotatedRect.origin.x < 0){
        rotatedRect.origin.x = 0;
    }
    if(rotatedRect.origin.y < 0){
        rotatedRect.origin.y = 0;
    }
    if(rotatedRect.origin.x + rotatedRect.size.width > size.width){
        rotatedRect.origin.x = size.width - rotatedRect.size.width;
    }
    if(rotatedRect.origin.y + rotatedRect.size.height > size.height){
        rotatedRect.origin.y = size.height - rotatedRect.size.height;
    }
    //NSLog(@"size  :%@", NSStringFromCGSize(size));
    //NSLog(@"before:%@", NSStringFromCGRect(rect));
    //NSLog(@"after :%@", NSStringFromCGRect(rotatedRect));
    return rotatedRect;
}

/*!
 * get capture connection with mediatype
 */
- (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections
{
	for ( AVCaptureConnection *connection in connections ) {
		for ( AVCaptureInputPort *port in [connection inputPorts] ) {
			if ( [[port mediaType] isEqual:mediaType] ) {
				return connection;
			}
		}
	}
	return nil;
}

/*!
 * on timer
 */
- (void)onVideoRecordingTimer{
    int minute = -([_videoRecordingStartedDate timeIntervalSinceNow] + 0.01)/ 60;
    int sec = -(int)([_videoRecordingStartedDate timeIntervalSinceNow] + 0.01) % 60;
    _videoElapsedTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d", minute, sec];
}

/*!
 * get temp video URL
 */
- (NSURL *)tempVideoURL{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *num = [defaults objectForKey:kTempVideoURL];
    int n = [num intValue];
    if(n > 5){
        n = 0;
    }else{
        n++;
    }
    
    NSString *filename = [NSString stringWithFormat:@"file://%@/tmp/output%d.mov", NSHomeDirectory(), n];
    NSURL *url = [NSURL URLWithString:filename];
    @synchronized(self){
        NSFileManager *manager = [NSFileManager defaultManager];
        if([manager fileExistsAtPath:url.path]){
            [manager removeItemAtURL:url error:nil];
        }
        while([manager fileExistsAtPath:url.path]){
            [NSThread sleepForTimeInterval:1];
        }
        //NSLog(@"deleted");
        [defaults setObject:[NSNumber numberWithInt:n] forKey:kTempVideoURL];
    };
    return url;
}

/*!
 * show freeze photo view
 */
- (void)freezeCaptureForInterval:(NSTimeInterval)interval{
    [_session stopRunning];
    [self performSelector:@selector(unfreezeCapture) withObject:nil afterDelay:interval];
}

/*!
 * hide freeze photo view
 */
- (void)unfreezeCapture{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if(_session.isRunning == NO){
            [_session startRunning];
        }
    });
}

/*!
 * play shutter sound
 */
- (void)playShutterSound{
    if(_shutterSoundPlayer.isPlaying){
        [_shutterSoundPlayer stop];
        _shutterSoundPlayer.currentTime = 0;
    }
    [_shutterSoundPlayer play];
}

/*!
 * play video sound
 */
- (void)playVideoBeepSound{
    [_videoBeepSoundPlayer play];
}

/*!
 * get image rotation angle
 */
- (int)getImageRotationAngle{
    if(self.cameraDeviceType == ENGAVFoundationCameraDeviceTypeFront){
        if(_videoOrientation == 1){
            return -90;
        }else if(_videoOrientation == 2){
            return 90;
        }else if(_videoOrientation == 3){
            return 180;
        }
    }else{
        if(_videoOrientation == 1){
            return -90;
        }else if(_videoOrientation == 2){
            return 90;
        }else if(_videoOrientation == 4){
            return 180;
        }
    }
    return 0;
}

/*!
 * create image from sample buffer
 * http://stackoverflow.com/questions/3305862/uiimage-created-from-cmsamplebufferref-not-displayed-in-uiimageview
 */
- (CGImageRef) newCGImageRefFromSampleBuffer:(CMSampleBufferRef) sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer); 
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
    
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst); 
    CGImageRef newImage = CGBitmapContextCreateImage(newContext); 
    CGContextRelease(newContext); 
    
    CGColorSpaceRelease(colorSpace); 
    CVPixelBufferUnlockBaseAddress(imageBuffer,0); 
    
    return newImage;
}

/*!
 * application will resign active
 */
- (void)applicationWillResignActive{
    _isApplicationActive = NO;
    if(self.isRecordingVideo == NO){
        return;
    }
    [self stopRecordingVideo];
}

/*!
 * application did enter background
 */
- (void)applicationDidEnterBackground{
    _isApplicationActive = NO;
}

/*!
 * application did become active
 */
- (void)applicationDidBecomeActive{
    if(_backgroundRecordingId != UIBackgroundTaskInvalid){
        _backgroundRecordingId = UIBackgroundTaskInvalid;
    }
    _isApplicationActive = YES;
    if(_session.isRunning == NO){
        [_session startRunning];
    }
}

/*!
 * setup AVFoundation
 */
- (void)setupAVFoundation:(ENGAVFoundationCameraMode)mode{
    
    if(self.cameraDeviceType == ENGAVFoundationCameraDeviceTypeBack){
        _device = self.backCameraDevice;
    }else{
        _device = self.frontFacingCameraDevice;
    }
    NSError *error = nil;
    
    if(_device.isFlashAvailable){
        [_device lockForConfiguration:&error];
        _device.flashMode = _flashModeButton.flashMode;
        [_device unlockForConfiguration];
    }

    [_session stopRunning];

    [_session beginConfiguration];
    [_session removeInput:_videoInput];
    [_session removeInput:_audioInput];
    [_session removeOutput:_videoDataOutput];
    [_session removeOutput:_stillImageOutput];
    [_session removeOutput:_movieFileOutput];
    
    _session = [[AVCaptureSession alloc] init];
    if(!_previewLayer){
        _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    }
    
    _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_device error:nil];
    if([_session canAddInput:_videoInput]){
        [_session addInput:_videoInput];
    }
    if(mode == ENGAVFoundationCameraModePhoto){
        if(self.stillCameraMethod == ENGAVFoundationStillCameraMethodStandard){
            _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
            [_stillImageOutput setOutputSettings:[[NSDictionary alloc] initWithObjectsAndKeys:
                                                  AVVideoCodecJPEG, AVVideoCodecKey,
                                                  nil]];
            if([_session canAddOutput:_stillImageOutput]){
                [_session addOutput:_stillImageOutput];
            }
            for (AVCaptureConnection* connection in _stillImageOutput.connections) {
                connection.videoOrientation = _videoOrientation;
            }            
        }else if(self.stillCameraMethod == ENGAVFoundationStillCameraMethodVideoCapture){
            _videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
            [_videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
            [_videoDataOutput setVideoSettings:@{(id)kCVPixelBufferPixelFormatTypeKey: @(self.pixelFormat)}];
            dispatch_queue_t queue = dispatch_queue_create("com.engraphia.videoDataOutput", NULL);
            [_videoDataOutput setSampleBufferDelegate:self queue:queue];
            //dispatch_release(queue);
            
            if([_session canAddOutput:_videoDataOutput]){
                [_session addOutput:_videoDataOutput];
            }
            for (AVCaptureConnection* connection in _videoDataOutput.connections) {
                connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            }
        }
    }else{
        _audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.audioDevice error:nil];
        if([_session canAddInput:_audioInput]){
            [_session addInput:_audioInput];
        }
        _movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        if([_session canAddOutput:_movieFileOutput]){
            [_session addOutput:_movieFileOutput];
        }
        for (AVCaptureConnection* connection in _movieFileOutput.connections) {
            connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        }
    }
    [_session commitConfiguration];
    [_indicatorLayer removeFromSuperlayer];
    [_squareGridLayer removeFromSuperlayer];
    [_previewLayer removeFromSuperlayer];
    
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _previewLayer.frame = self.bounds;
    
    [self.layer addSublayer:_previewLayer];
    [self.layer addSublayer:_indicatorLayer];
    [self.layer addSublayer:_squareGridLayer];
    
    if(_lastMode != ENGAVFoundationCameraModeNotInitialized){
        [UIView beginAnimations: @"TransitionAnimation" context:nil];
        [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight
                               forView:self
                                 cache:YES];
        [UIView setAnimationDuration:1.0];
        [UIView commitAnimations];
    }
    self.mode = mode;
    [self applyPreset];
    [self autofocus];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if(_session.isRunning == NO){
            [_session startRunning];
        }
    });
    [self updateCameraControls];
}

/*!
 * start recording
 */
- (void)startRecordingVideoInternal:(NSURL *)url{
    [_movieFileOutput startRecordingToOutputFileURL:url recordingDelegate:self];
}

/*!
 * disable shutter for interval
 */
- (void)disableShutterForInterval:(NSTimeInterval)interval{
    self.canTakePicture = NO;
    if([self.delegate respondsToSelector:@selector(shutterStateChanged:)]){
        [self.delegate shutterStateChanged:self.canTakePicture];
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(enableShutter) object:nil];
    [self performSelector:@selector(enableShutter) withObject:nil afterDelay:interval];
}

/*!
 * enable shutter
 */
-(void)enableShutter{
    self.canTakePicture = YES;
    if([self.delegate respondsToSelector:@selector(shutterStateChanged:)]){
        [self.delegate shutterStateChanged:self.canTakePicture];
    }
}


- (void)viewWillDisappear:(BOOL)animated{
    [_device removeObserver:self
                 forKeyPath:@"adjustingExposure"];
}

- (void)setDefaultValues{
    _lastMode = ENGAVFoundationCameraModeNotInitialized;
    self.cameraDeviceType = ENGAVFoundationCameraDeviceTypeBack;
    self.photoPreset = AVCaptureSessionPresetPhoto;
    self.videoPreset = AVCaptureSessionPresetMedium;
    self.showsCameraControls = YES;
    self.showsShutterButton = YES;
    self.showsIndicator = YES;
    self.showsSquareGrid = NO;
    self.useTapToFocus = YES;
    self.showsVideoElapsedTimeLabel = YES;
    self.freezeAfterShutter = NO;
    self.canTakePicture = YES;
    self.drawPreview = YES;
    self.freezeInterval = 0.1;
    if(_device.isTorchAvailable){
        self.showsFlashModeButton = YES;
    }
    if(self.hasMultipleCameraDevices){
        self.showsCameraDeviceButton = YES;
    }
}

//-----------------------------------------------------------------------------
//Public Implementations
//-----------------------------------------------------------------------------
#pragma mark - public implementation
/*!
 * initializer
 * @param frame
 */
- (id)initWithFrame:(CGRect)frame cameraMode:(ENGAVFoundationCameraMode)mode stillCameraMethod:(ENGAVFoundationStillCameraMethod)stillCameraMethod{
    return [self initWithFrame:frame cameraMode:mode stillCameraMethod:stillCameraMethod pixelFormat:kCVPixelFormatType_32BGRA];
}

/*!
 * initializer
 * @param frame
 */
- (id)initWithFrame:(CGRect)frame cameraMode:(ENGAVFoundationCameraMode)mode stillCameraMethod:(ENGAVFoundationStillCameraMethod)stillCameraMethod pixelFormat:(OSType) pixelFormat{
    self = [super init];
    if(self){
        [self setDefaultValues];
        self.pixelFormat = pixelFormat;
        [self setupInitialState:frame cameraMode:mode stillCameraMethod:stillCameraMethod pixelFormat:pixelFormat];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if(self){
        [self setDefaultValues];
    }
    return self;
}

/*!
 * initialize view
 */
-(void)setupInitialState:(CGRect)frame cameraMode:(ENGAVFoundationCameraMode)mode stillCameraMethod:(ENGAVFoundationStillCameraMethod)stillCameraMethod pixelFormat:(OSType) pixelFormat{
    _isApplicationActive = YES;
    NSNotificationCenter *notify = [NSNotificationCenter defaultCenter];
    [notify addObserver:self selector:@selector(applicationWillResignActive)
                   name:UIApplicationWillResignActiveNotification object:NULL];
    [notify addObserver:self selector:@selector(applicationDidBecomeActive)
                   name:UIApplicationDidBecomeActiveNotification object:NULL];
    [notify addObserver:self selector:@selector(applicationDidEnterBackground)
                   name:UIApplicationDidEnterBackgroundNotification object:NULL];
    
    self.frame = frame;
    self.backgroundColor = [UIColor clearColor];
    _pointOfInterest = CGPointMake(frame.size.width / 2, frame.size.height / 2);
    _defaultBounds = frame;
    _scale = 1.0;
    _croppedViewRect = CGRectZero;
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    tapRecognizer.delegate = self;
    [self addGestureRecognizer:tapRecognizer];
    UIPinchGestureRecognizer *pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    [self addGestureRecognizer:pinchRecognizer];
    _shutterButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [_shutterButton setTitle:@"Shutter" forState:UIControlStateNormal];
    [_shutterButton addTarget:self action:@selector(handleShutterButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    _flashModeButton = [[ENGAVFoundationFlashButton alloc] init];
    _flashModeButton.delegate = self;
    _cameraDeviceButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_cameraDeviceButton setBackgroundImage:[UIImage imageNamed:@"camera_change.png"] forState:UIControlStateNormal];
    [_cameraDeviceButton addTarget:self action:@selector(handleCameraDeviceButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    _videoElapsedTimeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _videoElapsedTimeLabel.backgroundColor = [UIColor clearColor];
    _videoElapsedTimeLabel.textColor = [UIColor whiteColor];
    [_videoElapsedTimer invalidate];
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        _videoElapsedTimeLabel.font = [UIFont systemFontOfSize:22];
    }else{
        _videoElapsedTimeLabel.font = [UIFont systemFontOfSize:16];
    }
    self.pixelFormat = pixelFormat;
    self.stillCameraMethod = stillCameraMethod;
    self.mode = mode;
    [self updateCameraControls];
}

/*!
 * setup
 */
- (void)start{
    [self initCameraWithMode:self.mode];
}

/*!
 * take picture
 */
-(void)takePicture
{
#if TARGET_IPHONE_SIMULATOR
    if([self.delegate respondsToSelector:@selector(cameraController:didFinishPickingImage:)]){
        [self.delegate cameraController:self didFinishPickingImage:nil];
    }
    return;
#endif
    if(self.canTakePicture == NO){
        return;
    }
    [self disableShutterForInterval:0.5];
    if(self.mode == ENGAVFoundationCameraModeVideo){
        NSLog(@"Controller is in video mode. %s", __PRETTY_FUNCTION__);
        return;
    }
    if(_session.isRunning == NO){
        return;
    }
    if(self.stillCameraMethod == ENGAVFoundationStillCameraMethodStandard){
        AVCaptureConnection *videoConnection = nil;
        for (AVCaptureConnection *connection in _stillImageOutput.connections)
        {
            for (AVCaptureInputPort *port in [connection inputPorts])
            {
                if ([[port mediaType] isEqual:AVMediaTypeVideo] )
                {
                    videoConnection = connection;
                    break;
                }
            }
            if (videoConnection) { break; }
        }
        [_stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error)
         {
             if(imageSampleBuffer == nil){
                 return;
             }
             if(self.freezeAfterShutter){
                 [self freezeCaptureForInterval:self.freezeInterval];
             }
             NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
             
             UIImage *image = nil;
             if(_scale != 1.0){
                 imageData = [self cropImageData:imageData withViewRect:_croppedViewRect andScale:_scale];
             }
             
             if(imageData == nil){
                 return;
             }
             if([self.delegate respondsToSelector:@selector(cameraController:didFinishPickingImage:)]){
                 image = [[UIImage alloc] initWithData:imageData];
                 [self.delegate cameraController:self didFinishPickingImage:image];
             }
             
             if([self.delegate respondsToSelector:@selector(cameraController:didFinishPickingImageData:)]){
                 [self.delegate cameraController:self didFinishPickingImageData:imageData];
             }
         }];
    }else if(self.stillCameraMethod == ENGAVFoundationStillCameraMethodVideoCapture){
        self.isVideoFrameCapturing = YES;
    }
}

/*!
 * start recording video
 */
- (void)startRecordingVideo{
    [self playVideoBeepSound];
    if ([[UIDevice currentDevice] isMultitaskingSupported]) {
        if(_backgroundRecordingId != UIBackgroundTaskInvalid){
            [[UIApplication sharedApplication] endBackgroundTask:_backgroundRecordingId];
        }
        _backgroundRecordingId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            if (_backgroundRecordingId != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:_backgroundRecordingId];
                _backgroundRecordingId = UIBackgroundTaskInvalid;
            }
        }];
    }
    
    [_session beginConfiguration];
    [_session removeOutput:_movieFileOutput];
    _movieFileOutput = nil;
    _movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    if([_session canAddOutput:_movieFileOutput]){
        [_session addOutput:_movieFileOutput];
    }
    for (AVCaptureConnection* connection in _movieFileOutput.connections) {
        if ([connection isVideoOrientationSupported]){
            connection.videoOrientation = _videoOrientation;
        }
    }
    [_session commitConfiguration];
    
    NSURL *url = [self tempVideoURL];
    _currentVideoURL = url;
    [self performSelector:@selector(startRecordingVideoInternal:) withObject:url afterDelay:2.0];
}

/*!
 * video data output
 */
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    if([self.delegate respondsToSelector:@selector(cameraController:drawPreviewLayer:sampleBuffer:fromConnection:)]){
        [self.delegate cameraController:self drawPreviewLayer:_previewLayer sampleBuffer:sampleBuffer fromConnection:connection];
    }
}

- (void)transformARGB8888FromImage:(const vImage_Buffer *)src toImage:(const vImage_Buffer *)dst byKernel:(NSArray *)originalKernel
{
    NSUInteger lengthOfKernel = originalKernel.count;
    int16_t kernel[lengthOfKernel];
    int32_t divisor = 0;
    for (int i = 0; i < lengthOfKernel; i++)
    {
        kernel[i] = [[originalKernel objectAtIndex:i] intValue];
        divisor += kernel[i];
    }
    unsigned int heightOfKernel = 3;
    unsigned int widthOfKernel = 3;
    Pixel_8888 bgColor = {0, 0, 0, 0};
    vImage_Flags flags = 0;
    vImageConvolve_ARGB8888(src, dst, NULL, 0, 0, kernel, heightOfKernel, widthOfKernel,
                            divisor, bgColor, flags | kvImageBackgroundColorFill);
}

/*!
 * stop recording video
 */
- (void)stopRecordingVideo{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_videoElapsedTimer invalidate];
        _videoElapsedTimeLabel.text = @"";
    });
    if(self.isRecordingVideo){
        [self playVideoBeepSound];
        [_movieFileOutput stopRecording];
    }
}

/*!
 * returns recording video
 */
-(BOOL)isRecordingVideo{
    return [_movieFileOutput isRecording];
}

/*!
 * restart session
 */
- (void)restartSession{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if(_session.isRunning == NO){
            [_session startRunning];
        }
    });
}

/*!
 * did start recording
 */
- (void) captureOutput:(AVCaptureFileOutput *)captureOutput
didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
       fromConnections:(NSArray *)connections{
    _videoRecordingStartedDate = [NSDate date];
    _videoElapsedTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(onVideoRecordingTimer) userInfo:nil repeats:YES];
    [_videoElapsedTimer fire];
    if([self.delegate respondsToSelector:@selector(cameraControllerDidStartRecordingVideo:)]){
        [self.delegate cameraControllerDidStartRecordingVideo:self];
    }    
}

/*!
 * did finish recording
 */
- (void) captureOutput:(AVCaptureFileOutput *)captureOutput
didFinishRecordingToOutputFileAtURL:(NSURL *)anOutputFileURL
                    fromConnections:(NSArray *)connections
                              error:(NSError *)error
{
    if([self.delegate respondsToSelector:@selector(cameraController:didFinishRecordingVideoToOutputFileURL:error:)]){
        _currentVideoURL = nil;
        [self.delegate cameraController:self didFinishRecordingVideoToOutputFileURL:anOutputFileURL error:error];
    }

    if ([[UIDevice currentDevice] isMultitaskingSupported]) {
        [[UIApplication sharedApplication] endBackgroundTask:_backgroundRecordingId];
        _backgroundRecordingId = UIBackgroundTaskInvalid;
    }
}   

#pragma mark - public property implementations
/*!
 * set mode
 */
-(void)setMode:(ENGAVFoundationCameraMode)mode{
    if(self.mode == mode){
        return;
    }
    _lastMode = self.mode;
    _mode = mode;
    [self setupAVFoundation:mode];
}

/*!
 * set still capture mode
 */
- (void)setStillCameraMethod:(ENGAVFoundationStillCameraMethod)stillCameraMethod{
    dispatch_async(dispatch_get_main_queue(), ^{
        if(self.stillCameraMethod == stillCameraMethod){
            return;
        }
        if(self.mode != ENGAVFoundationCameraModePhoto){
            return;
        }
        _stillCameraMethod = stillCameraMethod;
        
        NSError *error = nil;
        if(_device.isFlashAvailable){
            [_device lockForConfiguration:&error];
            _device.flashMode = _flashModeButton.flashMode;
            [_device unlockForConfiguration];
        }

        [_session beginConfiguration];
        [_session removeOutput:_videoDataOutput];
        [_session removeOutput:_stillImageOutput];
        if(self.stillCameraMethod == ENGAVFoundationStillCameraMethodStandard){
            _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
            [_stillImageOutput setOutputSettings:[[NSDictionary alloc] initWithObjectsAndKeys:
                                                  AVVideoCodecJPEG, AVVideoCodecKey,
                                                  nil]];
            for (AVCaptureConnection* connection in _stillImageOutput.connections) {
                connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            }
            if([_session canAddOutput:_stillImageOutput]){
                [_session addOutput:_stillImageOutput];
            }
            for (AVCaptureConnection* connection in _stillImageOutput.connections) {
                connection.videoOrientation = _videoOrientation;
            }            
        }else if(self.stillCameraMethod == ENGAVFoundationStillCameraMethodVideoCapture){
            _videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
            [_videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
            [_videoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:self.pixelFormat] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
            dispatch_queue_t queue = dispatch_queue_create("com.engraphia.videoDataOutput", NULL);
            [_videoDataOutput setSampleBufferDelegate:self queue:queue];
            //dispatch_release(queue);
            
            if([_session canAddOutput:_videoDataOutput]){
                [_session addOutput:_videoDataOutput];
            }
            for (AVCaptureConnection* connection in _videoDataOutput.connections) {
                connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            }
        }
        [_session commitConfiguration];
    });
}

/*!
 * apply preset
 */
- (void)applyPreset{
    [_session beginConfiguration];
    if(self.mode == ENGAVFoundationCameraModePhoto){
        _session.sessionPreset = self.photoPreset;
    }else{
        _session.sessionPreset = self.videoPreset;
    }    
    [_session commitConfiguration];
}

/*!
 * shows camera controls
 */
- (void)setShowsCameraControls:(BOOL)showsCameraControls{
    _showsCameraControls = showsCameraControls;
    [self updateCameraControls];
}

/*!
 * shows camera device button
 */
- (void)setShowsCameraDeviceButton:(BOOL)showsCameraDeviceButton{
    _showsCameraDeviceButton = showsCameraDeviceButton;
    [self updateCameraControls];
}

/*!
 * shows flash mode button
 */
- (void)setShowsFlashModeButton:(BOOL)showsFlashModeButton{
    _showsFlashModeButton = showsFlashModeButton;
    [self updateCameraControls];
}

/*!
 * shows shutter button
 */
- (void)setShowsShutterButton:(BOOL)showsShutterButton{
    _showsShutterButton = showsShutterButton;
    [self updateCameraControls];
}

/*!
 * shows video elapsed time label
 */
- (void)setShowsVideoElapsedTimeLabel:(BOOL)showsVideoElapsedTimeLabel{
    showsVideoElapsedTimeLabel = showsVideoElapsedTimeLabel;
    [self updateCameraControls];
}

/*!
 * shows indicator
 */
- (void)setShowsIndicator:(BOOL)showsIndicator{
    _showsIndicator = showsIndicator;
    [self updateCameraControls];
}

/*!
 * shows squareGrid
 */
- (void)setShowsSquareGrid:(BOOL)showsSquareGrid{
    _showsSquareGrid = showsSquareGrid;
    [self updateCameraControls];
}

/*!
 * square grid rect
 */
- (CGRect)squareGridRect{
    return _squareGridLayer.frame;
}

/*!
 * use tap to focus
 */
- (void)setUseTapToFocus:(BOOL)useTapToFocus{
    _useTapToFocus = useTapToFocus;
    if(self.useTapToFocus){
        _indicatorLayer.hidden = NO;
    }else{
        [self autofocus];
        _indicatorLayer.hidden = YES;
    }
}

/*!
 * check the device has multiple video devices
 */
- (BOOL)hasMultipleCameraDevices{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    return devices.count > 1;
}

/*!
 * get front-facing camera device
 */
- (AVCaptureDevice *)frontFacingCameraDevice{
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in videoDevices) {
        if (device.position == AVCaptureDevicePositionFront) {
            return device;
        }
    }
    return nil;
}

/*!
 * get back camera device
 */
- (AVCaptureDevice *)backCameraDevice{
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in videoDevices) {
        if (device.position == AVCaptureDevicePositionBack) {
            return device;
        }
    }
    return nil;
}

/*!
 * get audio device
 */
- (AVCaptureDevice *) audioDevice
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if ([devices count] > 0) {
        return [devices objectAtIndex:0];
    }
    return nil;
}

/*!
 * check the device has front-facing camera device
 */
- (BOOL)frontFacingCameraAvailable{
    return self.frontFacingCameraDevice != nil;
}

/*!
 * check the device has front-facing camera device
 */
- (BOOL)backCameraAvailable{
    return self.backCameraDevice != nil;
}

/*!
 * set volume
 */
- (void)setSoundVolume:(CGFloat)soundVolume{
    _soundVolume = soundVolume;
    [_shutterSoundPlayer setVolume:soundVolume];
    [_videoBeepSoundPlayer setVolume:soundVolume];
}

/*!
 * set pixel format
 */
- (void)setPixelFormat:(OSType)pixelFormat{
    _pixelFormat = pixelFormat;
    [_videoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:self.pixelFormat] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    [_session commitConfiguration];
}

/*!
 * set drawPreview
 */
- (void)setDrawPreview:(BOOL)drawPreview{
    _drawPreview = drawPreview;
    if(drawPreview){
        [_previewLayer setSession:_session];
    }else{
        [_previewLayer setSession: nil];
    
    }
}

#pragma mark -
#pragma mark flashButton delegate

/*!
 * set flash mode
 */
- (void)setFlashMode:(AVCaptureFlashMode)mode{
    AVCaptureDevice* device = self.backCameraDevice;
    [device lockForConfiguration:nil];    
    [device setFlashMode:mode];
    [device unlockForConfiguration];
}

@end
