//
//  BZAudioFile.h
//  ZWAuidoKit
//
//  Created by ZhengWei on 16/6/28.
//  Copyright © 2016年 Bourbon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
@interface BZAudioFile : NSObject

@property (nonatomic,assign,readonly) SInt64 fileSize;
@property (nonatomic,assign,readonly) AudioStreamBasicDescription format;
@property (nonatomic,assign,readonly) UInt64 audioDataByteCount;
@property (nonatomic,assign,readonly) NSTimeInterval duration;
@property (nonatomic,assign,readonly) UInt32 bitRate;

//专辑名称
@property (nonatomic,copy,readonly) NSString *album;
//歌曲名称
@property (nonatomic,copy,readonly) NSString *title;
//歌曲封面
@property (nonatomic,strong,readonly) UIImage *artAlbum;

-(instancetype)initWithFilePath:(NSString *)filePath;
-(NSArray *)parseData:(BOOL *)isEof;

- (NSData *)fetchMagicCookie;
//跳转到指定时间
-(void)seekToTime:(float)progress;

-(void)closeFile;

@end
