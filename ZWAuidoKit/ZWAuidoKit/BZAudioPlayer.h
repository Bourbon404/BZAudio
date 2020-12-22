//
//  BZAudioPlayer.h
//  ZWAuidoKit
//
//  Created by ZhengWei on 16/6/28.
//  Copyright © 2016年 Bourbon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
typedef NS_ENUM(NSUInteger,BZAudioPlayerStatus) {

    BZAudioPlayerStatusStopped = 0,
    BZAudioPlayerStatusPlaying = 1,
    BZAudioPlayerStatusWaiting = 2,
    BZAudioPlayerStatusPaused = 3,
    BZAudioPlayerStatusFlushing = 4,
    
};

@class BZAudioPlayer;
@protocol BZAudioPlayerDelegate <NSObject>
@optional
//播放信息获取完毕
-(void)audioPlayInfoGetSuccess:(BZAudioPlayer *)player;

@end
@interface BZAudioPlayer : NSObject

@property (nonatomic,assign,readonly) NSTimeInterval duration;
@property (nonatomic,assign,readonly) NSTimeInterval currentTime;

@property (nonatomic,copy,readonly) NSString *title;
@property (nonatomic,copy,readonly) NSString *album;
@property (nonatomic,strong,readonly) UIImage *icon;

@property (nonatomic,assign,readonly) BZAudioPlayerStatus status;
@property (nonatomic,copy) NSString *filePath;

@property (nonatomic,assign) BOOL isUseAudioFileStream;

@property (nonatomic,weak) id<BZAudioPlayerDelegate>delegate;

+(BZAudioPlayer *)sharedInstance;

-(void)play;
-(void)pause;
-(void)stop;
-(void)seekToProgess:(float)progress;

@end
