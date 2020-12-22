//
//  ViewController.m
//  ZWAuidoKit
//
//  Created by ZhengWei on 16/6/12.
//  Copyright © 2016年 Bourbon. All rights reserved.
//

#import "ViewController.h"
#import "BZAudioPlayer.h"
@interface ViewController ()<BZAudioPlayerDelegate>
{
    BOOL _started;
    BZAudioPlayer *_player;
    NSTimer *_playTimer;
    __weak IBOutlet UISlider *_playSlider;
    __weak IBOutlet UILabel *_playedLabel;
    __weak IBOutlet UILabel *_durationLabel;
    __weak IBOutlet UIImageView *icon;
    __weak IBOutlet UILabel *_title;
    __weak IBOutlet UILabel *_album;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"MP3" ofType:@"mp3"];
//    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"M4ASample" ofType:@"m4a"];
//    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"CAFSample" ofType:@"caf"];

    _player = [BZAudioPlayer sharedInstance];
    [_player setIsUseAudioFileStream:NO];
    [_player setDelegate:self];
    [_player setFilePath:filePath];

    [_durationLabel setTextAlignment:(NSTextAlignmentCenter)];
    [_playedLabel   setTextAlignment:(NSTextAlignmentCenter)];
    _playedLabel.text   = @"00:00:00";
    _durationLabel.text = @"00:00:00";
    _title.text         = @"未知歌曲";
    _album.text         = @"未知专辑";
    
    CGSize size = [_playSlider sizeThatFits:(UILayoutFittingCompressedSize)];
    NSLog(@"%@",NSStringFromCGSize(size));

}
-(void)dealloc
{
    [_playTimer invalidate];
    _playTimer = nil;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)stop:(UIButton *)sender {
    [_player stop];
    [_playTimer invalidate];
    _playTimer = nil;
}
- (IBAction)play:(UIButton *)sender {
    [_player play];
    if (!_playTimer) {
        _playTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(audioPlayerProgress:) userInfo:nil repeats:YES];
    }
}
- (IBAction)pause:(id)sender {
    [_player pause];
    [_playTimer invalidate];
    _playTimer = nil;
}
- (IBAction)progress:(UISlider *)sender {
    float progress = sender.value / _player.duration;
    [_player seekToProgess:progress];
}
-(void)audioPlayerProgress:(NSTimer *)timer
{
    NSLog(@"当前进度:%f  播放总时长：%f",_player.currentTime,_player.duration);
    _playSlider.value = _player.currentTime;
    
    _playedLabel.text = [self configText:_player.currentTime];

}
#pragma mark -delegate
-(void)audioPlayInfoGetSuccess:(BZAudioPlayer *)player
{
    _playSlider.minimumValue = 0;
    _playSlider.maximumValue = _player.duration;
    _durationLabel.text = [self configText:player.duration];
    _title.text = player.title;
    _album.text = player.album;
    icon.image = player.icon;
}
#pragma mark -method
-(NSString *)configText:(NSTimeInterval)time
{
    NSInteger tmp = [[NSString stringWithFormat:@"%.0f",time] integerValue];
    NSInteger hour = tmp /3600;
    NSInteger minute = (tmp % 3600) / 60;
    NSInteger second = (tmp % (3600 * 60)) % 60;
    
    NSString *hourStr   = hour < 10 ? [NSString stringWithFormat:@"0%ld",hour] : [NSString stringWithFormat:@"%ld",hour];
    NSString *minuteStr = minute < 10 ? [NSString stringWithFormat:@"0%ld",minute] : [NSString stringWithFormat:@"%ld",minute];
    NSString *secondStr = second < 10 ? [NSString stringWithFormat:@"0%ld",second] : [NSString stringWithFormat:@"%ld",second];
    
    return [NSString stringWithFormat:@"%@:%@:%@",hourStr,minuteStr,secondStr];
}
@end
