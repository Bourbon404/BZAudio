//
//  BZAudioOutputQueue.m
//  ZWAuidoKit
//
//  Created by ZhengWei on 16/6/29.
//  Copyright © 2016年 Bourbon. All rights reserved.
//

#import "BZAudioOutputQueue.h"
const int BZAudioQUeueBufferCount = 2;
@interface BZAudioQueueBuffer : NSObject
@property (nonatomic,assign) AudioQueueBufferRef buffer;
@end
@implementation BZAudioQueueBuffer
@end
@interface BZAudioOutputQueue ()
{
@private
    AudioQueueRef _audioQueue;
    NSMutableArray *_buffers;
    NSMutableArray *_reusableBuffers;
    
    BOOL _isRunning;
    BOOL _started;
    NSTimeInterval _playedTime;
    
    pthread_mutex_t _mutex;
    pthread_cond_t _cond;
}
@end
@implementation BZAudioOutputQueue
@synthesize format = _format;
@dynamic available;
@synthesize volume = _volume;
@synthesize bufferSize = _bufferSize;
@synthesize isRunning = _isRunning;

-(instancetype)initWithFormat:(AudioStreamBasicDescription)format bufferSize:(UInt32)bufferSize macgicCookie:(NSData *)macgicCookie
{
    if (self = [super init]) {
        _format =format;
        _volume = 1.0;
        _bufferSize = bufferSize;
        
        _buffers = [[NSMutableArray alloc] init];
        _reusableBuffers = [[NSMutableArray alloc] init];
        
        [self _createAudioOutputQueue:macgicCookie];
    }
    return self;
}
/**
 *  创建audioqueue
 */
-(void)_createAudioOutputQueue:(NSData *)macgicCookie
{
    OSStatus status = AudioQueueNewOutput(&_format,
                                          BZAudioQueueOutputCallback,
                                          (__bridge void * _Nullable)(self),
                                          NULL,
                                          NULL,
                                          0,
                                          &_audioQueue);
    if (status != noErr) {
        _audioQueue = NULL;
        NSLog(@"创建播放队列失败");
        return;
    }
    NSLog(@"==========第五步创建播放队列成功，并给播放队列添加属性");
    
    status = AudioQueueAddPropertyListener(_audioQueue, kAudioQueueProperty_IsRunning, MCAudioQueuePropertyCallback, (__bridge void * _Nullable)(self));
    if (status != noErr) {
        AudioQueueDispose(_audioQueue, YES);
        _audioQueue = NULL;
        return;
    }
    if (_buffers.count == 0) {
        NSLog(@"传入的buffer错误，重新获取buffer数据");
//        for (int i = 0; i < 1; i ++) {
            AudioQueueBufferRef buffer;
            status = AudioQueueAllocateBuffer(_audioQueue, _bufferSize, &buffer);
            if (status != noErr) {
                AudioQueueDispose(_audioQueue, YES);
                _audioQueue = NULL;
//                break;
                NSLog(@"buffer数据读取失败");
                return;
            }
            BZAudioQueueBuffer *bufferObj = [[BZAudioQueueBuffer alloc] init];
            bufferObj.buffer = buffer;
            [_reusableBuffers addObject:bufferObj];
//        }
        NSLog(@"buffer数据读取成功");
    }
    
    UInt32 property = kAudioQueueProperty_HardwareCodecPolicy;
    [self setProperty:property dataSize:sizeof(property) data:&property error:NULL];
    
    if (macgicCookie) {
        [self setProperty:kAudioQueueProperty_MagicCookie dataSize:(UInt32)macgicCookie.length data:macgicCookie.bytes error:NULL];
    }
    
    //设置音量
    [self setVolumeParameter];
}
- (void)setVolumeParameter
{
    [self setParameter:kAudioQueueParam_Volume value:_volume error:NULL];
}
- (BOOL)setProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32)dataSize data:(const void *)data error:(NSError *__autoreleasing *)outError
{
    OSStatus status = AudioQueueSetProperty(_audioQueue, propertyID, data, dataSize);
    return status == noErr;
}
- (BOOL)setParameter:(AudioQueueParameterID)parameterId value:(AudioQueueParameterValue)value error:(NSError *__autoreleasing *)outError
{
    OSStatus status = AudioQueueSetParameter(_audioQueue, parameterId, value);
    return status == noErr;
}
#pragma mark -property
-(NSTimeInterval)playedTime
{
    if (_format.mSampleRate == 0) {
        return 0;
    }
    AudioTimeStamp time;
    OSStatus status = AudioQueueGetCurrentTime(_audioQueue, NULL, &time, NULL);
    if (status == noErr) {
        _playedTime = time.mSampleTime / _format.mSampleRate;
    }
    return _playedTime;
}
#pragma mark -control
-(BOOL)_start
{
    
    OSStatus status = AudioQueueStart(_audioQueue, NULL);
    _started = status == noErr;
    NSString *tmp = _started == YES ? @"成功" : @"失败";
    NSLog(@"==========第六步启动播放队列:%@",tmp);
    return _started;
}
-(BOOL)resume
{
    return [self _start];
}
-(BOOL)pause
{
    OSStatus status = AudioQueuePause(_audioQueue);
    _started = NO;
    return status == noErr;
}
-(BOOL)reset
{
    OSStatus status = AudioQueueReset(_audioQueue);
    return status == noErr;
}
-(BOOL)flush
{
    OSStatus status = AudioQueueFlush(_audioQueue);
    return status == noErr;
}
-(BOOL)stop:(BOOL)immediately
{
    OSStatus status = noErr;
    if (immediately) {
        status = AudioQueueStop(_audioQueue, true);
    }else{
        status = AudioQueueStop(_audioQueue, false);
    }
    _started = NO;
    _playedTime = 0;
    return status == noErr;
}
#pragma mark -method
-(BOOL)playData:(NSData *)data packetCount:(UInt32)packetCount packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions isEof:(BOOL)isEof
{
    if (data.length > _bufferSize) {
        return NO;
    }
    if (_reusableBuffers.count == 0) {
        if (!_started && ![self _start]) {
            return NO;
        }
    }
    
    BZAudioQueueBuffer *bufferObj = [_reusableBuffers firstObject];
    [_reusableBuffers removeObject:bufferObj];
    
    if (!bufferObj) {
        AudioQueueBufferRef buffer;
        OSStatus status = AudioQueueAllocateBuffer(_audioQueue, _bufferSize, &buffer);
        if (status == noErr) {
            bufferObj = [[BZAudioQueueBuffer alloc] init];
            bufferObj.buffer = buffer;
        }else{
            return NO;
        }
    }
    memcpy(bufferObj.buffer->mAudioData, data.bytes, data.length);
    bufferObj.buffer->mAudioDataByteSize = (UInt32)data.length;
    
    /**
        在使用AudioQueue之前首先必须理解其工作模式，它之所以这么命名是因为在其内部有一套缓冲队列（Buffer Queue）的机制。
        在AudioQueue启动之后需要通过AudioQueueAllocateBuffer生成若干个AudioQueueBufferRef结构，这些Buffer将用来存储即将要播放的音频数据，并且这些Buffer是受生成他们的AudioQueue实例管理的，内存空间也已经被分配（按照Allocate方法的参数），当AudioQueue被Dispose时这些Buffer也会随之被销毁。
        当有音频数据需要被播放时首先需要被memcpy到AudioQueueBufferRef的mAudioData中（mAudioData所指向的内存已经被分配，之前AudioQueueAllocateBuffer所做的工作），并给mAudioDataByteSize字段赋值传入的数据大小。完成之后需要调用AudioQueueEnqueueBuffer把存有音频数据的Buffer插入到AudioQueue内置的Buffer队列中。在Buffer队列中有buffer存在的情况下调用AudioQueueStart，此时AudioQueue就回按照Enqueue顺序逐个使用Buffer队列中的buffer进行播放，每当一个Buffer使用完毕之后就会从Buffer队列中被移除并且在使用者指定的RunLoop上触发一个回调来告诉使用者，某个AudioQueueBufferRef对象已经使用完成，你可以继续重用这个对象来存储后面的音频数据。如此循环往复音频数据就会被逐个播放直到结束。
     */

    OSStatus status = AudioQueueEnqueueBuffer(_audioQueue, bufferObj.buffer, packetCount, packetDescriptions);
    if (status == noErr) {
        if (_reusableBuffers.count == 0 || isEof) {
            if (!_started && ![self _start]) {
                return NO;
            }
        }
    }
    return status == noErr;
}
#pragma mark -callback
static void BZAudioQueueOutputCallback(void *inClientData,AudioQueueRef inAQ,AudioQueueBufferRef inBuffer){
    BZAudioOutputQueue *audioQueue = (__bridge BZAudioOutputQueue *)inClientData;
    [audioQueue handleAudioQueueOutputCallBack:inAQ buffer:inBuffer];
}
-(void)handleAudioQueueOutputCallBack:(AudioQueueRef)audioQueue buffer:(AudioQueueBufferRef)buffer
{
    for (int i = 0; i < _buffers.count; i++) {
        if (buffer == [_buffers[i] buffer]) {
            [_reusableBuffers addObject:_buffers[i]];
            break;
        }
    }
}
//监听播放队列启动或停止
static void MCAudioQueuePropertyCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID)
{
    NSLog(@"播放队列启动或停止了");
    BZAudioOutputQueue *audioQueue = (__bridge BZAudioOutputQueue *)inUserData;
    [audioQueue handleAudioQueuePropertyCallBack:inAQ property:inID];
}

- (void)handleAudioQueuePropertyCallBack:(AudioQueueRef)audioQueue property:(AudioQueuePropertyID)property
{
    if (property == kAudioQueueProperty_IsRunning)
    {
        UInt32 isRunning = 0;
        UInt32 size = sizeof(isRunning);
        AudioQueueGetProperty(audioQueue, property, &isRunning, &size);
        _isRunning = isRunning;
    }
}
@end
