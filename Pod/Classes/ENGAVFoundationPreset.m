//
//  AVFoundationPreset.m
//
//  Created by Kentaro ISHITOYA on 12/03/17.
//  Copyright (c) 2012 cocotomo. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import <AVFoundation/AVFoundation.h>
#import "ENGAVFoundationPreset.h"
//#import "UIDevice-Hardware.h"

static NSArray *ENGAVFoundationPresetAvaliablePhotoPresets_;
static NSArray *ENGAVFoundationPresetAvaliableVideoPresets_;

//-----------------------------------------------------------------------------
//Private Implementations
//-----------------------------------------------------------------------------
@interface ENGAVFoundationPreset(PrivateImplementatio)
@end

@implementation ENGAVFoundationPreset(PrivateImplementation)
@end

//-----------------------------------------------------------------------------
//Public Implementations
//----------------------------------------------------------------------------
@implementation ENGAVFoundationPreset
@synthesize name;
@synthesize desc;
/*!
 * init with name and description
 */
- (id)initWithName:(NSString *)inName andDesc:(NSString *)inDesc{
    self = [super init];
    if(self){
        self.name = inName;
        self.desc = inDesc;
    }
    return self;
}

/*!
 * encode
 */
- (void)encodeWithCoder:(NSCoder*)coder {
    [coder encodeObject:self.name forKey:@"name"];
    [coder encodeObject:self.desc forKey:@"desc"];
}

/*!
 * init with coder
 */
- (id)initWithCoder:(NSCoder*)coder {
    self = [super init];
    if (self) {
        self.name = [coder decodeObjectForKey:@"name"];
        self.desc = [coder decodeObjectForKey:@"desc"];
    }
    return self;
}

/*!
 * get preset
 */
+ (id)presetWithName:(NSString *)inName andDesc:(NSString *)inDesc{
    return [[ENGAVFoundationPreset alloc] initWithName:inName andDesc:inDesc];
}

/*!
 * available photo presets
 */
+ (NSArray *)availablePhotoPresets{
    if(ENGAVFoundationPresetAvaliablePhotoPresets_){
        return ENGAVFoundationPresetAvaliablePhotoPresets_;
    }
    NSMutableArray *ps = [[NSMutableArray alloc] init];
    if(AVCaptureSessionPresetPhoto != nil){
        [ps addObject:[ENGAVFoundationPreset presetWithName:AVCaptureSessionPresetPhoto andDesc:@"Photo"]];
    }
    if(AVCaptureSessionPresetHigh != nil){
        [ps addObject:[ENGAVFoundationPreset presetWithName:AVCaptureSessionPresetHigh andDesc:@"High"]];
    }
    if(AVCaptureSessionPresetMedium != nil){
        [ps addObject:[ENGAVFoundationPreset presetWithName:AVCaptureSessionPresetMedium andDesc:@"Medium"]];
    }
    if(AVCaptureSessionPresetLow != nil){
        [ps addObject:[ENGAVFoundationPreset presetWithName:AVCaptureSessionPresetLow andDesc:@"Low"]];
    }
    ENGAVFoundationPresetAvaliablePhotoPresets_ = ps;
    return ENGAVFoundationPresetAvaliablePhotoPresets_;
}

/*!
 * available video presets
 */
+ (NSArray *)availableVideoPresets{
    if(ENGAVFoundationPresetAvaliableVideoPresets_){
        return ENGAVFoundationPresetAvaliableVideoPresets_;
    }
    NSMutableArray *ps = [[NSMutableArray alloc] init];
    if(AVCaptureSessionPresetHigh != nil){
        [ps addObject:[ENGAVFoundationPreset presetWithName:AVCaptureSessionPresetHigh andDesc:@"High"]];
    }
    if(AVCaptureSessionPresetMedium != nil){
        [ps addObject:[ENGAVFoundationPreset presetWithName:AVCaptureSessionPresetMedium andDesc:@"Medium"]];
    }
    if(AVCaptureSessionPresetLow != nil){
        [ps addObject:[ENGAVFoundationPreset presetWithName:AVCaptureSessionPresetLow andDesc:@"Low"]];
    }
    ENGAVFoundationPresetAvaliableVideoPresets_ = ps;
    return ENGAVFoundationPresetAvaliableVideoPresets_;
}
@end
