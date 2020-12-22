//
//  BZAVAudioSession.h
//  ZWAuidoKit
//
//  Created by ZhengWei on 16/6/28.
//  Copyright © 2016年 Bourbon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface BZAVAudioSession : NSObject

+(BZAVAudioSession *)sharedInstance;

-(void)setCategory:(NSString *)category;
-(void)setActive:(BOOL)active;

@end
