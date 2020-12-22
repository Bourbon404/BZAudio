//
//  BZAudioFile.m
//  ZWAuidoKit
//
//  Created by ZhengWei on 16/6/28.
//  Copyright © 2016年 Bourbon. All rights reserved.
//

#import "BZAudioFile.h"
#import "MCParsedAudioData.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
static const UInt32 packetPerRead = 15;


@interface BZAudioFile ()
{
@private
    AudioFileID _fileID;
    NSString *_filePath;
    AudioFileTypeID _fileType;
    
    SInt64 _fileSize;
    NSFileHandle *_fileHandle;
    NSFileManager *_fileManager;
    
    UInt32 _maxPacketSize;
    
    SInt64 _packetOffset;
    
    SInt64 _dataOffset;
    
    CFDictionaryRef _infoDict;
    CFDataRef _dataRef;
}
@end
@implementation BZAudioFile
@synthesize fileSize = _fileSize;
@synthesize audioDataByteCount = _audioDataByteCount;
@synthesize duration = _duration;
@synthesize bitRate = _bitRate;
@synthesize album = _album;
@synthesize title = _title;
@synthesize artAlbum = _artAlbum;
-(instancetype)initWithFilePath:(NSString *)filePath
{
    if (self = [super init]) {
        _filePath = filePath;
        
        _fileHandle = [NSFileHandle fileHandleForReadingAtPath:_filePath];
        
        _fileManager = [NSFileManager defaultManager];
        BOOL success = [_fileManager fileExistsAtPath:_filePath];
        if (!success) {
            NSAssert(NULL, @"文件可能不存在");
        }
        
        NSError *error = nil;
        _fileSize = [[_fileManager attributesOfItemAtPath:_filePath error:&error] fileSize];
        if (_fileSize == 0) {
            NSAssert(_fileSize > 0, @"文件大小必须大于0");
        }
        
        NSLog(@"==========第一步打开文件");
        [self _openFile];
        NSLog(@"==========第二部查询文件信息");
        [self _fetchFormatInfo];
    
    }
    return self;
}
#pragma mark -method
-(void)_openFile{
    OSStatus status = AudioFileOpenWithCallbacks((__bridge void * _Nonnull)(self),
                                                 AudioFileReadCallBack,
                                                 NULL,
                                                 AudioFileGetSizeCallBack,
                                                 NULL,
                                                 _fileType,
                                                 &_fileID);
    if (status != noErr) {
        NSLog(@"打开文件时失败:%d",(int)status);
    }
}
-(void)_fetchFormatInfo
{
    UInt32 formatListSize;
    //获取歌曲的属性时需要注意的是 ** 当其中的属性会产生变化的时候，需要先用 AudioFileGetPropertyInfo 检测一次
    OSStatus status = AudioFileGetPropertyInfo(_fileID, kAudioFilePropertyFormatList, &formatListSize, NULL);
    if (status == noErr)
    {
        BOOL found = NO;
        //获取格式信息
        AudioFormatListItem *formatList = (AudioFormatListItem *)malloc(formatListSize);
        OSStatus status = AudioFileGetProperty(_fileID, kAudioFilePropertyFormatList, &formatListSize, formatList);
        if (status == noErr)
        {
            UInt32 supportedFormatsSize;
            status = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize);
            if (status != noErr)
            {
                free(formatList);
                [self closeFile];
                return;
            }
            
            UInt32 supportedFormatCount = supportedFormatsSize / sizeof(OSType);
            OSType *supportedFormats = (OSType *)malloc(supportedFormatsSize);
            status = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize, supportedFormats);
            if (status != noErr)
            {
                free(formatList);
                free(supportedFormats);
                [self closeFile];
                return;
            }
            
            for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i++)
            {
                AudioStreamBasicDescription format = formatList[i].mASBD;
                for (UInt32 j = 0; j < supportedFormatCount; ++j)
                {
                    if (format.mFormatID == supportedFormats[j])
                    {
                        _format = format;
                        found = YES;
                        break;
                    }
                }
            }
            free(supportedFormats);
        }
        free(formatList);
        
        if (!found)
        {
            [self closeFile];
            return;
        }
        else
        {
//            [self _calculatepPacketDuration];
        }
    }
    
    //每一个包的数据大小
    UInt32 size = sizeof(_maxPacketSize);
    status = AudioFileGetProperty(_fileID, kAudioFilePropertyPacketSizeUpperBound, &size, &_maxPacketSize);
    if (status != noErr || _maxPacketSize == 0)
    {
        status = AudioFileGetProperty(_fileID, kAudioFilePropertyMaximumPacketSize, &size, &_maxPacketSize);
        if (status != noErr)
        {
            [self closeFile];
            return;
        }
    }
    
    /**
     *  kAudioFilePropertyDataOffset 这个值是用来获取文件中的音频数据开始在哪，因为每一个音频文件的前面是文件信息，后面才是音频数据
     *
     *  @param _dataOffset 音频数据开始的位置
     *
     *  @return 音频数据开始的位置,也可以理解为文件信息数据的大小
     */
    size = sizeof(_dataOffset);
    status = AudioFileGetProperty(_fileID, kAudioFilePropertyDataOffset, &size, &_dataOffset);
    if (status != noErr)
    {
        [self closeFile];
        return;
    }
    //音频数据的大小
    _audioDataByteCount = _fileSize - _dataOffset;
    
    //码率
    size = sizeof(_bitRate);
    status = AudioFileGetProperty(_fileID, kAudioFilePropertyBitRate, &size, &_bitRate);
    if (status != noErr)
    {
        [self closeFile];
        return;
    }
    //音频时长
    size = sizeof(_duration);
    status = AudioFileGetProperty(_fileID, kAudioFilePropertyEstimatedDuration, &size, &_duration);
    if (status != noErr) {
        //当上面的方法获取时长失败的时候，可以用这个方法获取
        /**
         *  因为平均码率:大可理解为文件大小除以播放时间，并且audioDataByteCount是音频数据大小，且是一个8位的数据
            所以可以通过下面的方式，来得到播放时间.
            日，写个这玩意还能补充一下基本概念
         */
        if (_fileSize > 0 && _bitRate > 0) {
            _duration = (_audioDataByteCount * 8) / _bitRate;
        }
    }

    
    //获取歌曲的专辑和名称
    size = sizeof(_infoDict);
    status = AudioFileGetProperty(_fileID, kAudioFilePropertyInfoDictionary, &size, &_infoDict);
    if (status != noErr) {
        [self closeFile];
        return;
    }
    NSDictionary *dict = (__bridge NSDictionary *)(_infoDict);
    _album = [dict objectForKey:@"album"] != nil ? [dict objectForKey:@"album"] : @"未知专辑";
    _title = [dict objectForKey:@"title"] != nil ? [dict objectForKey:@"title"] : @"未知名称";
    NSLog(@"歌曲的信息:%@",dict);
    
    //文件格式
    size = sizeof(_fileType);
    status = AudioFileGetProperty(_fileID, kAudioFilePropertyFileFormat, &size, &_fileType);
    if (status != noErr) {
        [self closeFile];
        return;
    }
    
    AVURLAsset *avURLAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:_filePath] options:nil];
    for (NSString *format in [avURLAsset availableMetadataFormats]) {
        for (AVMetadataItem *metadataItem in [avURLAsset metadataForFormat:format]) {
            if ([metadataItem.commonKey isEqualToString:@"artwork"]) {
                _artAlbum = [UIImage imageWithData:(NSData *)metadataItem.value];
                break;
            }
        }
    }
    NSLog(@"文件格式:%u",(unsigned int)_fileType);
    
    
}
#pragma mark -Callback
static OSStatus AudioFileReadCallBack(void   *inClientData,
                                      SInt64  inPosition,
                                      UInt32  requestCount,
                                      void   *buffer,
                                      UInt32 *actualCount){
    
    BZAudioFile *file = (__bridge BZAudioFile *)inClientData;
    *actualCount = [file availableDataLengthAtOffset:inPosition maxLength:requestCount];
    if (*actualCount > 0) {
        NSData *data = [file dataAtOffset:inPosition length:*actualCount];
        memcpy(buffer, data.bytes, data.length);
    }
    return noErr;
}
static SInt64 AudioFileGetSizeCallBack(void *inClientData){
    BZAudioFile *file = (__bridge BZAudioFile *)inClientData;
    return file.fileSize;
}
#pragma mark -检验数据有效性
-(NSData *)dataAtOffset:(SInt64)inPosition length:(UInt32)length
{
    [_fileHandle seekToFileOffset:inPosition];
    return [_fileHandle readDataOfLength:length];
}
-(UInt32)availableDataLengthAtOffset:(SInt64)inPosition maxLength:(UInt32)requestCount
{
    if ((inPosition + requestCount) > _fileSize) {
        if (inPosition > _fileSize) {
            return 0;
        }else{
            return (UInt32)(_fileSize - inPosition);
        }
    }else{
        return requestCount;
    }
}
-(NSArray *)parseData:(BOOL *)isEof{
    
    UInt32 ioNumPackets = packetPerRead;
    UInt32 ioNUmBytes = ioNumPackets * _maxPacketSize;
    void * outBuffer = (void *)malloc(ioNUmBytes);
    
    AudioStreamPacketDescription *outPacketDescriptions = NULL;
    OSStatus status = noErr;
    
    UInt32 descSize = sizeof(AudioStreamPacketDescription) * ioNumPackets;
    outPacketDescriptions = (AudioStreamPacketDescription *)malloc(descSize);
    status = AudioFileReadPacketData(_fileID, false, &ioNUmBytes, outPacketDescriptions, _packetOffset, &ioNumPackets, outBuffer);
    
    if (status != noErr) {
        *isEof = status == kAudioFileEndOfFileError;
        free(outBuffer);
        return nil; 
    }
    
    if (ioNUmBytes == 0) {
        *isEof = YES;
    }
    
    _packetOffset += ioNumPackets;
    
    
    if (ioNumPackets > 0)
    {
        NSMutableArray *parsedDataArray = [[NSMutableArray alloc] init];
        for (int i = 0; i < ioNumPackets; ++i)
        {
            AudioStreamPacketDescription packetDescription;
            if (outPacketDescriptions)
            {
                packetDescription = outPacketDescriptions[i];
            }
            else
            {
                packetDescription.mStartOffset = i * _format.mBytesPerPacket;
                packetDescription.mDataByteSize = _format.mBytesPerPacket;
                packetDescription.mVariableFramesInPacket = _format.mFramesPerPacket;
            }
            
            MCParsedAudioData *parsedData = [MCParsedAudioData parsedAudioDataWithBytes:outBuffer + packetDescription.mStartOffset
                                                                      packetDescription:packetDescription];
            if (parsedData)
            {
                [parsedDataArray addObject:parsedData];
            }
        }
        return parsedDataArray;
    }
    
    return nil;
}
-(void)closeFile{
    OSStatus status = AudioFileClose(_fileID);
    if (status != noErr) {
        NSLog(@"关闭文件的时候失败le ");
    }
}

- (NSData *)fetchMagicCookie
{
    UInt32 cookieSize;
    OSStatus status = AudioFileGetPropertyInfo(_fileID, kAudioFilePropertyMagicCookieData, &cookieSize, NULL);
    if (status != noErr)
    {
        return nil;
    }
    
    void *cookieData = malloc(cookieSize);
    status = AudioFileGetProperty(_fileID, kAudioFilePropertyMagicCookieData, &cookieSize, cookieData);
    if (status != noErr)
    {
        return nil;
    }
    
    NSData *cookie = [NSData dataWithBytes:cookieData length:cookieSize];
    free(cookieData);
    
    return cookie;
}
-(void)seekToTime:(float)progress
{
    double seekTime = _duration * progress;
    SInt64 approximateSeekOffset = _dataOffset + (seekTime / _duration) * _audioDataByteCount;
    _packetOffset = approximateSeekOffset;
}
@end
