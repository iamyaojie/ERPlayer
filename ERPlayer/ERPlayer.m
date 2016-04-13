//
//  ERPlayer.m
//  ERPlayer
//
//  Created by 王耀杰 on 16/4/5.
//  Copyright © 2016年 Erma. All rights reserved.
//

#import "ERPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MPVolumeView.h>

#pragma mark - interface
#pragma mark -

//Resources.bundle
#define SELFWIDTH self.bounds.size.width
#define SELFHEIGHT self.bounds.size.height

#define SCREENW [UIScreen mainScreen].bounds.size.width
#define SCREENH [UIScreen mainScreen].bounds.size.height

#define MARGIN 4

//视频播放状态记录
typedef NS_ENUM(NSInteger, VideoPlayerState) {
    VideoPlayerStatePlay,
    VideoPlayerStatePause,
    VideoPlayerStateStop
};

//手指滑动状态记录
typedef NS_ENUM(NSInteger, GestureDirection){
    
    GestureDirectionHorizontalMoved, //水平划动
    GestureDirectionVerticalMoved    //垂直划动
    
};

@interface ERPlayer ()

/** 记录当前视频播放器的状态 */
@property (assign, nonatomic) VideoPlayerState currentVideoPlayerState;
/** 记录划动方向 */
@property (nonatomic, assign) GestureDirection gestureDirection;
/** 记录上一刻的time */
@property (nonatomic, assign) NSTimeInterval tempTime;
/** 记录进退时长 */
@property (nonatomic, assign) CGFloat sumTime;
/** 记录Frame */
@property (nonatomic, assign) CGRect tempFrame;
/** 记录父控制器 */
@property (nonatomic, strong) UIView *superView;

/** 是否用户操作 */
@property (assign, nonatomic) BOOL isUserOperation;
/** 是否调节音量,否则调节亮度 */
@property (nonatomic, assign) BOOL isAdjustVolume;
/** 记录是否全屏 */
@property (nonatomic, assign) BOOL isFullScreen;
/** 判断是否进入后台 */
@property (nonatomic, assign) BOOL isCallBack;

/** 计时器 */
@property (strong, nonatomic) NSTimer *timer;
/** 音量控制滑杆 */
@property (nonatomic, strong) UISlider *volumeViewSlider;

/** 顶部cover View */
@property (strong, nonatomic) UIView *topView;
/** 顶部cover View的Back ImgView */
@property (strong, nonatomic) UIImageView *topBackImgView;
/** 顶部cover X Button */
@property (strong, nonatomic) UIButton *XButton;

/** 底部cover View */
@property (strong, nonatomic) UIView *bottomView;
/** 底部cover View的Back ImgView */
@property (strong, nonatomic) UIImageView *bottomBackImgView;
/** 底部cover 播放button */
@property (strong, nonatomic) UIButton *playButton;
/** 底部cover 当前时间label */
@property (strong, nonatomic) UILabel *currentTimeLabel;
/** 底部cover 全屏button */
@property (strong, nonatomic) UIButton *FullScreenButton;
/** 底部cover 总共时间的Label */
@property (strong, nonatomic) UILabel *totalTimeLabel;
/** 底部cover 进度条 */
@property (strong, nonatomic) UISlider *progressSlider;

/** 中间提示view */
@property (strong, nonatomic) UIView *tipsView;
/** View的Back ImgView */
@property (strong, nonatomic) UIImageView *tipsBackImgView;
/** 提示label */
@property (strong, nonatomic) UILabel *tipsLabel;
/** 提示img */
@property (strong, nonatomic) UIImageView *tipsImg;

/** 播放管理者 */
@property (nonatomic, strong) AVPlayerItem *playerItem;
/** 播放器 */
@property (nonatomic, strong) AVPlayer *player;
/** playerLayer */
@property (nonatomic, strong) AVPlayerLayer *playerLayer;

@end

#pragma mark - implementation
#pragma mark -
@implementation ERPlayer

#pragma mark - 对外提供的方法
- (void)setViedoUrl:(NSURL *)videoUrl
{
    self.playerItem = [AVPlayerItem playerItemWithURL:videoUrl];
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    
    [self.layer insertSublayer:self.playerLayer atIndex:0];
    
}

- (void)setVideoLayerStyle:(ERVideoLayerStyle)videoLayerStyle {
    
    switch (videoLayerStyle) {
            
        case ERVideoTop:
            self.frame = CGRectMake(0, 20, SCREENW, self.bounds.size.height * SCREENW / self.bounds.size.width);
            self.isFullScreen = NO;
            break;
            
        case ERVideoLowerLeftCorner:
            self.frame = CGRectMake(0, SCREENH - self.bounds.size.height * (SCREENW / 3 * 2) / self.bounds.size.width - 44 - 10, SCREENW / 3 * 2, self.bounds.size.height * (SCREENW / 3 * 2) / self.bounds.size.width);
            self.isFullScreen = NO;
            break;
            
        case ERVideoLowerRightCorner:
            self.frame = CGRectMake(SCREENW / 3, SCREENH - self.bounds.size.height * (SCREENW / 3 * 2) / self.bounds.size.width - 44 - 10, SCREENW / 3 * 2, self.bounds.size.height * (SCREENW / 3 * 2) / self.bounds.size.width);
            break;
            
        case ERVideoRightUpperRightCorner:
            self.frame = CGRectMake(SCREENW / 3, 54 + 10, SCREENW / 3 * 2, self.bounds.size.height * (SCREENW / 3 * 2) / self.bounds.size.width);
            self.isFullScreen = NO;
            break;
            
        case ERVideoRightUpperLeftCorner:
            self.frame = CGRectMake(0, 54 + 10, SCREENW / 3 * 2, self.bounds.size.height * (SCREENW / 3 * 2) / self.bounds.size.width);
            self.isFullScreen = NO;
            break;
            
        default:
            break;
    }
}

#pragma mark - 私有方法

- (void)systemVolumeView {
    
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    _volumeViewSlider = nil;
    for (UIView *view in [volumeView subviews]){
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
            _volumeViewSlider = (UISlider *)view;
            break;
        }
    }
    
    NSError *setCategoryError = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&setCategoryError];
    
}

- (void)configControlAction
{
    [self.progressSlider addTarget:self action:@selector(progressSliderTouchBegan:) forControlEvents:UIControlEventTouchDown];
    [self.progressSlider addTarget:self action:@selector(progressSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.progressSlider addTarget:self action:@selector(progressSliderTouchEnded:) forControlEvents:UIControlEventTouchUpInside];
    [self.progressSlider addTarget:self action:@selector(progressSliderTouchEnded:) forControlEvents:UIControlEventTouchUpOutside];
    [self.progressSlider addTarget:self action:@selector(progressSliderTouchEnded:) forControlEvents:UIControlEventTouchCancel];
}

- (void)startTimer
{
    self.timer = [NSTimer scheduledTimerWithTimeInterval:.2f target:self selector:@selector(updateTimeOnProgressAndTimeLabel) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)stopTimer
{
    [self.timer invalidate];
}

- (void)updateTimeOnProgressAndTimeLabel {
    [self updateTimeOnProgress];
    [self updateTimeOnTimeLabel];
}

- (void)updateTimeOnTimeLabel
{
    
    NSTimeInterval currentTime = CMTimeGetSeconds(self.player.currentTime);
    self.currentTimeLabel.text = [self stringWithTime:currentTime];
    NSTimeInterval duration = CMTimeGetSeconds(self.player.currentItem.duration);
    self.totalTimeLabel.text = [self stringWithTime:duration];
    
}

- (void)updateTimeOnProgress
{
    self.progressSlider.value = CMTimeGetSeconds(self.player.currentTime) / CMTimeGetSeconds(self.player.currentItem.duration);
}

- (void)updateTipsView
{
    NSTimeInterval currentTime = CMTimeGetSeconds(self.player.currentTime);
    self.currentTimeLabel.text = [self stringWithTime:currentTime];
    NSTimeInterval duration = CMTimeGetSeconds(self.player.currentItem.duration);
    self.totalTimeLabel.text = [self stringWithTime:duration];
    
    if (currentTime > self.tempTime) {
        self.tipsImg.image = [UIImage imageNamed:@"Resources.bundle/Plus"];
    }else {
        self.tipsImg.image = [UIImage imageNamed:@"Resources.bundle/Minus"];
    }
    
    self.tipsLabel.text = [NSString stringWithFormat:@"%@ / %@", self.currentTimeLabel.text, self.totalTimeLabel.text];
}

- (void)hidenAllView
{
    if (self.isUserOperation) return;
    self.tipsView.hidden = YES;
    self.bottomView.hidden = YES;
    self.topView.hidden = YES;
}

#pragma mark - 操作进度条的事件
- (void)progressSliderTouchBegan:(UISlider *)sender
{
    [self pause];
    self.isUserOperation = YES;
    self.bottomView.hidden = NO;
    self.topView.hidden = NO;
}

- (void)progressSliderValueChanged:(UISlider *)sender
{
    
    NSTimeInterval currentTime = CMTimeGetSeconds(self.player.currentItem.duration) * self.progressSlider.value;
    // 设置当前播放时间
    [self.player seekToTime:CMTimeMakeWithSeconds(currentTime, NSEC_PER_SEC) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    
    [self updateTimeOnTimeLabel];
    
    self.tipsView.hidden = NO;
    [self updateTipsView];
    
}

- (void)progressSliderTouchEnded:(UISlider *)sender
{
    self.isUserOperation = NO;
    [self play];
    [self performSelector:@selector(hidenAllView) withObject:nil afterDelay:5];
    
}

#pragma mark - 点击button的事件
- (void)didClickButton:(UIButton *)sender
{
    
    if (sender.tag == 1) {
        if (sender.selected) {
            [self pause];
        }else {
            [self play];
        }
    }
    
    if (sender.tag == 2) {
        UIDeviceOrientation orientation             = [UIDevice currentDevice].orientation;
        UIInterfaceOrientation interfaceOrientation = (UIInterfaceOrientation)orientation;
        switch (interfaceOrientation) {
            case UIInterfaceOrientationPortrait:{
                [self interfaceOrientation:UIInterfaceOrientationLandscapeRight];
            }
                break;
            case UIInterfaceOrientationLandscapeRight:{
                [self interfaceOrientation:UIInterfaceOrientationPortrait];
            }
                break;
            default:
                break;
        }
    }
    
    if (sender.tag == 3) {
        [self removeFromSuperview];
        [self.player replaceCurrentItemWithPlayerItem:nil];
    }
}

#pragma mark - 私有工具方法

- (NSString *)stringWithTime:(NSTimeInterval)time {
    NSInteger dMin = time / 60;
    NSInteger dSec = (NSInteger)time % 60;
    return [NSString stringWithFormat:@"%02ld:%02ld", dMin, dSec];
}

- (void)play {
    [self startTimer];
    self.playButton.selected = YES;
    self.currentVideoPlayerState = VideoPlayerStatePlay;
    [self.player play];
}

- (void)pause
{
    [self stopTimer];
    self.playButton.selected = NO;
    self.currentVideoPlayerState = VideoPlayerStatePause;
    [self.player pause];
}

/**
 *  计算progressSlider的值
 */
- (void)horizontalMoved:(CGFloat)value
{
    // 每次滑动需要叠加时间
    self.sumTime += value / 200;
    
    // 需要限定sumTime的范围
    CMTime totalTime           = self.playerItem.duration;
    CGFloat totalMovieDuration = (CGFloat)totalTime.value/totalTime.timescale;
    if (self.sumTime > totalMovieDuration) {
        self.sumTime = totalMovieDuration;
    }else if (self.sumTime < 0){
        self.sumTime = 0;
    }
    self.progressSlider.value = self.sumTime / totalMovieDuration;
}

/**
 *  pan垂直移动的方法
 *
 */
- (void)verticalMoved:(CGFloat)value
{
    if (self.isAdjustVolume) {
        // 更改系统的音量
        self.volumeViewSlider.value      -= value / 10000;
    }else {
        //亮度
        [UIScreen mainScreen].brightness -= value / 10000;
        NSString *brightness             = [NSString stringWithFormat:@"亮度%.0f%%",[UIScreen mainScreen].brightness/1.0*100];
        self.tipsView.hidden      = NO;
        self.tipsLabel.text        = brightness;
        self.tipsImg.image = [UIImage imageNamed:@"Resources.bundle/Lightbulb"];
    }
    
}

#pragma mark - layoutSubviews初始化所用控件
- (void)layoutSubviews {
    
    [super layoutSubviews];
    
    self.backgroundColor = [UIColor blackColor];
    
    self.topView.frame = CGRectMake(0, 0, SELFWIDTH, 44);
    self.topBackImgView.frame = CGRectMake(0, 0, SELFWIDTH, 44);
    self.XButton.frame = CGRectMake(MARGIN * 2, MARGIN * 2, 28, 28);
    
    self.bottomView.frame = CGRectMake(0, SELFHEIGHT - 44, SELFWIDTH, 44);
    self.bottomBackImgView.frame = CGRectMake(0, 0, SELFWIDTH, 44);
    self.playButton.frame = CGRectMake(MARGIN * 2, MARGIN * 2, 28, 28);
    self.currentTimeLabel.frame = CGRectMake(44 + MARGIN, 0, 52, 44);
    self.FullScreenButton.frame = CGRectMake(SELFWIDTH - 44 + MARGIN * 2, MARGIN * 2, 28, 28);
    self.totalTimeLabel.frame = CGRectMake(SELFWIDTH - 44 - 52 - MARGIN, 0, 52, 44);
    self.progressSlider.frame = CGRectMake(44 + MARGIN + 52 + MARGIN, 0, SELFWIDTH - (44 + MARGIN + 52) - (52 + 44 + MARGIN + MARGIN), 44);
    
    self.tipsView.center = CGPointMake(SELFWIDTH / 2.0, SELFHEIGHT / 2.0);
    self.tipsView.bounds = CGRectMake(0, 0, 180, 44);
    self.tipsBackImgView.frame = self.tipsView.bounds;
    self.tipsImg.frame = CGRectMake(MARGIN * 2, MARGIN * 2, 28, 28);
    self.tipsLabel.frame = CGRectMake(44, 0, 180 - 44, 44);
    
    self.tipsView.hidden = YES;
    
    //获取系统音量
    [self systemVolumeView];
    
    // 配置action
    [self configControlAction];
    
    // 添加观察者、通知
    [self addNotification];
    
    // 添加手势
    [self createGesture];
    
    if (self.superView == nil) {
        self.superView = self.superview;
    }
    
    if (self.tempFrame.size.width == 0) {
        self.tempFrame = self.frame;
    }
    
//    self.playerLayer.frame = self.layer.bounds;
        self.playerLayer.frame = self.bounds;
}

#pragma mark - 手势方法
// 创建手势
- (void)createGesture
{
    // 创建轻拍手势
    UITapGestureRecognizer *singleTapGestureRecognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(singleTap:)];
    [singleTapGestureRecognizer setNumberOfTapsRequired:1];
    [self addGestureRecognizer:singleTapGestureRecognizer];
    
    // 滑动手势
    UIPanGestureRecognizer *gesture = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(gestureSlide:)];
    [self addGestureRecognizer:gesture];
    
}

- (void)addNotification {
    
    // 处理系设备旋转
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDeviceOrientationChange)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil
     ];
    // app退到后台
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    // app进入前台
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterPlayGround)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
}

/**
 *   轻拍
 */
- (void)singleTap:(UITapGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        self.isUserOperation = YES;
        //        self.isSingleTapHidenAll = !self.isSingleTapHidenAll;
        self.bottomView.hidden = !self.bottomView.isHidden;
        self.topView.hidden = !self.topView.isHidden;
        self.tipsView.hidden = YES;
    }
}

/**
 *  手势事件
 */
- (void)gestureSlide:(UIPanGestureRecognizer *)gesture
{
    //根据在view上Pan的位置，确定是调音量还是亮度
    CGPoint locationPoint = [gesture locationInView:self];
    
    // 根据上次和本次移动的位置，算速率
    CGPoint veloctyPoint = [gesture velocityInView:self];
    
    // 判断是垂直移动还是水平移动
    switch (gesture.state) {
            
        case UIGestureRecognizerStateBegan:{ // 开始移动
            
            // 使用绝对值来判断移动的方向
            CGFloat x = fabs(veloctyPoint.x);
            CGFloat y = fabs(veloctyPoint.y);
            
            if (x > y) { // 水平移动
                self.gestureDirection = GestureDirectionHorizontalMoved;
                [self progressSliderTouchBegan:self.progressSlider];
            }
            else if (x < y){ // 垂直移动
                self.gestureDirection = GestureDirectionVerticalMoved;
                // 开始滑动的时候,状态改为正在控制音量
                if (locationPoint.x > self.bounds.size.width / 2) {
                    self.isAdjustVolume = YES;
                }else { // 状态改为显示亮度调节
                    self.isAdjustVolume = NO;
                }
            }
            break;
        }
            
        case UIGestureRecognizerStateChanged:{ // 正在移动
            switch (self.gestureDirection) {
                case GestureDirectionHorizontalMoved:{
                    [self horizontalMoved:veloctyPoint.x]; // 水平移动的方法只要x方向的值
                    [self progressSliderValueChanged:self.progressSlider];
                    break;
                }
                case GestureDirectionVerticalMoved:{
                    [self verticalMoved:veloctyPoint.y]; // 垂直移动方法只要y方向的值
                    break;
                }
                default:
                    break;
            }
            break;
        }
            
        case UIGestureRecognizerStateEnded:{ // 移动停止
            // 移动结束也需要判断垂直或者平移
            switch (self.gestureDirection) {
                case GestureDirectionHorizontalMoved:{
                    [self progressSliderTouchEnded:self.progressSlider];
                    break;
                }
                case GestureDirectionVerticalMoved:{
                    [self performSelector:@selector(hidenAllView) withObject:nil afterDelay:5];
                    break;
                }
                default:
                    break;
            }
            break;
        }
        default:
            break;
    }
}

#pragma mark - 屏幕旋转相关

/**
 *  屏幕旋转
 */
- (void)onDeviceOrientationChange
{
    
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    UIInterfaceOrientation interfaceOrientation = (UIInterfaceOrientation)orientation;
    switch (interfaceOrientation) {
            
        case UIInterfaceOrientationPortrait:
            [self changeSmallScreen];
            break;
            
        case UIInterfaceOrientationLandscapeLeft:
            [self changeSelfFrame2FullScreen];
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            [self changeSelfFrame2FullScreen];
            break;

        default:
            break;
    }
}

/**
 *  强制屏幕转屏
 */
- (void)interfaceOrientation:(UIInterfaceOrientation)orientation
{
    if ([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
        SEL selector = NSSelectorFromString(@"setOrientation:");
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
        [invocation setSelector:selector];
        [invocation setTarget:[UIDevice currentDevice]];
        int val = orientation;
        [invocation setArgument:&val atIndex:2];
        [invocation invoke];
    }
}

- (void)changeSmallScreen {
    
    self.frame = self.tempFrame;
    self.isFullScreen = NO;
    self.FullScreenButton.selected = NO;
    [self removeFromSuperview];
    [self.superView addSubview:self];
    
}

- (void)changeSelfFrame2FullScreen {
    
    self.bounds = CGRectMake(0, 0, SCREENW, SCREENH);
    self.center = CGPointMake(SCREENW / 2, SCREENH / 2);
    self.playerLayer.bounds = CGRectMake(0, 0, SCREENW, SCREENH);
    self.playerLayer.position = CGPointMake(SCREENW / 2, SCREENH / 2);
    self.isFullScreen = YES;
    self.FullScreenButton.selected = YES;
    [self removeFromSuperview];
    [[UIApplication sharedApplication].keyWindow addSubview:self];
    
}

#pragma mark - NSNotification

/**
 *  应用退到后台
 */
- (void)appDidEnterBackground
{
    [self pause];
    self.isCallBack = YES;
}

/**
 *  应用进入前台
 */
- (void)appDidEnterPlayGround
{
    if (self.isCallBack) {
        if (self.currentVideoPlayerState == VideoPlayerStatePlay) {
            [self play];
            self.isCallBack = NO;
        }
    }
}

#pragma mark - 懒加载
- (UIView *)topView {
    if (_topView == nil) {
        _topView = [UIView new];
        [self addSubview:_topView];
    }
    return _topView;
}

- (UIImageView *)topBackImgView {
    if (_topBackImgView == nil) {
        _topBackImgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Resources.bundle/coverBg"]];
        _tipsBackImgView.alpha = .95;
        [self.topView addSubview:_topBackImgView];
    }
    return _topBackImgView;
}

- (UIButton *)XButton {
    if (_XButton == nil) {
        _XButton = [UIButton new];
        [_XButton setImage:[UIImage imageNamed:@"Resources.bundle/X"] forState:UIControlStateNormal];
        _XButton.tag = 3;
        [_XButton addTarget:self action:@selector(didClickButton:) forControlEvents:UIControlEventTouchUpInside];
        
        [self.topView addSubview:_XButton];
    }
    return _XButton;
}

- (UIView *)bottomView {
    if (_bottomView == nil) {
        _bottomView = [UIView new];
        [self addSubview:_bottomView];
    }
    return _bottomView;
}

- (UIImageView *)bottomBackImgView {
    if (_bottomBackImgView == nil) {
        _bottomBackImgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Resources.bundle/coverBg"]];
        _bottomBackImgView.alpha = .95;
        [self.bottomView addSubview:_bottomBackImgView];
    }
    return _bottomBackImgView;
}

- (UIButton *)playButton {
    if (_playButton == nil) {
        _playButton = [UIButton new];
        [_playButton setImage:[UIImage imageNamed:@"Resources.bundle/Play"] forState:UIControlStateNormal];
        [_playButton setImage:[UIImage imageNamed:@"Resources.bundle/Pause"] forState:UIControlStateSelected];
        _playButton.tag = 1;
        [_playButton addTarget:self action:@selector(didClickButton:) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomView addSubview:_playButton];
    }
    return _playButton;
}

- (UILabel *)currentTimeLabel {
    if (_currentTimeLabel == nil) {
        _currentTimeLabel = [UILabel new];
        _currentTimeLabel.text = @"00 : 00";
        _currentTimeLabel.font = [UIFont systemFontOfSize:14];
        _currentTimeLabel.textAlignment = NSTextAlignmentCenter;
        [self.bottomView addSubview:_currentTimeLabel];
    }
    return _currentTimeLabel;
}

-(UIButton *)FullScreenButton {
    if (_FullScreenButton == nil) {
        _FullScreenButton = [UIButton new];
        [_FullScreenButton setImage:[UIImage imageNamed:@"Resources.bundle/FullScreen"] forState:UIControlStateNormal];
        _FullScreenButton.tag = 2;
        [_FullScreenButton addTarget:self action:@selector(didClickButton:) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomView addSubview:_FullScreenButton];
    }
    return _FullScreenButton;
}

- (UILabel *)totalTimeLabel {
    if (_totalTimeLabel == nil) {
        _totalTimeLabel = [UILabel new];
        _totalTimeLabel.text = @"00 : 00";
        _totalTimeLabel.font = [UIFont systemFontOfSize:14];
        _totalTimeLabel.textAlignment = NSTextAlignmentCenter;
        [self.bottomView addSubview:_totalTimeLabel];
    }
    return _totalTimeLabel;
}

- (UISlider *)progressSlider {
    if (_progressSlider == nil) {
        _progressSlider = [UISlider new];
        [_progressSlider setThumbImage:[UIImage imageNamed:@"Resources.bundle/Point"] forState:UIControlStateNormal];
        [_progressSlider setMinimumTrackImage:[UIImage imageNamed:@"Resources.bundle/MinimumTrackImage"] forState:UIControlStateNormal];
        [self.bottomView addSubview:_progressSlider];
    }
    return _progressSlider;
}

- (UIView *)tipsView {
    if (_tipsView == nil) {
        _tipsView = [UIView new];
        _tipsView.layer.cornerRadius = 8;
        _tipsView.layer.masksToBounds = YES;
        [self addSubview:_tipsView];
    }
    return _tipsView;
}

-(UIImageView *)tipsBackImgView {
    if (_tipsBackImgView == nil) {
        _tipsBackImgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Resources.bundle/coverBg"]];
        _tipsBackImgView.alpha = .7;
        [self.tipsView addSubview:_tipsBackImgView];
    }
    return _tipsBackImgView;
}

- (UIImageView *)tipsImg {
    if (_tipsImg == nil) {
        _tipsImg = [UIImageView new];
        [self.tipsView addSubview:_tipsImg];
    }
    return _tipsImg;
}

- (UILabel *)tipsLabel {
    if (_tipsLabel == nil) {
        _tipsLabel = [UILabel new];
        _tipsLabel.font = [UIFont systemFontOfSize:15];
        _tipsLabel.textAlignment = NSTextAlignmentCenter;
        [self.tipsView addSubview:_tipsLabel];
    }
    return _tipsLabel;
}

@end
