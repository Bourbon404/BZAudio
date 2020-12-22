//
//  BZAudioOutputQueue.h
//  ZWAuidoKit
//
//  Created by ZhengWei on 16/6/29.
//  Copyright © 2016年 Bourbon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
@interface BZAudioOutputQueue : NSObject

@property (nonatomic,assign,readonly) BOOL available;
@property (nonatomic,assign,readonly) AudioStreamBasicDescription format;
@property (nonatomic,assign) float volume;
@property (nonatomic,assign) UInt32 bufferSize;
@property (nonatomic,assign,readonly) BOOL isRunning;
/**
 *  return playedTime of audioqueue, return invalidPlayedTime when error occurs;
 */
@property (nonatomic,readonly) NSTimeInterval playedTime;

-(instancetype)initWithFormat:(AudioStreamBasicDescription)format bufferSize:(UInt32)bufferSize macgicCookie:(NSData *)macgicCookie;

-(BOOL)playData:(NSData *)data packetCount:(UInt32)packetCount packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions isEof:(BOOL)isEof;

-(BOOL)resume;
-(BOOL)pause;
-(BOOL)reset;
-(BOOL)stop:(BOOL)immediately;

@end
