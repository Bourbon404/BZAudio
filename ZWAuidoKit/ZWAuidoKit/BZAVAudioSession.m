//
//  BZAVAudioSession.m
//  ZWAuidoKit
//
//  Created by ZhengWei on 16/6/28.
//  Copyright © 2016年 Bourbon. All rights reserved.
//

#import "BZAVAudioSession.h"

@interface BZAVAudioSession ()
{
@private
    AVAudioSession *_audioSession;
}
@end

@implementation BZAVAudioSession

+(BZAVAudioSession *)sharedInstance
{
    static BZAVAudioSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        session = [[BZAVAudioSession alloc] init];
    });
    return session;
}
-(instancetype)init
{
    if (self = [super init]) {
        _audioSession = [AVAudioSession sharedInstance];
    }
    return self;
}
-(void)setCategory:(NSString *)category
{
    NSError *error = nil;
    BOOL success = [_audioSession setCategory:category error:&error];
    if (!success) {
        NSLog(@"设置类别的时候失败了:%@",error);
    }
}
-(void)setActive:(BOOL)active
{
    NSError *error = nil;
    BOOL success = [_audioSession setActive:active error:&error];
    if (!success) {
        NSLog(@"设置开始活动时失败了:%@",error);
    }
}

@end
