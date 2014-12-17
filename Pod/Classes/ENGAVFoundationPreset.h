//
//  AVFoundationPreset.h
//
//  Created by Kentaro ISHITOYA on 12/03/17.
//  Copyright (c) 2012 cocotomo. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum{
    ENGAVFoundationPresetTypePhoto,
    ENGAVFoundationPresetTypeVideo
} ENGAVFoundationPresetType;

@interface ENGAVFoundationPreset : NSObject<NSCoding>
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *desc;

- (id)initWithCoder:(NSCoder*)coder;
- (void)encodeWithCoder:(NSCoder*)coder;
- (id)initWithName:(NSString *)name andDesc:(NSString *)description;
+ (id)presetWithName:(NSString *)name andDesc:(NSString *)description;
+ (NSArray *) availablePhotoPresets;
+ (NSArray *) availableVideoPresets;
@end
