//
//  ChatViewController.h
//  RongCloud
//
//  Created by LiuLinhong on 2016/11/15.
//  Copyright © 2016年 Beijing Rongcloud Network Technology Co. , Ltd. All rights reserved.
//

#import "ChatViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "SettingViewController.h"
#import "CommonUtility.h"
#import "LoginViewController.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import "SealRTCAppDelegate.h"
#import "UICollectionView+RongRTCBgView.h"
#import <RongIMLib/RongIMLib.h>
#import "STParticipantsTableViewController.h"
#import "STPresentationViewController.h"
#import "STParticipantsInfo.h"
#import "STSetRoomInfoMessage.h"
#import "STDeleteRoomInfoMessage.h"
#import "STKickOffInfoMessage.h"
#import "RTActiveWheel.h"
#import "RongRTCFileCapturer.h"
#import "RTHttpNetworkWorker.h"
#import "RongAudioVolumeControl.h"
#import <ReplayKit/ReplayKit.h>
@interface ChatViewController () <UINavigationControllerDelegate,UIAlertViewDelegate,RongRTCFileCapturerDelegate,RCConnectionStatusChangeDelegate,RongAudioVolumeControlDelegate>

{
    CGFloat localVideoWidth, localVideoHeight;
    UIButton *silienceButton;
    BOOL isShowButton, isChatCloseCamera;
    NSTimeInterval showButtonSconds;
    NSTimeInterval defaultButtonShowTime;
    CADisplayLink *displayLink;
    RongRTCFileCapturer *fileCapturer;
    RongRTCAVOutputStream *videoOutputStream;
    BOOL isStartPublishAudio;
    BOOL isShowController;
    BOOL isShowVolumeControl;
}

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *mainVieTopMargin;
@property (nonatomic, strong) JSContext *jsContext;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *collectionViewTopMargin;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *collectionViewLeadingMargin;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *collectionViewTrailingMargin;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *collectionViewHeightConstraint;
@property (nonatomic, weak) IBOutlet UIView *statuView;
@property (nonatomic, strong) IBOutlet UICollectionViewLayout *collectionViewLayout;
@property (nonatomic, strong) NSMutableArray<STParticipantsInfo*>* dataSource;
@property (nonatomic, strong) RongRTCLocalVideoView *localFileVideoView;
@property (weak, nonatomic) IBOutlet UILabel *connectingLabel;
@property (nonatomic, strong) UIButton *audioControl;
@property (nonatomic, strong) RongAudioVolumeControl *controller;
@property (nonatomic, strong) UIButton *audioBubbleButton;
@property (nonatomic, strong) STParticipantsTableViewController *participantsTableViewController;
@end

@implementation ChatViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.videoMuteForUids = [NSMutableDictionary dictionary];
    self.alertTypeArray = [NSMutableArray array];
    self.videoHeight = ScreenWidth * 640.0 / 480.0;
    self.blankHeight = (ScreenHeight - self.videoHeight)/2;
    self.isFinishLeave = YES;
    self.isLandscapeLeft = NO;
    self.isNotLeaveMeAlone = NO;
    isChatCloseCamera = kLoginManager.isCloseCamera;
    isShowButton = YES;
    showButtonSconds = 0;
    defaultButtonShowTime = 6;
    self.titleLabel.text = [NSString stringWithFormat:@"%@：%@",NSLocalizedString(@"chat_room", nil), kLoginManager.roomNumber];
    self.dataTrafficLabel.hidden = YES;
    
    //remote video collection view
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    self.chatCollectionViewDataSourceDelegateImpl = [[ChatCollectionViewDataSourceDelegateImpl alloc] initWithViewController:self];
    self.collectionView.dataSource = self.chatCollectionViewDataSourceDelegateImpl;
    self.collectionView.delegate = self.chatCollectionViewDataSourceDelegateImpl;
    self.collectionView.tag = 202;
    self.collectionView.chatVC = self;
    self.collectionViewLayout = self.collectionView.collectionViewLayout;
    self.collectionView.alwaysBounceHorizontal = YES;
    self.collectionView.frame = (CGRect){0,60,screenSize.width,120};
    if (@available(iOS 11.0, *)) {
        if (UIApplication.sharedApplication.keyWindow.safeAreaInsets.bottom > 0.0) {
            self.collectionView.frame = (CGRect){0,94,screenSize.width,120};
        }
    }
    self.chatViewBuilder = [[ChatViewBuilder alloc] initWithViewController:self];
    self.chatRongRTCRoomDelegateImpl = [[ChatRongRTCRoomDelegateImpl alloc] initWithViewController:self];
    self.chatRongRTCNetworkMonitorDelegateImpl = [[ChatRongRTCNetworkMonitorDelegateImpl alloc] initWithViewController:self];
    
    #ifdef IS_PRIVATE_ENVIRONMENT
        if (kLoginManager.isPrivateEnvironment) {
            if (kLoginManager.privateMediaServer && kLoginManager.privateMediaServer.length > 0) {
                NSLog(@"private mediaserver : %@",kLoginManager.privateMediaServer);
                [[RongRTCEngine sharedEngine] setMediaServerUrl:kLoginManager.privateMediaServer];
            } else {
                [[RongRTCEngine sharedEngine] setMediaServerUrl:@""];
            }
        }
    #endif
    
    [RongRTCEngine sharedEngine].monitorDelegate  = self.chatRongRTCNetworkMonitorDelegateImpl;
    
    [self.speakerControlButton setEnabled:NO];
    [self selectSpeakerButtons:NO];

    [self addObserver];
    
    self.localView = [[RongRTCLocalVideoView alloc] initWithFrame:CGRectMake(0, 0, ScreenWidth, ScreenHeight)];
    self.localView.frameAnimated = NO;
    self.localView.fillMode = RongRTCVideoFillModeAspect;
    [self.videoMainView addSubview:self.localView];
    
    [[RongRTCAVCapturer sharedInstance] setVideoRender:self.localView];
    [kChatManager configParameter];
    self.chatGPUImageHandler = [[ChatGPUImageHandler alloc] init];
    
    __weak typeof(self) weakSelf = self;
    
    if (kLoginManager.isGPUFilter || kLoginManager.isWaterMark) {
        [RongRTCAVCapturer sharedInstance].videoSendBufferCallback = ^CMSampleBufferRef _Nullable(BOOL valid, CMSampleBufferRef  _Nullable sampleBuffer) {
            CMSampleBufferRef processedSampleBuffer = [weakSelf.chatGPUImageHandler onGPUFilterSource:sampleBuffer];
            return processedSampleBuffer;
        };
    }
    else {
        [RongRTCAVCapturer sharedInstance].videoDisplayBufferCallback = nil;
        [RongRTCAVCapturer sharedInstance].videoSendBufferCallback = nil;
    }

    kChatManager.localUserDataModel = nil;
    kChatManager.localUserDataModel = [[ChatCellVideoViewModel alloc] initWithView:self.localView];
    kChatManager.localUserDataModel.streamID = kLoginManager.userID;
    kChatManager.localUserDataModel.userID = kLoginManager.userID;
    kChatManager.localUserDataModel.isShowVideo = !isChatCloseCamera;
    kChatManager.localUserDataModel.userName = NSLocalizedString(@"me", nil);
    kChatManager.localUserDataModel.originalSize = CGSizeMake(localVideoWidth, localVideoHeight);
    [kChatManager.localUserDataModel.cellVideoView addSubview:kChatManager.localUserDataModel.infoLabel];
    
    self.localFileVideoView = [[RongRTCLocalVideoView alloc] initWithFrame:CGRectMake(0, 0, 90, 120)];
    self.localFileVideoView.fillMode = RongRTCVideoFillModeAspect;
    self.localFileVideoView.frameAnimated = NO;
    kChatManager.localFileVideoModel = nil;
    kChatManager.localFileVideoModel = [[ChatCellVideoViewModel alloc] initWithView:self.localFileVideoView];
    
    NSString *fileStreamId = [kChatManager.userID stringByAppendingString:@"RongRTCFileVideo"];
    if (!fileStreamId) {
        fileStreamId = @"RongRTCFileVideo";
    }
    kChatManager.localFileVideoModel.streamID = fileStreamId;
    kChatManager.localFileVideoModel.userID = kLoginManager.userID;
    kChatManager.localFileVideoModel.userName = @"我的视频文件";
    [kChatManager.localFileVideoModel.cellVideoView addSubview:kChatManager.localFileVideoModel.infoLabel];
    kChatManager.localFileVideoModel.isShowVideo = YES;
    
    [[RCIMClient sharedRCIMClient] setRCConnectionStatusChangeDelegate:self];
    
    RongAudioVolumeControl *control = [[RongAudioVolumeControl alloc]initWithFrame:CGRectMake(0, 0, 170, 90)];
    control.delegate = self;
    control.center = CGPointMake(self.view.frame.size.width/2, 250);
    control.layer.masksToBounds = YES;
    control.layer.cornerRadius = 5.f;
    control.hidden = YES;
    [self.view addSubview:control];
    
    self.controller = control;
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0.f, 0.f, 36.f, 36.f);
    [button addTarget:self action:@selector(audioControlButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [button setImage:[UIImage imageNamed:@"chat_av_audio_adjust_gray"] forState:UIControlStateNormal];
    [button setImage:[UIImage imageNamed:@"chat_av_audio_adjust"] forState:UIControlStateSelected];
    self.audioControl = button;
    self.audioControl.hidden = YES;
    [self.view addSubview:self.audioControl];
}

-(void)audioControlButtonClick:(UIButton *)button{
    button.selected = !button.selected;
    self.controller.hidden = !button.selected;
    isShowController = !self.controller.hidden;
}

-(void)volumeValueChanged:(NSInteger)value{
    [RongRTCAudioMixerEngine sharedEngine].volume = value/10.0;
}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;

    _deviceOrientaionBefore = UIDeviceOrientationPortrait;
    
    self.isHiddenStatusBar = NO;
    [self dismissButtons:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
#ifdef IS_LIVE
[self joinLiveChannel];
#else
[self joinChannel];
#endif

    
    
    if ([self isHeadsetPluggedIn])
        [self reloadSpeakerRoute:NO];
}

- (void)addObserver
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioRouteChange:) name:AVAudioSessionRouteChangeNotification object:nil];
}

- (void)handleAudioRouteChange:(NSNotification*)notification
{
    NSInteger reason = [[[notification userInfo] objectForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    AVAudioSessionRouteDescription *route = [AVAudioSession sharedInstance].currentRoute;
    AVAudioSessionPortDescription *port = route.outputs.firstObject;
    switch (reason)
    {
        case AVAudioSessionRouteChangeReasonUnknown:
            break;
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable : //1
            [self reloadSpeakerRoute:NO];
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable : //2
            [self reloadSpeakerRoute:YES];
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange : //3
            break;
        case AVAudioSessionRouteChangeReasonOverride : //4
        {
            if ([port.portType isEqualToString:AVAudioSessionPortBuiltInReceiver] || [port.portType isEqualToString: AVAudioSessionPortBuiltInSpeaker]){
                [self reloadSpeakerRoute:YES];
            }
            else{
                [self reloadSpeakerRoute:NO];
            }
        }
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep : //6
            break;
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory : //7
            break;
        case AVAudioSessionRouteChangeReasonRouteConfigurationChange : //8
            break;
        default:
            break;
    }
}

- (void)dealloc
{
    self.collectionView = nil;
    self.participantsTableViewController = nil;
    _chatWhiteBoardHandler = nil;
    [self.localView removeFromSuperview];
    self.localView = nil;
    [self.localFileVideoView removeFromSuperview];
    self.localFileVideoView = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reloadSpeakerRoute:(BOOL)enable
{
    dispatch_async(dispatch_get_main_queue(), ^{
        kLoginManager.isSpeaker = enable;
        [self switchButtonBackgroundColor:kLoginManager.isSpeaker button:self.chatViewBuilder.speakerOnOffButton];
        
        if (enable)
            [CommonUtility setButtonImage:self.chatViewBuilder.speakerOnOffButton imageName:@"chat_speaker_on"];
        else
            [CommonUtility setButtonImage:self.chatViewBuilder.speakerOnOffButton imageName:@"chat_speaker_off"];
    });

}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = NO;
    [displayLink invalidate];
    displayLink = nil;
    self.collectionView.chatVC = nil;
    
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
    
    _chatCollectionViewDataSourceDelegateImpl = nil;
    _chatViewBuilder = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    self.videoMainView.subviews.firstObject.frame = (CGRect){0,0,size.width,size.height};
    CGFloat menuWidth = self.chatViewBuilder.upMenuView.frame.size.width;
    CGFloat menuHeight = self.chatViewBuilder.upMenuView.frame.size.height;
    self.chatViewBuilder.upMenuView.frame = (CGRect){size.width - menuWidth - 16,(size.height - menuHeight)/2,menuWidth,menuHeight};
    self.chatViewBuilder.hungUpButton.center = CGPointMake(size.width / 2, size.height - 44);
    self.chatViewBuilder.openCameraButton.center = CGPointMake(size.width / 2 - ButtonDistance - 44/2, size.height - 44);
    self.chatViewBuilder.microphoneOnOffButton.center = CGPointMake(size.width/2 + ButtonDistance+44/2, size.height - 44);
    CGFloat height = self.collectionView.frame.size.height;
    self.collectionView.frame = (CGRect){0,0,height,size.height};
 
    
    if (self.chatViewBuilder.excelView.hidden) {
        self.chatViewBuilder.excelView.frame = (CGRect){-size.width,0,size.width,size.height};
    } else {
        self.chatViewBuilder.excelView.frame = (CGRect){0,0,size.width,size.height};
    }
    self.chatViewBuilder.excelView.excelView.frame = (CGRect){16,0,size.width-32,size.height};
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
       UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
        if (UIInterfaceOrientationPortrait == orientation) {
            [RongRTCAVCapturer sharedInstance].videoOrientation =  AVCaptureVideoOrientationPortrait;
        } else if (UIInterfaceOrientationLandscapeLeft == orientation) {
            CGFloat x = self.chatViewBuilder.upMenuView.frame.origin.x - 44;
            CGFloat y = self.chatViewBuilder.upMenuView.frame.origin.y;
            self.chatViewBuilder.upMenuView.frame = (CGRect){x,y,menuWidth,menuHeight};
            [RongRTCAVCapturer sharedInstance].videoOrientation =  AVCaptureVideoOrientationLandscapeLeft;
        } else if(UIInterfaceOrientationLandscapeRight == orientation) {
            [RongRTCAVCapturer sharedInstance].videoOrientation =  AVCaptureVideoOrientationLandscapeRight;
        } else if (UIInterfaceOrientationPortraitUpsideDown == orientation) {
            [RongRTCAVCapturer sharedInstance].videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
        }

        CGFloat offset = 16;
        CGFloat leftOffset = 0;
        CGFloat topOffset = 0;
        if (@available(iOS 11.0, *)) {
            if (UIApplication.sharedApplication.keyWindow.safeAreaInsets.bottom > 0.0) {
                topOffset = 34;
                offset += UIInterfaceOrientationIsLandscape(orientation) ? 34 : 78;
                if (orientation == UIInterfaceOrientationLandscapeRight) {
                   leftOffset = 44;
                } else if (orientation == UIInterfaceOrientationLandscapeLeft) {
                    leftOffset = 34;
                }
            }
        }
        
        if (self.selectionModel) {
            self.selectionModel.infoLabel.frame = (CGRect){13,size.height-offset,size.width-16,16};
            self.selectionModel.infoLabelGradLayer.frame = (CGRect){0,size.height-offset,size.width,16};
            self.selectionModel.avatarView.frame = (CGRect){0,0,size.width,size.height};
        } else {
            kChatManager.localUserDataModel.infoLabel.frame  = (CGRect){13,size.height-offset,size.width-16,16};
            kChatManager.localUserDataModel.infoLabelGradLayer.frame = (CGRect){0,size.height-offset,size.width,16};
            kChatManager.localUserDataModel.avatarView.frame = (CGRect){0,0,size.width,size.height};
        }
        
        UICollectionViewFlowLayout* layout = (UICollectionViewFlowLayout*)self.collectionView.collectionViewLayout;
        if (UIInterfaceOrientationIsLandscape(orientation)) {
            self.collectionView.frame = (CGRect){leftOffset,0,90,size.height};
            layout.scrollDirection = UICollectionViewScrollDirectionVertical;
            self.collectionView.alwaysBounceVertical = YES;
            self.collectionView.alwaysBounceHorizontal = NO;
        } else {
            self.collectionView.frame = (CGRect){0,60 + topOffset,size.width,120};
            layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
            self.collectionView.alwaysBounceHorizontal = YES;
            self.collectionView.alwaysBounceVertical = NO;
        }
        
        if (self->_chatWhiteBoardHandler) {
            [self->_chatWhiteBoardHandler rotateWhiteBoardView];
        }
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        if (kLoginManager.isWaterMark) {
            BOOL isTrans = size.width > size.height;
            [self.chatGPUImageHandler transformWaterMark:isTrans];
        }
    }];
    
    CGPoint point = [self.audioBubbleButton convertPoint:self.audioBubbleButton.frame.origin toView:self.view];
    self.audioControl.frame = CGRectMake(point.x - 45, point.y, self.audioControl.frame.size.width, self.audioControl.frame.size.height);
    self.controller.center = CGPointMake(size.width/2, point.y + 60);
    
}

#pragma mark - status bar
- (BOOL)prefersStatusBarHidden
{
    return _isHiddenStatusBar;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)setIsHiddenStatusBar:(BOOL)isHiddenStatusBar
{
    _isHiddenStatusBar = isHiddenStatusBar;
    NSInteger version = [[[UIDevice currentDevice] systemVersion] integerValue];
    if (version == 11) {
        if (isHiddenStatusBar && ![self isiPhoneX]) {
            _mainVieTopMargin.constant = 20.0;
            [self setNeedsStatusBarAppearanceUpdate];
        }else if (![self isiPhoneX]) {
            _mainVieTopMargin.constant = 0.0;
            [self setNeedsStatusBarAppearanceUpdate];
        }
    }else{
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

- (BOOL)isiPhoneX
{
    if ([[CommonUtility getdeviceName] isEqualToString:@"iPhone X"]) {
        return YES;
    }
    return NO;
}

#pragma mark - config UI
- (void)dismissButtons:(BOOL)flag
{
    if (isShowButton) {
        displayLink.paused = NO;
    }
}

- (void)showButtons:(BOOL)flag
{
    isShowButton = !flag;
    
    self.chatViewBuilder.upMenuView.hidden = flag;
    self.chatViewBuilder.hungUpButton.hidden = flag;
    self.dataTrafficLabel.hidden = YES;
    self.talkTimeLabel.hidden = flag;
    self.titleLabel.hidden = flag;
    self.chatViewBuilder.openCameraButton.hidden = flag;
    self.chatViewBuilder.microphoneOnOffButton.hidden = flag;
    
    if (!isShowButton) {
        if (_deviceOrientaionBefore == UIDeviceOrientationPortrait) {
            _collectionViewTopMargin.constant = -40;
        }
    }else{
        if (_deviceOrientaionBefore == UIDeviceOrientationPortrait) {
            _collectionViewTopMargin.constant = 0;
        }
    }
    self.isHiddenStatusBar = flag;
    if (flag) {
        self.audioControl.hidden = YES;
        self.controller.hidden = YES;
    }
    else{
        if (isShowController) {
            self.controller.hidden = NO;
        }
        if (isShowVolumeControl) {
            self.audioControl.hidden = NO;
        }
    }
    
}

#pragma mark - touch event
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    showButtonSconds = 0;
    [self showButtons:isShowButton];
    if (isShowButton) {
        displayLink.paused = NO;
    }
}

#pragma mark - CollectionViewTouchesDelegate
- (void)didTouchedBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event withBlock:(void (^)(void))block
{
    UITouch *touch = [touches anyObject];
    if (CGRectContainsPoint(self.collectionView.frame, [touch locationInView:self.collectionView]))
    {
        CGPoint point = [touch locationInView:self.collectionView];
        NSInteger count = [kChatManager countOfRemoteUserDataArray];
        if (count * 60 < ScreenWidth && point.x > count * 60)
        {
            showButtonSconds = 0;
            [self showButtons:isShowButton];
            if (isShowButton)
                displayLink.paused = NO;
            
            return;
        }
    }
    
    block();
}

#pragma mark - join channel
- (void)joinLiveChannel {
    [[RCIMClient sharedRCIMClient] registerMessageType:STSetRoomInfoMessage.class];
    [[RCIMClient sharedRCIMClient] registerMessageType:STDeleteRoomInfoMessage.class];
    [[RCIMClient sharedRCIMClient] registerMessageType:RongWhiteBoardMessage.class];

    if (!kLoginManager.isHost) {
        [[RongRTCAVCapturer sharedInstance] useSpeaker:YES];
        [[RongRTCEngine sharedEngine] subscribeLiveAVStream:kLoginManager.liveUrl liveType:RongRTCLiveTypeAudioVideo handler:^(RongRTCCode desc, RongRTCLiveAVInputStream * _Nullable inputStream) {
                if (inputStream.streamType == RTCMediaTypeVideo) {
                 
                    RongRTCRemoteVideoView *view = [[RongRTCRemoteVideoView alloc] initWithFrame:self.localView.bounds];
                    [self.localView addSubview:view];
                    view.fillMode = RongRTCVideoFillModeAspect;
//                    view.backgroundColor = [UIColor redColor];
                    [inputStream setVideoRender:view];
       
                }
       
            }];
            return;
    }

//    [[RongRTCEngine sharedEngine] setMediaServerUrl:kLoginManager.mediaServerURL];
    RongRTCRoomConfig *config = [[RongRTCRoomConfig alloc] init];
    config.roomType = RongRTCRoomTypeLive;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"audio"]) {
        config.liveType = RongRTCLiveTypeAudio;
    }
    [[RCIMClient sharedRCIMClient] registerMessageType:STKickOffInfoMessage.class];
    if (ENABLE_MANUAL_MEDIASERVER) [[RongRTCEngine sharedEngine] setMediaServerUrl:kLoginManager.mediaServerURL];
    [[RongRTCEngine sharedEngine] joinRoom:kLoginManager.roomNumber config:config completion:^(RongRTCRoom * _Nullable room, RongRTCCode code) {
       
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showAlertLabelWithString:NSLocalizedString(@"chat_wait_attendees", nil)];
            self.room = room;
            self.joinRoomCode = code;
            if (kLoginManager.isObserver) {
                self.chatMode = AVChatModeObserver;
                [self joinChannelImpl];
            }
            else if (room.remoteUsers.count >= MAX_NORMAL_PERSONS && room.remoteUsers.count < MAX_AUDIO_PERSONS) {
                NSString * msg = [NSString stringWithFormat:@"会议室中视频通话人数已超过 %d 人，你将以音频模式加入会议室。",MAX_NORMAL_PERSONS];
                UIAlertView *al = [[UIAlertView alloc]initWithTitle:nil message:msg delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
                al.tag = 1110;
                [al show];
            }
            else if (room.remoteUsers.count >= MAX_AUDIO_PERSONS){
                NSString * msg = [NSString stringWithFormat:@"会议室中人数已超过 %d 人，你将以旁听者模式加入会议室。",MAX_AUDIO_PERSONS];
                UIAlertView *al = [[UIAlertView alloc]initWithTitle:nil message:msg delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
                al.tag = 1111;
                [al show];
            }
            else if(room) {
                self.chatMode = AVChatModeNormal;
                if (kLoginManager.isCloseCamera) {
                    self.chatMode = AVChatModeAudio;
                }
                [self joinChannelImpl];
            } else {
                [self showAlertLabelWithString:NSLocalizedString(@"chat_wait_attendees", nil)];
            }
        });
    }];
}
- (void)joinChannel {
    [[RCIMClient sharedRCIMClient] registerMessageType:STSetRoomInfoMessage.class];
    [[RCIMClient sharedRCIMClient] registerMessageType:STDeleteRoomInfoMessage.class];
    [[RCIMClient sharedRCIMClient] registerMessageType:RongWhiteBoardMessage.class];
    [[RCIMClient sharedRCIMClient] registerMessageType:STKickOffInfoMessage.class];
    if (ENABLE_MANUAL_MEDIASERVER) [[RongRTCEngine sharedEngine] setMediaServerUrl:kLoginManager.mediaServerURL];
    [[RongRTCEngine sharedEngine] joinRoom:kLoginManager.roomNumber completion:^(RongRTCRoom * _Nullable room, RongRTCCode code) {
        if (code != RongRTCCodeSuccess) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *alertTitle = [NSString stringWithFormat:@"加入房间失败: %zd",code];
                if (code == RongRTCCodeServerBlockUser) {
                    alertTitle = NSLocalizedString(@"chat_join_kicked_by_server", nil);
                }
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:alertTitle message:nil preferredStyle:(UIAlertControllerStyleAlert)];
                UIAlertAction *action = [UIAlertAction actionWithTitle:NSLocalizedString(@"chat_alert_btn_confirm", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [self didClickHungUpButton];
                }];
                [alert addAction:action];
                [self presentViewController:alert animated:YES completion:^{}];
            });
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showAlertLabelWithString:NSLocalizedString(@"chat_wait_attendees", nil)];
            self.room = room;
            self.joinRoomCode = code;
            if (kLoginManager.isObserver) {
                self.chatMode = AVChatModeObserver;
                [self joinChannelImpl];
            }
            else if (room.remoteUsers.count >= MAX_NORMAL_PERSONS && room.remoteUsers.count < MAX_AUDIO_PERSONS) {
                NSString * msg = [NSString stringWithFormat:@"会议室中视频通话人数已超过 %d 人，你将以音频模式加入会议室。",MAX_NORMAL_PERSONS];
                UIAlertView *al = [[UIAlertView alloc]initWithTitle:nil message:msg delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
                al.tag = 1110;
                [al show];
            }
            else if (room.remoteUsers.count >= MAX_AUDIO_PERSONS){
                NSString * msg = [NSString stringWithFormat:@"会议室中人数已超过 %d 人，你将以旁听者模式加入会议室。",MAX_AUDIO_PERSONS];
                UIAlertView *al = [[UIAlertView alloc]initWithTitle:nil message:msg delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
                al.tag = 1111;
                [al show];
            }
            else if(room) {
                self.chatMode = AVChatModeNormal;
                if (kLoginManager.isCloseCamera) {
                    self.chatMode = AVChatModeAudio;
                }
                [self joinChannelImpl];
            } else {
                [self showAlertLabelWithString:NSLocalizedString(@"chat_wait_attendees", nil)];
            }
        });
    }];
}

- (void)joinChannelImpl
{
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    self.chatRongRTCRoomDelegateImpl.infos = self.dataSource;
    self.room.delegate = self.chatRongRTCRoomDelegateImpl;
    
    kLoginManager.isMaster = [self.room.remoteUsers count] ? NO : YES;
    NSInteger master = kLoginManager.isMaster ? 1 : 0;
    long long timestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    STParticipantsInfo* info  = [[STParticipantsInfo alloc] initWithDictionary:@{@"userId":[RCIMClient sharedRCIMClient].currentUserInfo.userId,
                                                                                 @"userName":kLoginManager.username,
                                                                                 @"joinMode":@(self.chatMode),
                                                                                 @"joinTime":@(timestamp),
                                                                                 @"master":@(master)
    }];
    STSetRoomInfoMessage* message = [[STSetRoomInfoMessage alloc] initWithInfo:info forKey:[RCIMClient sharedRCIMClient].currentUserInfo.userId];
    [self.room setRoomAttributeValue:[info toJsonString] forKey:[RCIMClient sharedRCIMClient].currentUserInfo.userId message:message completion:^(BOOL isSuccess, RongRTCCode desc) {
        [self.room getRoomAttributes:nil completion:^(BOOL isSuccess, RongRTCCode desc, NSDictionary * _Nullable attr) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [attr enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                    if ([key isEqualToString:kWhiteBoardMessageKey]) {
                        NSString *whiteboardJson = attr[kWhiteBoardMessageKey];
                        if (whiteboardJson) {
                            NSDictionary* dicInfo = [NSJSONSerialization JSONObjectWithData:[whiteboardJson dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                            NSArray *keys = [dicInfo allKeys];
                            if ([keys containsObject:kWhiteBoardUUID]) {
                                self.chatWhiteBoardHandler.roomUuid = dicInfo[kWhiteBoardUUID];
                            }
                            if ([keys containsObject:kWhiteBoardRoomToken]) {
                                self.chatWhiteBoardHandler.roomToken = dicInfo[kWhiteBoardRoomToken];
                            }
                        }
                    }
                    else{
                        NSDictionary* dicInfo = [NSJSONSerialization JSONObjectWithData:[obj dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                        STParticipantsInfo* info = [[STParticipantsInfo alloc] initWithDictionary:dicInfo];
                        [self.dataSource addObject:info];
                        [kChatManager setRemoteModelUsername:info.userName userId:info.userId];
                    }
                }];
            });
        }];
    }];
    
    [[RongRTCAVCapturer sharedInstance] setCaptureParam:kChatManager.captureParam];
    FwLogD(RC_Type_APP,@"A-joinChannelImpl-T",@"joinChannelImpl chatMode %@",@(self.chatMode));
    if (self.chatMode == AVChatModeObserver || self.chatMode == AVChatModeAudio) {
        kChatManager.captureParam.turnOnCamera = NO;
        if (self.chatMode == AVChatModeAudio) {
            [[RongRTCAVCapturer sharedInstance] setCameraDisable:YES];
        }
        self.chatViewBuilder.openCameraButton.enabled = NO;
        self.chatViewBuilder.switchCameraButton.enabled = NO;
        if (self.chatMode == AVChatModeObserver) {
            self.chatViewBuilder.microphoneOnOffButton.enabled = NO;
            self.chatViewBuilder.customVideoButton.enabled = NO;
            self.chatViewBuilder.customAudioButton.enabled = NO;
            self.localView.hidden = YES;
        }
        else if (self.chatMode == AVChatModeAudio) {
            isChatCloseCamera = YES;
        }
        [[RongRTCAVCapturer sharedInstance] useSpeaker:YES];
    }
    else{
        [[RongRTCAVCapturer sharedInstance] startCapture];
    }
    
    if (isChatCloseCamera)
    {
        [self switchButtonBackgroundColor:isChatCloseCamera button:self.chatViewBuilder.openCameraButton];
        [CommonUtility setButtonImage:self.chatViewBuilder.openCameraButton imageName:@"chat_close_camera"];
        self.chatViewBuilder.switchCameraButton.enabled = NO;
        
        kChatManager.localUserDataModel.avatarView.frame = self.localView.frame;
        [kChatManager.localUserDataModel.cellVideoView addSubview:kChatManager.localUserDataModel.avatarView];
    }
    
    RongRTCCode code = self.joinRoomCode;
    FwLogD(RC_Type_APP,@"A-appReceiveUserJoin-T",@"joinRoom  %@",@(code));
    if (code == RongRTCCodeSuccess ) {
        DLog(@"joinRoom code Success");
        if (self.chatMode == AVChatModeAudio || self.chatMode == AVChatModeNormal) {
#ifdef IS_LIVE
            [self publishLiveLocalResource];
#else
            [self publishLocalResource];
            
#endif
            
        }
        if (self.room.remoteUsers.count > 0) {
            NSMutableArray *arr = [NSMutableArray array];
            for (RongRTCRemoteUser *user in self.room.remoteUsers) {
                for (RongRTCAVInputStream *stream in user.remoteAVStreams) {
                    [arr addObject:stream];
                }
            }
            FwLogD(RC_Type_APP,@"A-appReceiveUserJoin-T",@"joinRoom success hideAlertLabel YES");
            [self hideAlertLabel:YES];
            [self startTalkTimer];
            
            
            [self subscribeRemoteResource:arr];
        }
        else {
            DLog(@"joinRoom room.remoteUsers.count < 0");
        }
    }
    else {
        DLog(@"joinRoom code Failed, code: %zd", code);
    }
}

- (void)didLeaveRoom {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"chat_kicked_by_server", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:NSLocalizedString(@"chat_alert_btn_confirm", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self didClickHungUpButton];
        }];
        [alert addAction:action];
        [self presentViewController:alert animated:YES completion:^{}];
    });
}

- (void)publishLocalResource {
    DLog(@"start publishLocalResource");
    [self.room publishDefaultAVStream:^(BOOL isSuccess,RongRTCCode desc) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (isSuccess) {
                DLog(@"publishLocalResource Success");
            }
            else {
                DLog(@"publishLocalResource Failed,  Desc: %@", @(desc));
            }
        });
    }];
}
- (void)publishLiveLocalResource {
    DLog(@"start publishLocalResource");
    [self.room publishDefaultLiveAVStream:^(BOOL isSuccess, RongRTCCode desc, RongRTCLiveInfo * _Nullable liveInfo) {
        RongRTCRoom *room = self.room;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (isSuccess) {
                DLog(@"publishLocalResource Success");
            }
            else {
                DLog(@"publishLocalResource Failed,  Desc: %@", @(desc));
            }
            
        });
        if (isSuccess) {
             [[RTHttpNetworkWorker shareInstance] publish:self.room.roomId roomName:@"sunchengxiuzuishuai" liveUrl:liveInfo.liveUrl completion:^(BOOL success) {
                 
                
                 
                              DLog(@"主播发布资源%@",@(success));
                       dispatch_async(dispatch_get_main_queue(), ^{
                           UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"主播" message:[NSString stringWithFormat:@"当前主播发布资源%@",success?@"成功":@"失败"] preferredStyle:(UIAlertControllerStyleAlert)];
                           UIAlertAction *action = [UIAlertAction actionWithTitle:@"浪去吧" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                               
                           }];
                           [controller addAction:action];
                           [self presentViewController:controller animated:YES completion:^{
                               
                           }];
                       });
                      }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"主播" message:[NSString stringWithFormat:@"主播发布音视频资源失败"] preferredStyle:(UIAlertControllerStyleAlert)];
                UIAlertAction *action = [UIAlertAction actionWithTitle:@"下播吧" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    
                }];
                [controller addAction:action];
                [self presentViewController:controller animated:YES completion:^{
                    
                }];
            });
        }
       
       
    }];
}
// 自动化使用
- (void)receivePublishMessage {
}

- (void)subscribeRemoteResource:(NSArray<RongRTCAVInputStream *> *)streams
{
    NSMutableArray *subscribes = [NSMutableArray new];
    for (RongRTCAVInputStream *stream in streams) {
        NSString *streamID = stream.streamId;
        [subscribes addObject:stream];
        
        for (STParticipantsInfo* info in self.dataSource) {
            if ([stream.tag containsString:@"RongRTCFileVideo"] && [info.userId isEqualToString:stream.userId]) {
                kChatManager.videoOwner = info.userName;
                break;
            }
        }
        DLog(@"Subscribe streamID: %@   mediaType: %zd", stream.streamId, stream.streamType);

        ChatCellVideoViewModel *model = [kChatManager getRemoteUserDataModelFromStreamID:streamID];
        if (stream.streamType == RTCMediaTypeVideo) {
            if (![kChatManager isContainRemoteUserFromStreamID:streamID] || model.cellVideoView == nil) {
                RongRTCRemoteVideoView *view = [[RongRTCRemoteVideoView alloc] initWithFrame:CGRectMake(0, 0, 90, 120)];
                view.fillMode = RongRTCVideoFillModeAspect;
                view.frameAnimated = NO;
                [stream setVideoRender:view];
                
                ChatCellVideoViewModel *chatCellVideoViewModel = [[ChatCellVideoViewModel alloc] initWithView:view];
                chatCellVideoViewModel.streamID = streamID;
                chatCellVideoViewModel.userID = stream.userId;
                chatCellVideoViewModel.everOnLocalView = 0;
                chatCellVideoViewModel.inputStream = stream;
                switch (stream.state) {
                    case RongRTCInputStreamStateForbidden:
                        chatCellVideoViewModel.isShowVideo = NO;
                        break;
                    case RongRTCInputStreamStateNormal:
                        chatCellVideoViewModel.isShowVideo = YES;
                        break;
                    default:
                        break;
                }
                [kChatManager addRemoteUserDataModel:chatCellVideoViewModel];
                DLog(@"Subscribe remote user count: %zd", [kChatManager countOfRemoteUserDataArray]);
                [chatCellVideoViewModel.cellVideoView addSubview:chatCellVideoViewModel.infoLabel];
                
                if (!chatCellVideoViewModel.isShowVideo) {
                    chatCellVideoViewModel.avatarView.frame = view.frame;
                    [chatCellVideoViewModel.cellVideoView addSubview:chatCellVideoViewModel.avatarView];
                }
                
                NSInteger row = [kChatManager countOfRemoteUserDataArray]-1;
                NSIndexPath *tempPath = [NSIndexPath indexPathForRow:row inSection:0];
                [self.collectionView insertItemsAtIndexPaths:@[tempPath]];
                FwLogD(RC_Type_APP,@"A-appSetRender-T",@"%@appSetRender dont contanin user",@"sealRTCApp:");
            }
            else {
                FwLogD(RC_Type_APP,@"A-appSetRender-T",@"%@appSetRender and contain render",@"sealRTCApp:");
                ChatCellVideoViewModel *model = [kChatManager getRemoteUserDataModelFromStreamID:streamID];
                [stream setVideoRender:(RongRTCRemoteVideoView *)model.cellVideoView];
            }
        }
    }
    
    for (RongRTCAVInputStream *stream in streams) {
        if (![kChatManager isContainRemoteUserFromUserID:stream.userId] &&
            stream.streamType == RTCMediaTypeAudio) {
            
            RongRTCRemoteVideoView *view = [[RongRTCRemoteVideoView alloc] initWithFrame:CGRectMake(0, 0, 90, 120)];
            view.fillMode = RongRTCVideoFillModeAspect;
            view.frameAnimated = NO;
            
            ChatCellVideoViewModel *chatCellVideoViewModel = [[ChatCellVideoViewModel alloc] initWithView:view];
            chatCellVideoViewModel.streamID = stream.streamId;
            chatCellVideoViewModel.userID = stream.userId;
            chatCellVideoViewModel.everOnLocalView = 0;
            chatCellVideoViewModel.isShowVideo = NO;
            chatCellVideoViewModel.inputStream = stream;
            if (!chatCellVideoViewModel.isShowVideo) {
                chatCellVideoViewModel.avatarView.frame = view.frame;
                [chatCellVideoViewModel.cellVideoView addSubview:chatCellVideoViewModel.avatarView];
            }
            [view addSubview:chatCellVideoViewModel.infoLabel];
            [kChatManager addRemoteUserDataModel:chatCellVideoViewModel];
            NSInteger row = [kChatManager countOfRemoteUserDataArray]-1;
            NSIndexPath *tempPath = [NSIndexPath indexPathForRow:row inSection:0];
            [self.collectionView insertItemsAtIndexPaths:@[tempPath]];
        }
    }

    for (STParticipantsInfo* info in self.dataSource) {
        ChatCellVideoViewModel *model = [kChatManager getRemoteUserDataModelFromUserID:info.userId];
        if (info.userName) {
            model.userName = info.userName;
        }
    }
    
    DLog(@"start subscribeRemoteResource");
    FwLogD(RC_Type_APP,@"A-appSubscribeStream-T",@"%@app to  subscribe streams count : %ld",@"sealRTCApp:",subscribes.count);
    if (subscribes.count > 0) {
        FwLogD(RC_Type_APP,@"A-appSubscribeStream-T",@"%@all subscribe streams",@"sealRTCApp:");
        [self.room subscribeAVStream:nil tinyStreams:subscribes completion:^(BOOL isSuccess, RongRTCCode desc) {
            for (RongRTCAVInputStream *inStream in subscribes) {
                if (inStream.streamType != RTCMediaTypeVideo) {
                    continue;
                }
                if (isSuccess) {
                    FwLogD(RC_Type_APP,@"A-appSubscribeStream-T",@"%@all subscribe streams success",@"sealRTCApp:");
                    DLog(@"subscribeAVStream Success");
                }
                else {
                    FwLogD(RC_Type_APP,@"A-appSubscribeStream-T",@"%@all subscribe streams error",@"sealRTCApp:");
                    DLog(@"subscribeAVStream Failed, Desc: %@", @(desc));
                }
            }
        }];
    }
}

- (void)didConnectToUser:(NSString *)userId {
    FwLogD(RC_Type_APP,@"A-appConnectToStream-T",@"%@appConnectTostream collectionview to render",@"sealRTCApp:");
}

- (void)unsubscribeRemoteResource:(NSArray<RongRTCAVInputStream *> *)streams
{
    for (RongRTCAVInputStream *stream in streams) {
        DLog(@"Unsubscribe streamID: %@   mediaType: %zd", stream.streamId, stream.streamType);
    }
    
    [self.room unsubscribeAVStream:streams completion:^(BOOL isSuccess,RongRTCCode desc) {
    }];
}

#pragma mark - alertView delegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (alertView.tag == 9999) {
        if (buttonIndex > 0) {
            self.chatViewBuilder.upMenuView.buttons[1].enabled = NO;
            [self startPublishVideoFile:buttonIndex];
        }
        else{
            self.chatViewBuilder.upMenuView.buttons[1].enabled = YES;
            self.chatViewBuilder.upMenuView.buttons[1].selected = NO;
        }
    }
    else{
        if (buttonIndex == 1) {
            // 用户点击确定
            AVChatMode mode = AVChatModeAudio;
            if (alertView.tag == 1111) {
                mode = AVChatModeObserver;
            }
            self.chatMode = mode;
            [self joinChannelImpl];
        }
        else{
            [[RongRTCEngine sharedEngine] leaveRoom:kLoginManager.roomNumber completion:^(BOOL isSuccess, RongRTCCode code) {}];
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
}

#pragma mark - show alert label
- (void)showAlertLabelWithString:(NSString *)text
{
    self.alertLabel.hidden = NO;
    self.alertLabel.text = text;
}

- (void)showAlertLabelWithAnimate:(NSString *)text
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.chatViewBuilder.masterLabel.hidden = NO;
        self.chatViewBuilder.masterLabel.alpha = 1;
        self.chatViewBuilder.masterLabel.text = text;
        
        [UIView animateWithDuration:3.0 animations:^{
            self.chatViewBuilder.masterLabel.alpha = 0;
        } completion:^(BOOL finished){
        }];
    });
}

#pragma mark - hide alert label
- (void)hideAlertLabel:(BOOL)isHidden
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.alertLabel.hidden = isHidden;
    });
}

#pragma mark - update Time/Traffic by timer
- (void)updateTalkTimeLabel
{
    self.duration++;
    NSUInteger hour = self.duration / 3600;
    NSUInteger minutes = (self.duration - 3600 * hour) / 60;
    NSUInteger seconds = (self.duration - 3600 * hour - 60 * minutes) % 60;
    
    if (hour > 0)
        self.talkTimeLabel.text = [NSString stringWithFormat:@"%01ld:%02ld:%02ld", (unsigned long)hour, (unsigned long)minutes, (unsigned long)seconds];
    else
        self.talkTimeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld", (unsigned long)minutes, (unsigned long)seconds];
}

- (void)startTalkTimer
{
    if (self.duration == 0 && !self.durationTimer)
    {
        self.talkTimeLabel.text = @"00:00";
        self.durationTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateTalkTimeLabel) userInfo:nil repeats:YES];
    }
}

#pragma mark - click memu item button
- (void)menuItemButtonPressed:(UIButton *)sender
{
    UIButton *button = (UIButton *)sender;
    NSInteger tag = button.tag;
    
    switch (tag)
    {
        case -1:{
            
            if (self.chatViewBuilder.upMenuView.buttons[1].selected) {
                [RTActiveWheel showPromptHUDAddedTo:self.view text:@"请先关闭视频文件"];
                return;
            }
            self.audioBubbleButton = sender;
            sender.selected = !sender.selected;
            if (sender.selected) {
                NSString *path = [[NSBundle mainBundle] pathForResource:@"my_homeland" ofType:@"aac"];
                [[RongRTCAudioMixerEngine sharedEngine] mix:path action:RTCAudioActionMixAndPlay loop:YES];
                [[RongRTCAudioMixerEngine sharedEngine] start];
                
                CGPoint point = [sender convertPoint:sender.frame.origin toView:self.view];
                self.audioControl.frame = CGRectMake(point.x - 45, point.y, self.audioControl.frame.size.width, self.audioControl.frame.size.height);
                self.audioControl.hidden = NO;
                self.controller.center = CGPointMake(self.view.frame.size.width/2, point.y + 60);
                isShowController = NO;
                isShowVolumeControl = YES;
            }
            else{
                [[RongRTCAudioMixerEngine sharedEngine] stop];
                self.audioControl.hidden = YES;
                self.controller.hidden = YES;
                self.audioControl.selected = NO;
                isShowController = NO;
                isShowVolumeControl = NO;
            }
        }
            break;
        case 0:
            {
                isShowController = NO;
                isShowVolumeControl = NO;
                self.chatViewBuilder.upMenuView.buttons[0].selected = NO;
                [[RongRTCAudioMixerEngine sharedEngine] stop];
                sender.selected = !sender.selected;
                if (sender.selected) {
                    for (RongRTCRemoteUser *remoteUser in self.room.remoteUsers) {
                        for (RongRTCAVInputStream *stream in remoteUser.remoteAVStreams) {
                            if (stream.streamType == RTCMediaTypeVideo) {
                                if ([stream.tag hasPrefix:@"RongRTCFileVideo"]) {
                                    [RTActiveWheel showPromptHUDAddedTo:self.view text:@"房间中已有人发布视频文件"];
                                    sender.selected = NO;
                                    return;
                                }
                            }
                        }
                    }
                    sender.enabled = NO;
                    UIAlertView *al = [[UIAlertView alloc]initWithTitle:@"选择视频文件" message:nil delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"视频文件 1",@"视频文件 2", nil];
                    al.tag = 9999;
                    [al show];
                    self.audioControl.selected = NO;
                    self.audioControl.hidden = YES;
                    self.controller.hidden = YES;
                }
                else{
                    [fileCapturer stopCapture];
                    fileCapturer = nil;
                    sender.enabled = NO;
                    NSString *streamID = kChatManager.localFileVideoModel.streamID;
                    if ([kChatManager isContainRemoteUserFromStreamID:streamID])
                    {
                        RongRTCLocalVideoView *localVideoRender = (RongRTCLocalVideoView *)kChatManager.localFileVideoModel.cellVideoView;
                        if (localVideoRender) {
                            [localVideoRender flushVideoView];
                        }
                        NSInteger index = [kChatManager indexOfRemoteUserDataArray:streamID];
                        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                        if (kLoginManager.isSwitchCamera
                            && [self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.streamID isEqualToString:streamID])
                        {
                            [self.chatCollectionViewDataSourceDelegateImpl collectionView:self.collectionView didSelectItemAtIndexPath:indexPath];
                        }
                        [kChatManager removeRemoteUserDataModelFromStreamID:streamID];
                        FwLogD(RC_Type_APP,@"A-appReceiveUserLeave-T",@"%@appReceiveUserLeave and remove user",@"sealRTCApp:");
                        [self.collectionView deleteItemsAtIndexPaths:@[indexPath]];
                        if (self.orignalRow > 0) self.orignalRow--;
                    }
                    
                    [self.room unpublishAVStream:videoOutputStream extra:@"" completion:^(BOOL isSuccess, RongRTCCode desc) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            sender.enabled = YES;
                        });
                    }];
                    videoOutputStream = nil;
                    isStartPublishAudio = NO;
                }
            }
            break;
        case 1: //switch camera
            [self didClickSwitchCameraButton:button];
            break;
        case 2: //mute speaker
            [self didClickSpeakerButton:button];
            break;
        case 3:
            [self didClickMemeberBtn];
            break;
        case 4: //white board
            [self didClickWhiteboardButton];
            break;
        case 5:
            sender.selected = !sender.selected;
            [self didClickMusicMode:sender.selected];
            break;
        default:
            break;
    }
}

- (void)startPublishVideoFile:(NSInteger)buttonIndex {
    RongRTCStreamParams *param = [[RongRTCStreamParams alloc]init];
    param.videoSizePreset = RongRTCVideoSizePreset640x360;
    NSString *tag = @"RongRTCFileVideo";
    videoOutputStream = [[RongRTCAVOutputStream alloc] initWithParameters:param tag:tag];
    [videoOutputStream setVideoRender:self.localFileVideoView];
    
    #ifdef IS_LIVE
        [self.room publishLiveAVStream:videoOutputStream extra:@"" completion:^(BOOL isSuccess, RongRTCCode desc, RongRTCLiveInfo * _Nullable liveInfo) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.chatViewBuilder.upMenuView.buttons[1].enabled = YES;
                if (desc == RongRTCCodeSuccess) {
                    [RTActiveWheel showPromptHUDAddedTo:self.view text:@"发布成功"];
                }
                else{
                    [RTActiveWheel showPromptHUDAddedTo:self.view text:@"发布失败"];
                }
                
                
                self->fileCapturer = [[RongRTCFileCapturer alloc]init];
                self->fileCapturer.delegate = self;
                NSString *path = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"video_demo%ld_low",buttonIndex] ofType:@"mp4"];
                [self->fileCapturer startCapturingFromFilePath:path onError:^(NSError * _Nullable error) {}];
                [[RongRTCAudioMixerEngine sharedEngine] mix:path action:RTCAudioActionMixAndPlay loop:YES];
                [[RongRTCAudioMixerEngine sharedEngine] start];
                
            });
        }];
    #else
        [self.room publishAVStream:videoOutputStream extra:@"" completion:^(BOOL isSuccess, RongRTCCode desc) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.chatViewBuilder.upMenuView.buttons[1].enabled = YES;
                if (desc == RongRTCCodeSuccess) {
                    [RTActiveWheel showPromptHUDAddedTo:self.view text:@"发布成功"];
                }
                else{
                    [RTActiveWheel showPromptHUDAddedTo:self.view text:@"发布失败"];
                }
                
                self->fileCapturer = [[RongRTCFileCapturer alloc]init];
                self->fileCapturer.delegate = self;
                NSString *path = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"video_demo%ld_low",buttonIndex] ofType:@"mp4"];
                [self->fileCapturer startCapturingFromFilePath:path onError:^(NSError * _Nullable error) {}];
                [[RongRTCAudioMixerEngine sharedEngine] mix:path action:RTCAudioActionMixAndPlay loop:YES];
                [[RongRTCAudioMixerEngine sharedEngine] start];
                
            });
        }];
    #endif

    isStartPublishAudio = YES;
    
    [kChatManager addRemoteUserDataModel:kChatManager.localFileVideoModel];
    NSInteger row = [kChatManager countOfRemoteUserDataArray]-1;
    NSIndexPath *tempPath = [NSIndexPath indexPathForRow:row inSection:0];
    [self.collectionView insertItemsAtIndexPaths:@[tempPath]];
}

- (void)didReadCompleted {
    RongRTCLocalVideoView *localView =  (RongRTCLocalVideoView *)kChatManager.localFileVideoModel.cellVideoView;
    [localView flushVideoView];
}

- (void)didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    [videoOutputStream write:sampleBuffer error:nil];
    CFRelease(sampleBuffer);
}

#pragma mark - click mute micphone
- (void)didClickAudioMuteButton:(UIButton *)btn
{
    kLoginManager.isMuteMicrophone = !kLoginManager.isMuteMicrophone;
    [[RongRTCAVCapturer sharedInstance] setMicrophoneDisable:kLoginManager.isMuteMicrophone];
    [self switchButtonBackgroundColor:!kLoginManager.isMuteMicrophone button:btn];

    if (kLoginManager.isMuteMicrophone) {
        [CommonUtility setButtonImage:btn imageName:@"chat_microphone_off"];
    } else {
        [CommonUtility setButtonImage:btn imageName:@"chat_microphone_on"];
    }
    kChatManager.localUserDataModel.audioLevelView.hidden = kLoginManager.isMuteMicrophone;
}

#pragma mark - click mute speaker
- (void)didClickSpeakerButton:(UIButton *)btn
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        kLoginManager.isSpeaker = !kLoginManager.isSpeaker;
        if(![[RongRTCAVCapturer sharedInstance] useSpeaker:kLoginManager.isSpeaker]) {
            kLoginManager.isSpeaker = !kLoginManager.isSpeaker;
            return ;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self switchButtonBackgroundColor:kLoginManager.isSpeaker button:btn];
            
            if (kLoginManager.isSpeaker) {
                [CommonUtility setButtonImage:btn imageName:@"chat_speaker_on"];
            } else {
                [CommonUtility setButtonImage:btn imageName:@"chat_speaker_off"];
            }
        });
    });
}

#pragma mark - click member
- (void)didClickMemeberBtn {
    self.participantsTableViewController = [[STParticipantsTableViewController alloc] initWithRoom:self.room participantsInfos:self.dataSource];
    STPresentationViewController* pvc = [[STPresentationViewController alloc] initWithPresentedViewController:self.participantsTableViewController presentingViewController:self];
    self.participantsTableViewController.transitioningDelegate = pvc;
    [self presentViewController:self.participantsTableViewController animated:YES completion:nil];
}

#pragma mark - click white board
- (void)didClickWhiteboardButton
{
    if (self.chatMode == AVChatModeObserver) {
        if (!self.chatWhiteBoardHandler.roomUuid || self.chatWhiteBoardHandler.roomUuid.length == 0 || !self.chatWhiteBoardHandler.roomToken || self.chatWhiteBoardHandler.roomToken.length == 0) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"chat_white_open_failed", nil) message:@"" preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:(UIAlertActionStyleDefault) handler:^(UIAlertAction * _Nonnull action) {
            }];
            [alert addAction:action];
            [self presentViewController:alert animated:YES completion:^{
            }];
            return;
        }
        else {
            [self.chatWhiteBoardHandler setOperationEnable:NO];
        }
    }
    
    kLoginManager.isWhiteBoardOpen = !kLoginManager.isWhiteBoardOpen;
    
    if (kLoginManager.isWhiteBoardOpen) {
        [self.chatWhiteBoardHandler openWhiteBoardRoom];
    }
    else {
        [self.chatWhiteBoardHandler closeWhiteBoardRoom];
    }
}

#pragma mark - click local video
- (void)didClickVideoMuteButton:(UIButton *)btn
{
    isChatCloseCamera = !isChatCloseCamera;
    [[RongRTCAVCapturer sharedInstance] setCameraDisable:isChatCloseCamera];
    [self switchButtonBackgroundColor:!isChatCloseCamera button:btn];
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (UIInterfaceOrientationPortrait == orientation) {
        [RongRTCAVCapturer sharedInstance].videoOrientation =  AVCaptureVideoOrientationPortrait;
    } else if (UIInterfaceOrientationLandscapeLeft == orientation) {
        [RongRTCAVCapturer sharedInstance].videoOrientation =  AVCaptureVideoOrientationLandscapeLeft;
    } else if(UIInterfaceOrientationLandscapeRight == orientation) {
        [RongRTCAVCapturer sharedInstance].videoOrientation =  AVCaptureVideoOrientationLandscapeRight;
    } else if (UIInterfaceOrientationPortraitUpsideDown == orientation) {
        [RongRTCAVCapturer sharedInstance].videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
    }
    kChatManager.localUserDataModel.isShowVideo = !isChatCloseCamera;
    kChatManager.localUserDataModel.avatarView.frame = self.localView.frame;
    if (isChatCloseCamera) {
        [CommonUtility setButtonImage:btn imageName:@"chat_close_camera"];
        self.chatViewBuilder.switchCameraButton.enabled = NO;
        [kChatManager.localUserDataModel.cellVideoView addSubview:kChatManager.localUserDataModel.avatarView];
    } else {
        [CommonUtility setButtonImage:btn imageName:@"chat_open_camera"];
        self.chatViewBuilder.switchCameraButton.enabled = YES;
        [kChatManager.localUserDataModel.avatarView removeFromSuperview];
    }
}

#pragma mark - click switch camera
- (void)didClickSwitchCameraButton:(UIButton *)btn
{
    kLoginManager.isBackCamera = !kLoginManager.isBackCamera;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[RongRTCAVCapturer sharedInstance] switchCamera];
        if (kLoginManager.isWaterMark) {
            [self.chatGPUImageHandler rotateWaterMark:kLoginManager.isBackCamera];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self switchButtonBackgroundColor:kLoginManager.isBackCamera button:btn];
        });
    });
}

#pragma mark - click hungup button
- (void)didClickHungUpButton
{
    if (kLoginManager.isMaster && [self.dataSource count] > 1) {
        STParticipantsInfo *firstInfo = (STParticipantsInfo *)self.dataSource[1];
        if ([firstInfo.userId isEqualToString:kLoginManager.userID]) {
            firstInfo = (STParticipantsInfo *)self.dataSource[0];
        }
        NSString *userId = firstInfo.userId;
        if (userId) {
            STParticipantsInfo *info = [[STParticipantsInfo alloc] initWithDictionary:@{@"userId":firstInfo.userId,
                                                                                        @"userName":firstInfo.userName,
                                                                                        @"joinMode":@(firstInfo.joinMode),
                                                                                        @"joinTime":@(firstInfo.joinTime),
                                                                                        @"master":@(1)
            }];
            STSetRoomInfoMessage *message = [[STSetRoomInfoMessage alloc] initWithInfo:info forKey:firstInfo.userId];
            [self.room setRoomAttributeValue:[info toJsonString] forKey:firstInfo.userId message:message completion:^(BOOL isSuccess, RongRTCCode desc) {}];
        }
    }
    
    [[RongRTCAudioMixerEngine sharedEngine] stop];
    [RongRTCAVCapturer sharedInstance].videoSendBufferCallback = nil;
    if (fileCapturer) {
        [fileCapturer stopCapture];
        fileCapturer.delegate = nil;
        fileCapturer = nil;
    }
    
    STDeleteRoomInfoMessage* deleteMessage = [[STDeleteRoomInfoMessage alloc] initWithInfoKey:kLoginManager.userID];
    if (kLoginManager.userID) {
        [self.room deleteRoomAttributes:@[kLoginManager.userID] message:deleteMessage completion:^(BOOL isSuccess, RongRTCCode desc) {
        }];
    }
    
    
    if (_chatWhiteBoardHandler) {
        [_chatWhiteBoardHandler leaveRoom];
        if (![kChatManager countOfRemoteUserDataArray]) {
            [self.room deleteRoomAttributes:@[kWhiteBoardMessageKey] message:nil completion:^(BOOL isSuccess, RongRTCCode desc) {
            }];
            [_chatWhiteBoardHandler deleteRoom];
        }
        _chatWhiteBoardHandler = nil;
    }
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[RCIMClient sharedRCIMClient] setRCConnectionStatusChangeDelegate:nil];
        [self.controller removeFromSuperview];
        self.controller = nil;
        [self.participantsTableViewController dismissViewControllerAnimated:YES completion:nil];
        [[RongRTCAVCapturer sharedInstance] stopCapture];
        
        if (kLoginManager.isHost) {
            [[RTHttpNetworkWorker shareInstance] unpublish:self.room.roomId completion:^(BOOL success) {
                DLog(@"leave live ,unpublish: %@", @(success));
            }];
            [[RongRTCEngine sharedEngine] leaveRoom:kLoginManager.roomNumber completion:^(BOOL isSuccess, NSInteger code) {
                self.room = nil;
                if (isSuccess) {
                    DLog(@"leaveRoom Success");
                }else {
                    DLog(@"leaveRoom Failed, code: %zd", code);
                }
            }];
        } else {
#ifdef IS_LIVE
            [[RongRTCEngine sharedEngine] unsubscribeLiveAVStream:nil completion:^(BOOL isSuccess, RongRTCCode code) {
                self.room = nil;
                if (isSuccess) {
                    DLog(@"leaveRoom Success");
                }else {
                    DLog(@"leaveRoom Failed, code: %zd", code);
                }
            }];
            
#else
            [[RongRTCEngine sharedEngine] leaveRoom:kLoginManager.roomNumber completion:^(BOOL isSuccess, NSInteger code) {
                self.room = nil;
                if (isSuccess) {
                    DLog(@"leaveRoom Success");
                }else {
                    DLog(@"leaveRoom Failed, code: %zd", code);
                }
            }];
#endif
        }
        
        weakSelf.isFinishLeave = YES;
        [weakSelf.durationTimer invalidate];
        weakSelf.talkTimeLabel.text = @"";
        weakSelf.localView.hidden = NO;
        [weakSelf.localView removeFromSuperview];
        weakSelf.localView = nil;
        
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        
        [kChatManager.localUserDataModel removeKeyPathObservers];
        [kChatManager.localUserDataModel.cellVideoView removeFromSuperview];
        kChatManager.localUserDataModel = nil;
        [kChatManager.localFileVideoModel removeKeyPathObservers];
        [kChatManager.localFileVideoModel.cellVideoView removeFromSuperview];
        kChatManager.localFileVideoModel = nil;
        kLoginManager.isMuteMicrophone = NO;
        kLoginManager.isSwitchCamera = NO;
        kLoginManager.isBackCamera = NO;
        kLoginManager.isWhiteBoardOpen = NO;
        [kChatManager clearAllDataArray];
        [weakSelf.collectionView reloadData];
        [weakSelf.collectionView removeFromSuperview];
        weakSelf.collectionView.chatVC = nil;
        weakSelf.collectionView = nil;
        [weakSelf.navigationController popViewControllerAnimated:YES];
    });
}

#pragma mark - switch menu button color
- (void)switchButtonBackgroundColor:(BOOL)is button:(UIButton *)btn
{
    dispatch_async(dispatch_get_main_queue(), ^{
        btn.backgroundColor = !is ? [UIColor whiteColor] : [UIColor colorWithRed:1.f green:1.f blue:1.f alpha:0.4f];
    });
}

#pragma mark - Speaker/Audio/Video button selected
- (void)selectSpeakerButtons:(BOOL)selected
{
    _speakerControlButton.selected = selected;
}

- (void)selectAudioMuteButtons:(BOOL)selected
{
    _audioMuteControlButton.selected = selected;
}

- (BOOL)isHeadsetPluggedIn
{
    AVAudioSessionRouteDescription *route = [[AVAudioSession sharedInstance] currentRoute];
    for (AVAudioSessionPortDescription* desc in [route outputs])
    {
        NSString *outputer = desc.portType;
        if ([outputer isEqualToString:AVAudioSessionPortHeadphones] || [outputer isEqualToString:AVAudioSessionPortBluetoothLE] || [outputer isEqualToString:AVAudioSessionPortBluetoothHFP] || [outputer isEqualToString:AVAudioSessionPortBluetoothA2DP])
            return YES;
    }
    return NO;
}

#pragma mark - AlertController
- (void)alertWith:(NSString *)title withMessage:(NSString *)msg withOKAction:(nullable  UIAlertAction *)ok withCancleAction:(nullable UIAlertAction *)cancel
{
    self.alertController = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    if (cancel)
        [self.alertController addAction:cancel];
    if (!ok){
        UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"chat_alert_btn_confirm", nil) style:(UIAlertActionStyleDefault) handler:^(UIAlertAction * _Nonnull action) {
            [self.alertController dismissViewControllerAnimated:YES completion:nil];
        }];
        [self.alertController addAction:ok];
    }else{
        [self.alertController addAction:ok];
    }
    [self presentViewController:self.alertController animated:YES completion:^{}];
}

#pragma mark - Getters
- (NSMutableArray<STParticipantsInfo*>*)dataSource {
    if (!_dataSource) {
        _dataSource = [[NSMutableArray alloc] initWithCapacity:100];
    }
    return _dataSource;
}

- (ChatWhiteBoardHandler *)chatWhiteBoardHandler
{
    if (!_chatWhiteBoardHandler) {
        _chatWhiteBoardHandler = [[ChatWhiteBoardHandler alloc] initWithViewController:self];
    }
    
    return _chatWhiteBoardHandler;
}


- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)didClickMusicMode:(BOOL) selected
{
    if (selected) {
        [[RongRTCAVCapturer sharedInstance] changeMusicPlayMode:RongRTCAudioScenarioMusicSingleNotePlay];
    } else {
        [[RongRTCAVCapturer sharedInstance] changeMusicPlayMode:RongRTCAudioScenarioMusicNomalPlay];
    }
}


#pragma mark - RCConnectionStatusChangeDelegate
- (void)onConnectionStatusChanged:(RCConnectionStatus)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (status == ConnectionStatus_Connected) {
            self.connectingLabel.text = nil;
            self.connectingLabel.hidden = YES;
        } else if (status == ConnectionStatus_KICKED_OFFLINE_BY_OTHER_CLIENT) {
            [self didClickHungUpButton];
            kLoginManager.isIMConnectionSucc = NO;
            UIAlertView *alertV = [[UIAlertView alloc]initWithTitle:nil message:@"此用户已在其他设备登录，可修改用户名后再尝试登录" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
            [alertV show];
        } else {
            self.connectingLabel.hidden = NO;
            self.connectingLabel.text = NSLocalizedString(@"connecting_im", nil);
        }
    });
}

@end
