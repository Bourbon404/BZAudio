//
//  BZAudioFileStream.m
//  ZWAuidoKit
//
//  Created by ZhengWei on 16/7/1.
//  Copyright © 2016年 Bourbon. All rights reserved.
//

#import "BZAudioFileStream.h"
#import "MCParsedAudioData.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#define BitRateEstimationMaxPackets 5000
#define BitRateEstimationMinPackets 10

@interface BZAudioFileStream ()
{
@private
    AudioFileStreamID _audioFileStreamID;
    
    NSTimeInterval _packetDuration;
    BOOL _discontinuous;
    /**
     *  音频文件开始的头文件大小
     */
    SInt64 _dataOffset;
    AudioStreamBasicDescription _format;
    
    UInt64 _processedPacketsCount;
    UInt64 _processedPacketsSizeTotal;
    
    CFDictionaryRef _infoDict;
}
@end
@implementation BZAudioFileStream
@synthesize  audioDataByteCount   = _audioDataByteCount;
@synthesize fileType              = _fileType;
@synthesize fileSize              = _fileSize;
@synthesize readyToProducePackets = _readyToProducePackets;
@synthesize bitRate               = _bitRate;
@synthesize duration              = _duration;
@dynamic available;
@synthesize album                 = _album;
@synthesize title                 = _title;
@synthesize artAlbum              = _artAlbum;
@synthesize format                = _format;
-(instancetype)initWithFileType:(AudioFileTypeID)fileType withFilePath:(NSString *)filePath error:(NSError **)error;
{
    if (self = [super init]) {
        
        _fileType = fileType;
        _filePath = filePath;
        NSFileManager *_fileManager = [NSFileManager defaultManager];
        BOOL success = [_fileManager fileExistsAtPath:_filePath];
        if (!success) {
            NSAssert(NULL, @"文件可能不存在");
        }
        
        NSError *error = nil;
        _fileSize = [[_fileManager attributesOfItemAtPath:_filePath error:&error] fileSize];
        if (_fileSize == 0) {
            NSAssert(_fileSize > 0, @"文件大小必须大于0");
        }

        OSStatus status = AudioFileStreamOpen((__bridge void * _Nullable)(self),
                                              BZAudioFileStreamPropertyListener,
                                              BZAudioFileStreamPacketsProc,
                                              _fileType,
                                              &_audioFileStreamID);
        NSAssert(status == noErr, @"AudioFileStream 打开失败");
    }
    return self;
}
#pragma mark -property
-(BOOL)available
{
    return _audioFileStreamID != NULL;
}
-(void)setFilePath:(NSString *)filePath
{
    _filePath = filePath;
}
#pragma mark -callback
static void BZAudioFileStreamPropertyListener(void *						inClientData,
                                              AudioFileStreamID				inAudioFileStream,
                                              AudioFileStreamPropertyID		inPropertyID,
                                              AudioFileStreamPropertyFlags *ioFlags){

    //解析数据
    BZAudioFileStream *audioFileStream = (__bridge BZAudioFileStream *)(inClientData);
    [audioFileStream handleAudioFileStreamProperty:inPropertyID];
    
}
static void BZAudioFileStreamPacketsProc(void *							inClientData,
                                         UInt32							inNumberBytes,
                                         UInt32							inNumberPackets,
                                         const void *					inInputData,
                                         AudioStreamPacketDescription	*inPacketDescriptions){
    BZAudioFileStream *audioFileStream = (__bridge BZAudioFileStream *)(inClientData);
    [audioFileStream handleAudioFileStreamPackets:inInputData
                                    numberOfBytes:inNumberBytes
                                  numberOfPackets:inNumberPackets
                               packetDescriptions:inPacketDescriptions];
}
#pragma mark -method
- (NSData *)fetchMagicCookie
{
    UInt32 cookieSize;
    Boolean writable;
    OSStatus status = AudioFileStreamGetPropertyInfo(_audioFileStreamID, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
    if (status != noErr)
    {
        return nil;
    }
    
    void *cookieData = malloc(cookieSize);
    status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
    if (status != noErr)
    {
        return nil;
    }
    
    NSData *cookie = [NSData dataWithBytes:cookieData length:cookieSize];
    free(cookieData);
    
    return cookie;
}

-(void)_closeAudioFileStream
{
    if (self.available) {
        AudioFileStreamClose(_audioFileStreamID);
        _audioFileStreamID = NULL;
    }
}
-(void)close{
    [self _closeAudioFileStream];
}
-(SInt64)seekToTime:(NSTimeInterval)time
{
    SInt64 approximateSeekOffset = _dataOffset + (time / _duration)* _audioDataByteCount;
    SInt64 seekToPacket = floor(time / _packetDuration);
    SInt64 seekByteOffset;
    UInt32 ioFlags = 0;
    SInt64 outDataByteOffset;
    OSStatus status = AudioFileStreamSeek(_audioFileStreamID, seekToPacket, &outDataByteOffset, &ioFlags);
    if (status == noErr && !(ioFlags & kAudioFileStreamSeekFlag_OffsetIsEstimated)) {
        time -= ((approximateSeekOffset - _dataOffset) - outDataByteOffset) * 8.0 / _bitRate;
        seekByteOffset = outDataByteOffset + _dataOffset;
    }else{
        _discontinuous = YES;
        seekByteOffset = approximateSeekOffset;
    }
    return seekByteOffset;
}
-(BOOL)parseData:(NSData *)data error:(NSError **)error
{
    if (self.readyToProducePackets && _packetDuration == 0) {
        return NO;
    }
    OSStatus status = AudioFileStreamParseBytes(_audioFileStreamID, (UInt32)data.length, data.bytes,_discontinuous ? kAudioFileStreamParseFlag_Discontinuity:0);
    return status == noErr;
}
-(void)handleAudioFileStreamProperty:(AudioFileStreamPropertyID)propertyID
{
    if (propertyID == kAudioFileStreamProperty_BitRate) {
        UInt32 bitRateSize = sizeof(_bitRate);
        OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, propertyID, &bitRateSize, &_bitRate);
        if (status != noErr) {
            NSLog(@"error");
        }
        
    }else if (propertyID == kAudioFileStreamProperty_DataOffset){
        UInt32 offsetSize = sizeof(_dataOffset);
        OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, propertyID, &offsetSize, &_dataOffset);
        if (status != noErr) {
            NSLog(@"error");
        }
        [self calculateDuration];

    }else if (propertyID == kAudioFileStreamProperty_DataFormat){
        UInt32 asbdSize = sizeof(_format);
        OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, propertyID, &asbdSize, &_format);
        if (status != noErr) {
            NSLog(@"error");
        }
        [self calculatePacketDuration];

    }else if (propertyID == kAudioFileStreamProperty_AudioDataByteCount){
        UInt32 byteCountSize = sizeof(_audioDataByteCount);
        OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, propertyID, &byteCountSize, &_audioDataByteCount);
        if (status != noErr) {
            NSLog(@"error");
        }
        [self calculateDuration];
        
    }else if (propertyID == kAudioFileStreamProperty_ReadyToProducePackets){
        //解析完成，下一步进行帧分离
        _readyToProducePackets = YES;
        _discontinuous = YES;
        
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(audioFileStreamReadyToProducePackets:)]) {
            [self.delegate audioFileStreamReadyToProducePackets:self];
        }
    }else if (propertyID == kAudioFileStreamProperty_InfoDictionary){
        //获取歌曲的专辑和名称
        UInt32 size = sizeof(_infoDict);
        OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, propertyID, &size, &_infoDict);
        if (status != noErr) {
            [self close];
        }
        NSDictionary *dict = (__bridge NSDictionary *)(_infoDict);
        _album = [dict objectForKey:@"album"] != nil ? [dict objectForKey:@"album"] : @"未知专辑";
        _title = [dict objectForKey:@"title"] != nil ? [dict objectForKey:@"title"] : @"未知名称";
        NSLog(@"歌曲的信息:%@",dict);
        
        AVURLAsset *avURLAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:_filePath] options:nil];
        for (NSString *format in [avURLAsset availableMetadataFormats]) {
            for (AVMetadataItem *metadataItem in [avURLAsset metadataForFormat:format]) {
                if ([metadataItem.commonKey isEqualToString:@"artwork"]) {
                    _artAlbum = [UIImage imageWithData:(NSData *)metadataItem.value];
                    break;
                }
            }
        }

    }else if (propertyID == kAudioFileStreamProperty_FileFormat){
        //文件格式
        UInt32 size = sizeof(_fileType);
        OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFilePropertyFileFormat, &size, &_fileType);
        if (status != noErr) {
            [self close];
        }
    }else if (propertyID == kAudioFileStreamProperty_FormatList){
        Boolean outWriteable;
        UInt32 formatListSize;
        OSStatus status = AudioFileStreamGetPropertyInfo(_audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatListSize, &outWriteable);
        if (status == noErr)
        {
            AudioFormatListItem *formatList = malloc(formatListSize);
            OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatListSize, formatList);
            if (status == noErr)
            {
                UInt32 supportedFormatsSize;
                status = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize);
                if (status != noErr)
                {
                    free(formatList);
                    return;
                }
                
                UInt32 supportedFormatCount = supportedFormatsSize / sizeof(OSType);
                OSType *supportedFormats = (OSType *)malloc(supportedFormatsSize);
                status = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize, supportedFormats);
                if (status != noErr)
                {
                    free(formatList);
                    free(supportedFormats);
                    return;
                }
                
                for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i += sizeof(AudioFormatListItem))
                {
                    AudioStreamBasicDescription format = formatList[i].mASBD;
                    for (UInt32 j = 0; j < supportedFormatCount; ++j)
                    {
                        if (format.mFormatID == supportedFormats[j])
                        {
                            _format = format;
                            [self calculatePacketDuration];
                            break;
                        }
                    }
                }
                free(supportedFormats);
            }
            free(formatList);
        }
    }

}
- (void)handleAudioFileStreamPackets:(const void *)packets
                       numberOfBytes:(UInt32)numberOfBytes
                     numberOfPackets:(UInt32)numberOfPackets
                  packetDescriptions:(AudioStreamPacketDescription *)packetDescriptioins
{
    if (_discontinuous) {
        _discontinuous = NO;
    }
    if (numberOfBytes || numberOfPackets == 0) {
        return;
    }
    
    BOOL deletePackDesc = NO;
    if (packetDescriptioins == NULL) {
        deletePackDesc = YES;
        UInt32 packetSize = numberOfBytes / numberOfPackets;
        AudioStreamPacketDescription *descriptons = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription)*numberOfPackets);
        
        for (int i = 0; i < numberOfPackets; i++) {
            UInt32 packetOffset = packetSize * i;
            descriptons[i].mStartOffset = packetOffset;
            
            if (i == numberOfPackets - 1) {
                descriptons[i].mDataByteSize = numberOfBytes - packetOffset;
            }else{
                descriptons[i].mDataByteSize = packetSize;
            }
        }
        packetDescriptioins = descriptons;
    }
    
    NSMutableArray *parsedDataArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < numberOfPackets; i++) {
        SInt64 packetOffset = packetDescriptioins[i].mStartOffset;
        MCParsedAudioData *parsedData = [MCParsedAudioData parsedAudioDataWithBytes:packets+packetOffset
                                                                  packetDescription:packetDescriptioins[i]];
        [parsedDataArray addObject:parsedData];
        
        if (_processedPacketsCount < BitRateEstimationMaxPackets) {
            _processedPacketsSizeTotal += parsedData.packetDescription.mDataByteSize;
            _processedPacketsCount += 1;
            [self calculateBitRate];
            [self calculateDuration];
        }
    }
    
    [self.delegate audioFileStream:self audioDataParsed:parsedDataArray];
    
    if (deletePackDesc) {
        free(packetDescriptioins);
    }
}
#pragma mark -calculate
-(void)calculatePacketDuration
{
    if (_format.mSampleRate > 0) {
        _packetDuration = _format.mFramesPerPacket / _format.mSampleRate;
    }
}
-(void)calculateDuration
{
    if (_fileSize > 0 && _bitRate > 0) {
        _duration = _audioDataByteCount * 8 / _bitRate;
    }
}
-(void)calculateBitRate
{
    if (_packetDuration && _processedPacketsCount > BitRateEstimationMinPackets && _processedPacketsCount <= BitRateEstimationMaxPackets) {
        double averagePacketByteSize = _processedPacketsSizeTotal / _processedPacketsCount;
        _bitRate = 8.0 * averagePacketByteSize / _packetDuration;
    }
}
@end
