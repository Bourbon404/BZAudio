//
//  BZAudioPlayer.m
//  ZWAuidoKit
//
//  Created by ZhengWei on 16/6/28.
//  Copyright © 2016年 Bourbon. All rights reserved.
//

#import "BZAudioPlayer.h"
#import "BZAVAudioSession.h"
#import "BZAudioFile.h"
#import "BZAudioOutputQueue.h"
#import "MCAudioBuffer.h"
#import "BZAudioFileStream.h"
@interface BZAudioPlayer ()
{
@private
    BZAVAudioSession *_session;
    BZAudioFile *_audioFile;
    BZAudioFileStream *_audioFileStream;
    BZAudioOutputQueue *_audioQueue;
    
    UInt32 _bufferSize;
    
    MCAudioBuffer *_buffer;
    
    BOOL _started;
    BOOL _seekRequired;
    BOOL _stopRequired;
    BOOL _pauseRequired;
        
    NSTimeInterval _seekTime;
    
    NSFileHandle *_fileHandle;
    
    unsigned long long _offset;
    unsigned long long _fileSize;
}
@end
@implementation BZAudioPlayer
@synthesize duration             = _duration;
@synthesize status               = _status;
@synthesize title                = _title;
@synthesize album                = _album;;
@synthesize icon                 = _icon;
@synthesize isUseAudioFileStream = _isUseAudioFileStream;
+(BZAudioPlayer *)sharedInstance
{
    static BZAudioPlayer *player = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        player = [[BZAudioPlayer alloc] init];
    });
    return player;
}
-(instancetype)init
{
    if (self = [super init]) {
        _session = [BZAVAudioSession sharedInstance];
        [_session setCategory:AVAudioSessionCategoryPlayback];
        [_session setActive:YES];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(methodForInterruption:) name:AVAudioSessionInterruptionNotification object:_session];
        _buffer = [MCAudioBuffer buffer];
        
        _seekRequired = NO;
        
    }
    return self;
}
-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
#pragma mark -property
-(void)setFilePath:(NSString *)filePath
{
    _filePath = filePath;
}
-(NSTimeInterval)currentTime
{
    return _audioQueue.playedTime;
}
-(NSString *)album
{
    return _isUseAudioFileStream ? _audioFileStream.album : _audioFile.album;
}
-(NSString *)title
{
    return _isUseAudioFileStream ? _audioFileStream.title : _audioFile.title;
}
#pragma mark -method
-(BOOL)cereateAudioQueue
{
    if (_audioQueue) {
        return YES;
    }
    
    NSData *macgicCookie = nil;
    AudioStreamBasicDescription format;
    UInt64 audioDataByteCount = 0;
    if (!_isUseAudioFileStream) {
        _audioFile = [[BZAudioFile alloc] initWithFilePath:_filePath];
        NSLog(@"==========第三步为创建播放Queue准备数据");
        /**
         *  https://developer.apple.com/reference/audiotoolbox/1576499-audio_file_properties/kaudiofilepropertymagiccookiedata
         *  通过查看文档了解到,这个是一个指向到内存中的一个指针。一些文件类型在数据包写到音频文件前需要读到这个数据。这里是做播放功能，所以这个这个数据可以不提供
         */
        macgicCookie       = [_audioFile fetchMagicCookie];
        /**
         *  这是两个关键值音频时长和音频大小
         */
        _duration          = [_audioFile duration];
        _icon              = [_audioFile artAlbum];
        format             = [_audioFile format];
        audioDataByteCount = [_audioFile audioDataByteCount];


    }else{
        
        _fileHandle = [NSFileHandle fileHandleForReadingAtPath:_filePath];
        _fileSize   = [[[NSFileManager defaultManager] attributesOfItemAtPath:_filePath error:nil] fileSize];

        
        NSError *error = nil;
#warning formattype
        _audioFileStream = [[BZAudioFileStream alloc] initWithFileType:kAudioFileMP3Type withFilePath:_filePath error:&error];
        
        macgicCookie       = [_audioFileStream fetchMagicCookie];
        _duration          = [_audioFileStream duration];
        _icon              = [_audioFileStream artAlbum];
        format             = [_audioFileStream format];
        audioDataByteCount = [_audioFileStream audioDataByteCount];
    }
    
    if (_duration != 0) {
#warning 这个地方说是获取到buffer大小，但我暂时不知道为什么要这么做
        _bufferSize = _duration * audioDataByteCount;
    }
    
    NSLog(@"==========第四步开始创建播放Queue");
    _audioQueue = [[BZAudioOutputQueue alloc] initWithFormat:format bufferSize:_bufferSize macgicCookie:macgicCookie];
    __weak __typeof(&*self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.delegate != nil && [weakSelf.delegate respondsToSelector:@selector(audioPlayInfoGetSuccess:)]) {
            [weakSelf.delegate audioPlayInfoGetSuccess:weakSelf];
        }
    });
    
    return YES;
}

#pragma mark -control
-(void)play
{
    if (!_started) {
        _status = BZAudioPlayerStatusPlaying;
        __weak __typeof(&*self)weakSelf = self;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [weakSelf threadMain];
        });
    }else{
        [self _resume];
    }
}
-(void)threadMain
{
    [self cereateAudioQueue];
    
    BOOL isEof = NO;
    NSMutableArray *bufferArray = [NSMutableArray array];
    NSLog(@"开始解析数据，拿到部分数据后就开始播放");
    while (_status && self.status != BZAudioPlayerStatusStopped) {
        /**
         *  循环解析数据,这里拿到的数据是
         */
        @autoreleasepool {
            if (!_isUseAudioFileStream) {
                if (!isEof) {
                    NSArray *parsedData = [_audioFile parseData:&isEof];
                    
                    if (parsedData) {
                        [bufferArray addObjectsFromArray:parsedData];
                        [_buffer enqueueFromDataArray:parsedData];
                        
                    }else{
                        isEof = YES;
                        NSLog(@"数据解析完成,可以播放了");
                    }
                }
            }else{
                if (!_audioFileStream.readyToProducePackets || [_buffer bufferedSize] < _bufferSize || !_audioQueue) {
                    NSData *data = [_fileHandle readDataOfLength:1000];
                    _offset += [data length];
                    if (_offset >= _fileSize) {
                        isEof = YES;
                    }
                    NSError *error = nil;
                    [_audioFileStream parseData:data error:&error];
                    if (error) {
                        continue;
                    }
                }
                
            }
            
            //stop
            if (_stopRequired) {
                _status = BZAudioPlayerStatusStopped;
                _started = NO;
                [_audioQueue stop:YES];
                _stopRequired = NO;
                break;
            }
            
            //pause
            if (_pauseRequired) {
                
                _status = BZAudioPlayerStatusPaused;
                [_audioQueue pause];
                _pauseRequired = NO;
            }
            
            
            //play
            if ([_buffer bufferedSize] > _bufferSize || isEof) {
                _status = BZAudioPlayerStatusPlaying;
                UInt32 packetCount;
                AudioStreamPacketDescription *desces = NULL;

                NSData *data = [_buffer dequeueDataWithSize:_bufferSize packetCount:&packetCount descriptions:&desces];
                if (packetCount != 0) {
                    //正常播放
                    BOOL success = [_audioQueue playData:data packetCount:packetCount packetDescriptions:desces isEof:isEof];
                    if (success) {
                        NSLog(@"成功");
                    }else{
                        NSLog(@"失败");
                    }
                }else if(isEof){
                    
//                    if (![_buffer hasData] && _audioQueue.isRunning) {
//                        //播放完成
//                        NSLog(@"没数据了");
//                        [_audioQueue stop:NO];
//                        _started = BZAudioPlayerStatusFlushing;
//                    }
//                    
                    //正在缓冲
                    if ([_buffer hasData] && _audioQueue.isRunning) {
                        NSLog(@"正在缓冲");
                        [_audioQueue stop:NO];
                        _status = BZAudioPlayerStatusFlushing;
                    }
                }else{
                    NSLog(@"播放完成了");
                    //播放完成
                    _status = BZAudioPlayerStatusStopped;
                    break;
                }
                free(desces);

            }
            
            //seek
            if (_seekRequired) {
                
            }
        }
        
    }
    [self cleanUp];
    
}
-(void)cleanUp
{
    [_buffer clean];
    if (_isUseAudioFileStream) {
        [_audioFileStream close];
        _audioFileStream = nil;
    }else{
        [_audioFile closeFile];
        _audioFile = nil;
    }
    
    [_audioQueue stop:YES];
    _audioQueue = nil;
    
    _started = NO;
    _seekRequired = NO;
    _stopRequired = NO;
    _pauseRequired = NO;
    
    _started = BZAudioPlayerStatusStopped;
    
}
-(void)pause
{
    BOOL success = [_audioQueue pause];
    NSString *status = success == YES ? @"暂停成功" : @"暂停失败";
    NSLog(@"%@",status);
    _pauseRequired = success;
}
-(void)_resume
{
    BOOL success = [_audioQueue resume];
    NSString *status = success == YES ? @"恢复成功" : @"恢复失败";
    NSLog(@"%@",status);
}
-(void)stop
{
    BOOL success = [_audioQueue reset];
    NSString *status = success == YES ? @"停止成功" : @"停止失败";
    NSLog(@"%@",status);
    _stopRequired = YES;
}
-(void)seekToProgess:(float)progress
{
    _seekTime = progress;
    [_buffer clean];
    [_audioFile seekToTime:_seekTime];
    BOOL success = [_audioQueue reset];
    if (success) {
        NSLog(@"重新启动成功");
    }else{
        NSLog(@"重新启动失败");
    }
}
#pragma mark -notify
-(void)methodForInterruption:(NSNotification *)notify
{
    NSLog(@"这里是接收到了打断的通知:%@",notify);
}
@end
