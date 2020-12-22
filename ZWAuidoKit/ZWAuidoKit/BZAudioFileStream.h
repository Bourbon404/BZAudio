//
//  BZAudioFileStream.h
//  ZWAuidoKit
//
//  Created by ZhengWei on 16/7/1.
//  Copyright © 2016年 Bourbon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
@class BZAudioFileStream;
@protocol BZAudioFileStreamDelegate <NSObject>

@optional
-(void)audioFileStreamReadyToProducePackets:(BZAudioFileStream *)audioFileStream;
@required
-(void)audioFileStream:(BZAudioFileStream *)audioFileStream audioDataParsed:(NSArray *)audioData;

@end
@interface BZAudioFileStream : NSObject

@property (nonatomic,assign,readonly) AudioFileTypeID fileType;
@property (nonatomic,assign,readonly) unsigned long long fileSize;
@property (nonatomic,assign,readonly) UInt32 bitRate;
@property (nonatomic,assign,readonly) BOOL readyToProducePackets;
@property (nonatomic,assign,readonly) NSTimeInterval duration;
@property (nonatomic,assign,readonly) BOOL available;
@property (nonatomic,assign,readonly) AudioStreamBasicDescription format;
/**
 *  真正的音频文件的内容大小
 */
@property (nonatomic,assign,readonly) UInt64 audioDataByteCount;

//专辑名称
@property (nonatomic,copy,readonly) NSString *album;
//歌曲名称
@property (nonatomic,copy,readonly) NSString *title;
//歌曲封面
@property (nonatomic,strong,readonly) UIImage *artAlbum;

@property (nonatomic,copy) NSString *filePath;


@property (nonatomic,weak) id <BZAudioFileStreamDelegate>delegate;

-(instancetype)initWithFileType:(AudioFileTypeID)fileType withFilePath:(NSString *)filePath error:(NSError **)error;

-(BOOL)parseData:(NSData *)data error:(NSError **)error;

-(SInt64)seekToTime:(NSTimeInterval)time;
-(void)close;

- (NSData *)fetchMagicCookie;



@end
