//
//  ViewController.m
//  SoundRecorder
//
//  Created by 刘康蕤 on 16/6/1.
//  Copyright © 2016年 刘康蕤. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface ViewController ()<AVAudioRecorderDelegate,AVAudioPlayerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *volumeImage;
@property (weak, nonatomic) IBOutlet UIButton *listenBtn;
@property (weak, nonatomic) IBOutlet UIButton *recordBtn;

@property (nonatomic, strong) AVAudioRecorder * recorder;   ///<  录制器
@property (nonatomic, strong) AVAudioPlayer * avPlayer;     ///<  播放器

@property (nonatomic, strong) NSTimer * timer;              ///<  计时器

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _volumeImage.center = CGPointMake(CGRectGetWidth(self.view.frame)/2, 150);
    _volumeImage.image = [UIImage imageNamed:@"record_animate_00"];
    
    _listenBtn.center = CGPointMake(CGRectGetWidth(self.view.frame)/2 - 70, 350);
    _recordBtn.center = CGPointMake(CGRectGetWidth(self.view.frame)/2 + 70, 350);
    
    [self setAudioRecord];
}

/**
 *  录音设置
 */
- (void)setAudioRecord {
    // 录音设置
    NSMutableDictionary * recordSetting = [[NSMutableDictionary alloc] init];
    // 设置录音格式 AVFormatIDKey==kAudioFormatLinearPCM
    [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    // 设置录音采样频（Hz） 如：AVSampleRateKey==8000/44100/96000（影响音频的质量）
    [recordSetting setValue:[NSNumber numberWithFloat:44100] forKey:AVSampleRateKey];
    // 录音通道数  1 或 2
    [recordSetting setValue:[NSNumber numberWithInt:1] forKey:AVNumberOfChannelsKey];
    // 线性采样位数  8、16、24、32
    [recordSetting setValue:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
    // 录音的质量
    [recordSetting setValue:[NSNumber numberWithInt:AVAudioQualityHigh] forKey:AVEncoderAudioQualityKey];
    
    // 存放路径
    NSString *recordPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSURL * recordUr = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/record.acc",recordPath]];
    
    // 初始化录音器
    _recorder = [[AVAudioRecorder alloc] initWithURL:recordUr
                                            settings:recordSetting
                                               error:nil];
    _recorder.meteringEnabled = YES;
    _recorder.delegate = self;
    
}

#pragma mark   ///////    按钮点击方法    /////
- (IBAction)listenBtnAction:(id)sender {
    
    AVAudioSession * audioSeeion = [AVAudioSession sharedInstance];
    [audioSeeion setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    if ([_avPlayer isPlaying]) {
        [_avPlayer stop];
        if (_timer) {
            [_timer invalidate];
            _timer = nil;
        }
        return;
    }
    // 存放路径
    NSString *recordPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSURL * recordUr = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/record.acc",recordPath]];
    
    AVAudioPlayer * player = [[AVAudioPlayer alloc] initWithContentsOfURL:recordUr error:nil];
    player.delegate = self;
    self.avPlayer = player;
    self.avPlayer.volume=1;
    [self.avPlayer prepareToPlay];
    [self.avPlayer play];
    
    ///  设置定时检测
//    _timer = [NSTimer scheduledTimerWithTimeInterval:0 target:self
//                                            selector:@selector(playVoice) userInfo:nil
//                                             repeats:YES];
    
}

- (IBAction)recordBtnTouchDown:(id)sender {
    
    AVAudioSession * audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryRecord error:nil];
    [audioSession setActive:YES error:nil];
    
    ///  创建录音文件，准备录音
    if ([_recorder prepareToRecord]) {
        [_recorder record];
    }
    
    ///  设置定时检测
    _timer = [NSTimer scheduledTimerWithTimeInterval:0 target:self
                                            selector:@selector(recordVoice) userInfo:nil
                                             repeats:YES];
    
}

- (IBAction)recordBtnTouchUp:(id)sender {

    double ctime = _recorder.currentTime;
    [_recorder stop];
    if (ctime > 1) {
        
    }else {
        // 删除记录的文件前 必须先stop
        [_recorder deleteRecording];
        UIAlertController * alertController = [UIAlertController alertControllerWithTitle:@"提示"
                                                                                  message:@"录音时间太短"
                                                                           preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alertController animated:YES completion:nil];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alertController dismissViewControllerAnimated:YES completion:nil];
        });
    }
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
}

- (IBAction)recordBtnCancell:(id)sender {
    [_recorder stop];
    [_recorder deleteRecording];
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
}


#pragma mark  avAudioPlaydelegate 
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
    NSLog(@"播放结束");
}

// 记录声音
- (void)recordVoice {
    // 刷新音量数据
    [_recorder updateMeters];
    
    // 获取音量的平均值
//    [_recorder averagePowerForChannel:0];
    // 获取音量的最大值
//    [_recorder peakPowerForChannel:0];
    
    double lowPassResults = pow(10, 0.05 * [_recorder peakPowerForChannel:0]);
    
    [self setVolumeImageWithLowPassResult:lowPassResults];
}

// 播放声音
- (void)playVoice {
    [_avPlayer setMeteringEnabled:YES];
    // 刷新音量数据
    [_avPlayer updateMeters];

    float peak = [_avPlayer averagePowerForChannel:0];
    
    double lowPassResults = fabs((double)peak)/160.0;
    NSLog(@"peak = %f,lowPassResults = %f",peak,lowPassResults);
    [self setVolumeImageWithLowPassResult:lowPassResults];
    
}

- (void)setVolumeImageWithLowPassResult:(double)lowPassResults {
    
    if (0<lowPassResults<=0.06) {
        [self.volumeImage setImage:[UIImage imageNamed:@"record_animate_01.png"]];
    }else if (0.06<lowPassResults<=0.13) {
        [self.volumeImage setImage:[UIImage imageNamed:@"record_animate_02.png"]];
    }else if (0.13<lowPassResults<=0.20) {
        [self.volumeImage setImage:[UIImage imageNamed:@"record_animate_03.png"]];
    }else if (0.20<lowPassResults<=0.27) {
        [self.volumeImage setImage:[UIImage imageNamed:@"record_animate_04.png"]];
    }else if (0.27<lowPassResults<=0.34) {
        [self.volumeImage setImage:[UIImage imageNamed:@"record_animate_05.png"]];
    }else if (0.34<lowPassResults<=0.41) {
        [self.volumeImage setImage:[UIImage imageNamed:@"record_animate_06.png"]];
    }else if (0.41<lowPassResults<=0.48) {
        [self.volumeImage setImage:[UIImage imageNamed:@"record_animate_07.png"]];
    }else if (0.48<lowPassResults<=0.55) {
        [self.volumeImage setImage:[UIImage imageNamed:@"record_animate_08.png"]];
    }else if (0.55<lowPassResults<=0.62) {
        [self.volumeImage setImage:[UIImage imageNamed:@"record_animate_09.png"]];
    }else if (0.62<lowPassResults<=0.69) {
        [self.volumeImage setImage:[UIImage imageNamed:@"record_animate_10.png"]];
    }else if (0.69<lowPassResults<=0.76) {
        [self.volumeImage setImage:[UIImage imageNamed:@"record_animate_11.png"]];
    }else if (0.76<lowPassResults<=0.83) {
        [self.volumeImage setImage:[UIImage imageNamed:@"record_animate_12.png"]];
    }else if (0.83<lowPassResults<=0.9) {
        [self.volumeImage setImage:[UIImage imageNamed:@"record_animate_13.png"]];
    }else {
        [self.volumeImage setImage:[UIImage imageNamed:@"record_animate_14.png"]];
    }
}

@end
