//
//  ChatCellVideoViewModel.m
//  RongCloud
//
//  Created by LiuLinhong on 2016/12/07.
//  Copyright © 2016年 Beijing Rongcloud Network Technology Co. , Ltd. All rights reserved.
//

#import "ChatCellVideoViewModel.h"
#import "UIColor+ColorChange.h"
#import "ChatManager.h"
@interface ChatCellVideoViewModel ()
 
@property (nonatomic,assign) BOOL registerObserverFlag;
@end


@implementation ChatCellVideoViewModel

- (instancetype)initWithView:(UIView *)view
{
    self = [super init];
    if (self)
    {
        self.cellVideoView = view;
        self.streamID = @"";
        self.userID = @"";
        self.originalSize = CGSizeZero;
        self.frameRateRecv = 0;
        self.frameWidthRecv = 0;
        self.frameHeightRecv = 0;
        self.audioVideoType = 1;
        self.videoType = 1;
        self.isCloseMicphone = NO;
        self.isCloseCamera = NO;
        self.registerObserverFlag = YES;
        self.avatarView = [[ChatAvatarView alloc] init];
        self.isUnpublish = NO;
        
        [self initLableView];
    }
    
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.streamID = @"";
        self.userID = @"";
        self.originalSize = CGSizeZero;
        self.frameRateRecv = 0;
        self.frameWidthRecv = 0;
        self.frameHeightRecv = 0;
        self.audioVideoType = 1;
        self.videoType = 1;
        self.isCloseMicphone = NO;
        self.isCloseCamera = NO;
        self.registerObserverFlag = YES;
        self.avatarView = [[ChatAvatarView alloc] init];
        self.isUnpublish = NO;
        
        [self initLableView];
    }
    
    return self;
}

- (void)dealloc
{
    [self.cellVideoView removeFromSuperview];
    self.cellVideoView = nil;
    [self.inputStream setVideoRender:nil];
    self.inputStream = nil;
    [self removeKeyPathObservers];
}

- (UIWebView *)audioLevelView
{
    if (!_audioLevelView) {
        _audioLevelView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 16, 16)];
        NSString *path = [[NSBundle mainBundle] pathForResource:@"sound" ofType:@"gif"];
        NSURL *url = [NSURL URLWithString:path];
        [_audioLevelView loadRequest:[NSURLRequest requestWithURL:url]];
        _audioLevelView.backgroundColor = [UIColor clearColor];
        _audioLevelView.opaque = NO;
        _audioLevelView.scalesPageToFit = YES;
        [self.infoLabel addSubview:_audioLevelView];
    }
    return _audioLevelView;
}

- (void)initLableView
{
    CGFloat offset = 16;
    if ([UIApplication sharedApplication].statusBarFrame.size.height == 44 &&
        self.cellVideoView.frame.size.height == ScreenHeight) {
        offset += 78;
    }
    
    CGRect frame = CGRectMake(13, self.cellVideoView.frame.size.height-offset, self.cellVideoView.frame.size.width - 26, 16);
    if ([self.cellVideoView isKindOfClass:[RongRTCRemoteVideoView class]]) {
        frame = CGRectMake(0, self.cellVideoView.frame.size.height - offset, self.cellVideoView.frame.size.width, 16);
    }
    self.infoLabel = [[UILabel alloc] initWithFrame:frame];
    self.infoLabel.textAlignment = NSTextAlignmentLeft;
    self.infoLabel.font = [UIFont systemFontOfSize:12];
    self.infoLabel.backgroundColor = [UIColor clearColor]; //[UIColor colorWithRed:0 green:0 blue:0 alpha:0.15];
    self.infoLabel.textColor = [UIColor whiteColor];
    self.infoLabel.text = self.userName;
    
    self.infoLabelGradLayer = [CAGradientLayer layer];
    self.infoLabelGradLayer.frame = self.infoLabel.frame;
    self.infoLabelGradLayer.hidden = YES;
    [self.infoLabelGradLayer setColors:@[(id)[UIColor colorWithRed:1 green:0 blue:0 alpha:0.3].CGColor, (id)[UIColor clearColor].CGColor]];
//    [self.cellVideoView.layer addSublayer:self.infoLabelGradLayer];
    [self.infoLabelGradLayer setStartPoint:CGPointMake(0, 1)];
    [self.infoLabelGradLayer setEndPoint:CGPointMake(0, 0)];
    
 #ifdef DEBUG
//    if (self.cellVideoView.frame.size.width < ScreenWidth)
//        [self.cellVideoView addSubview:self.infoLabel];
#endif
    if (self.registerObserverFlag)
    {
        [self addObserver:self forKeyPath:@"audioLevel" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
        [self addObserver:self forKeyPath:@"bitRate" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
        self.registerObserverFlag = YES;
    }
}

- (void)removeKeyPathObservers
{
    if (self.registerObserverFlag)
    {
        [self removeObserver:self forKeyPath:@"audioLevel"];
        [self removeObserver:self forKeyPath:@"bitRate"];
        self.registerObserverFlag = NO;
    }
}


-(void)setInputStream:(RongRTCAVInputStream *)inputStream{
    _inputStream = inputStream;
    if ([_inputStream.tag hasPrefix:@"RongRTCFileVideo"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *name = kChatManager.videoOwner;
            if (name.length >= 4) {
                name = [name substringToIndex:4];
            }
            self.infoLabel.text = [name stringByAppendingString:@"-视频文件"];
            self.infoLabel.textAlignment = NSTextAlignmentCenter;
        });
    }
}

- (void)setUserName:(NSString *)userName {
    _userName = [userName copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *name = userName;
        if (name.length >= 4) {
            name = [name substringToIndex:4];
        }
        if (name) {
            if ([self.inputStream.tag hasPrefix:@"RongRTCFileVideo"] || [self.infoLabel.text containsString:@"-视频文件"]) {
                self.infoLabel.text = [name stringByAppendingString:@"-视频文件"];
            }
            else{
                self.infoLabel.text = name;
            }
        }
    });

}

- (void)setCellVideoView:(UIView *)cellVideoView
{
    _cellVideoView = cellVideoView;
//    [self.infoLabel removeFromSuperview];
//#ifdef DEBUG
//    if (self.cellVideoView.frame.size.width < ScreenWidth)
//        [self.cellVideoView addSubview:self.infoLabel];
//#endif
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"audioLevel"]) {
        if (self.audioLevel == 0)
        {
            self.audioLevelView.hidden = YES;
            return;
        }
        else {
            self.audioLevelView.hidden = NO;
        }
        
        self.audioLevelView.frame = CGRectMake(self.infoLabel.frame.size.width-16, 0, self.infoLabel.frame.size.height, self.infoLabel.frame.size.height);
        [self.infoLabel bringSubviewToFront:self.audioLevelView];
    }
    else if ([keyPath isEqualToString:@"bitRate"]) {
        NSInteger newBitRate = [change[@"new"] integerValue];
        if (!newBitRate) {
            self.infoLabel.textColor = [UIColor redColor];
        }
        else {
            self.infoLabel.textColor = [UIColor whiteColor];
        }
    }
}

@end
