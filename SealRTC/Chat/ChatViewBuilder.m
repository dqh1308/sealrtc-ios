//
//  ChatViewBuilder.m
//  RongCloud
//
//  Created by LiuLinhong on 2016/11/18.
//  Copyright © 2016年 Beijing Rongcloud Network Technology Co. , Ltd. All rights reserved.
//

#import "ChatViewBuilder.h"
#import "ChatViewController.h"
#import "CommonUtility.h"

#define MenuButtonCount 7

@interface ChatViewBuilder ()
{
    ChatBubbleMenuViewDelegateImpl *chatBubbleMenuViewDelegateImpl;
    BOOL isLeftDisplay, isRightDisplay;
}

@property (nonatomic, weak) ChatViewController *chatViewController;

@end


@implementation ChatViewBuilder

- (instancetype)initWithViewController:(UIViewController *)vc
{
    self = [super init];
    if (self)
    {
        self.chatViewController = (ChatViewController *) vc;
        
        [self initInfoLabel];
        [self initSwipeGesture];
        isLeftDisplay = NO;
        isRightDisplay = NO;
        
        [self initView];
    }
    return self;
}

- (void)initView
{
    // 挂断按钮
    self.hungUpButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.hungUpButton.frame = CGRectMake(0, 0, 44, 44);
    NSString *deviceModel = [UIDevice currentDevice].model;
    if ([deviceModel containsString:@"iPad"])
        self.hungUpButton.center = CGPointMake(ScreenWidth/2, ScreenHeight - 44);
    else
        self.hungUpButton.center = CGPointMake(ScreenWidth/2, ScreenHeight-44);
    
    [self.hungUpButton addTarget:self.chatViewController action:@selector(didClickHungUpButton) forControlEvents:UIControlEventTouchUpInside];
    self.hungUpButton.backgroundColor = redButtonBackgroundColor;
    self.hungUpButton.layer.masksToBounds = YES;
    self.hungUpButton.layer.cornerRadius = 22.f;
    [self.chatViewController.view addSubview:self.hungUpButton];
    [CommonUtility setButtonImage:self.hungUpButton imageName:@"chat_hung_up"];
    
    // 开/关摄像头按钮
    self.openCameraButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.openCameraButton.frame = CGRectMake(ScreenWidth/2 - 120.f - 44.f, self.hungUpButton.frame.origin.y, 44.f, 44.f);
    self.openCameraButton.center = CGPointMake(ScreenWidth/2 - ButtonDistance - 44/2, ScreenHeight-44);
    self.openCameraButton.layer.cornerRadius = 44.f / 2.f;
    self.openCameraButton.backgroundColor = [UIColor colorWithRed:1.f green:1.f blue:1.f alpha:0.4f];
    self.openCameraButton.clipsToBounds = YES;
    [self.openCameraButton addTarget:self.chatViewController action:@selector(didClickVideoMuteButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.openCameraButton setTintColor:[UIColor blackColor]];
    [self.chatViewController.view addSubview:self.openCameraButton];
    [CommonUtility setButtonImage:self.openCameraButton imageName:@"chat_open_camera"];
    
    // 开/关麦克风按钮
    self.microphoneOnOffButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.microphoneOnOffButton.frame = CGRectMake(ScreenWidth/2 + 120.f, self.hungUpButton.frame.origin.y, 44.f, 44.f);
    self.microphoneOnOffButton.center = CGPointMake(ScreenWidth/2 + ButtonDistance+44/2, ScreenHeight-44);
    self.microphoneOnOffButton.layer.cornerRadius = 44.f / 2.f;
    self.microphoneOnOffButton.backgroundColor = [UIColor colorWithRed:1.f green:1.f blue:1.f alpha:0.4f];
    self.microphoneOnOffButton.clipsToBounds = YES;
    [self.microphoneOnOffButton addTarget:self.chatViewController action:@selector(didClickAudioMuteButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.microphoneOnOffButton setTintColor:[UIColor blackColor]];
    [self.chatViewController.view addSubview:self.microphoneOnOffButton];
    [CommonUtility setButtonImage:self.microphoneOnOffButton imageName:@"chat_microphone_on"];
    
    [self initMenuButton];
}

#pragma mark - init menu button
- (void)initMenuButton
{
    chatBubbleMenuViewDelegateImpl = [[ChatBubbleMenuViewDelegateImpl alloc] initWithViewController:self.chatViewController];
    
    self.chatViewController.homeImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.f, 0.f, 36.f, 36.f)];
    self.chatViewController.homeImageView.userInteractionEnabled = YES;
    self.chatViewController.homeImageView.image = [UIImage imageNamed:@"chat_menu"];
    self.chatViewController.homeImageView.backgroundColor = [UIColor whiteColor];
    self.chatViewController.homeImageView.layer.masksToBounds = YES;
    self.chatViewController.homeImageView.layer.cornerRadius = self.chatViewController.homeImageView.frame.size.width / 2.f;
    
    CGRect BubbleMenuButtonRect;
    NSString *deviceModel = [UIDevice currentDevice].model;
    if ([deviceModel containsString:@"iPad"])
    {
        BubbleMenuButtonRect = CGRectMake(self.chatViewController.view.frame.size.width - self.chatViewController.homeImageView.frame.size.width - 16.f, ScreenHeight - 60, self.chatViewController.homeImageView.frame.size.width, self.chatViewController.homeImageView.frame.size.height);
    }
    else
    {
        BubbleMenuButtonRect = CGRectMake(self.chatViewController.view.frame.size.width - self.chatViewController.homeImageView.frame.size.width - 16.f, (ScreenHeight - (TitleHeight + self.chatViewController.videoHeight) - 36)/2 + (TitleHeight + self.chatViewController.videoHeight), self.chatViewController.homeImageView.frame.size.width, self.chatViewController.homeImageView.frame.size.height);
    }
    
    self.upMenuView = [[DWBubbleMenuButton alloc] initWithFrame:BubbleMenuButtonRect expansionDirection:DirectionUp];
    CGFloat centerY = MAX(ScreenHeight/2+(MenuButtonCount*36+(MenuButtonCount-1)*10)/2,self.chatViewController.dataTrafficLabel.frame.origin.y+self.chatViewController.dataTrafficLabel.frame.size.height + 130.0 + (MenuButtonCount*36+(MenuButtonCount-1)*10));
    
    self.upMenuView.center = CGPointMake(self.chatViewController.view.frame.size.width - self.chatViewController.homeImageView.frame.size.width/2 - 16.f, centerY);
    self.upMenuView.homeButtonView = self.chatViewController.homeImageView;
    self.upMenuView.delegate = chatBubbleMenuViewDelegateImpl;
    [self.upMenuView addButtons:[self createDemoButtonArray]];
    [self.chatViewController.view addSubview:self.upMenuView];
    [self.upMenuView showButtons];
    self.upMenuView.homeButtonView.hidden = YES;
}

- (NSArray *)createDemoButtonArray
{
    NSMutableArray *buttonsMutable = [[NSMutableArray alloc] init];
    for (NSInteger i = 0; i < MenuButtonCount; i++)
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(0.f, 0.f, 36.f, 36.f);
        button.layer.cornerRadius = button.frame.size.height / 2.f;
        button.backgroundColor = [UIColor colorWithRed:1.f green:1.f blue:1.f alpha:0.4f];
        button.tintColor = [UIColor blackColor];
        button.clipsToBounds = YES;
        NSInteger tag = i - 1;
        button.tag = tag;
        [button addTarget:self.chatViewController action:@selector(menuItemButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [buttonsMutable addObject:button];
        
        switch (tag)
        {
            case -1:{
                [buttonsMutable removeObject:button];
                button = [UIButton buttonWithType:UIButtonTypeCustom];
                button.frame = CGRectMake(0.f, 0.f, 36.f, 36.f);
                button.layer.cornerRadius = button.frame.size.height / 2.f;
                button.backgroundColor = [UIColor colorWithRed:1.f green:1.f blue:1.f alpha:0.4f];
                button.clipsToBounds = YES;
                button.tag = tag;
                [button addTarget:self.chatViewController action:@selector(menuItemButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
                [buttonsMutable addObject:button];
                [button setImage:[UIImage imageNamed:@"chat_custom_audio_normal"] forState:UIControlStateNormal];
                [button setImage:[UIImage imageNamed:@"chat_custom_audio_selected"] forState:UIControlStateSelected];
                self.customAudioButton = button;
            }
                break;
            case 0:{
                [buttonsMutable removeObject:button];
                button = [UIButton buttonWithType:UIButtonTypeCustom];
                button.frame = CGRectMake(0.f, 0.f, 36.f, 36.f);
                button.layer.cornerRadius = button.frame.size.height / 2.f;
                button.backgroundColor = [UIColor colorWithRed:1.f green:1.f blue:1.f alpha:0.4f];
                button.clipsToBounds = YES;
                button.tag = tag;
                [button addTarget:self.chatViewController action:@selector(menuItemButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
                [buttonsMutable addObject:button];
                [button setImage:[UIImage imageNamed:@"chat_vc_normalvideo"] forState:UIControlStateNormal];
                [button setImage:[UIImage imageNamed:@"chat_vc_selectvideo"] forState:UIControlStateSelected];
                self.customVideoButton = button;
            }
                break;
            case 1: //切换前/后摄像头
            {
                self.switchCameraButton = button;
                [CommonUtility setButtonImage:button imageName:@"chat_switch_camera"];
            }
                break;
            case 2: //切换扬声器/听筒
            {
                self.speakerOnOffButton = button;
                [CommonUtility setButtonImage:button imageName:@"chat_speaker_on"];
            }
                break;
            case 3: //人员列表
            {
                [CommonUtility setButtonImage:button imageName:@"participants"];
            }
                break;
            case 4: //白板开关
            {
                self.whiteboardButton = button;
                [CommonUtility setButtonImage:button imageName:@"chat_white_board_on"];
            }
                break;
            case 5:{
                [buttonsMutable removeObject:button];
                button = [UIButton buttonWithType:UIButtonTypeCustom];
                button.frame = CGRectMake(0.f, 0.f, 36.f, 36.f);
                button.layer.cornerRadius = button.frame.size.height / 2.f;
                button.backgroundColor = [UIColor colorWithRed:1.f green:1.f blue:1.f alpha:0.4f];
                button.clipsToBounds = YES;
                button.tag = tag;
                [button addTarget:self.chatViewController action:@selector(menuItemButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
                [buttonsMutable addObject:button];
                [button setImage:[UIImage imageNamed:@"chat_custom_audio_normal"] forState:UIControlStateNormal];
                [button setImage:[UIImage imageNamed:@"chat_custom_audio_selected"] forState:UIControlStateSelected];
                if(!kLoginManager.isAudioScenarioMusic) {
                    button.enabled = NO;
                }
                self.musicModeButton = button;
            }
                break;
            default:
                break;
        }
    }
    
    return [buttonsMutable copy];
}

#pragma mark - bitrate display label
- (void)initInfoLabel
{
    self.excelView = [[BlinkExcelView alloc] initWithFrame:CGRectMake(-ScreenWidth, 0, ScreenWidth, ScreenHeight)];
    self.excelView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.35];
    self.excelView.hidden = YES;
    [self.chatViewController.view addSubview:self.excelView];
    
    self.masterLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, (ScreenHeight-26)/2 + 30, ScreenWidth, 26)];
    self.masterLabel.textAlignment = NSTextAlignmentCenter;
    self.masterLabel.font = [UIFont systemFontOfSize:16];
    self.masterLabel.backgroundColor = [UIColor clearColor];
    self.masterLabel.hidden = YES;
    self.masterLabel.textColor = [UIColor whiteColor];
    [self.chatViewController.view addSubview:self.masterLabel];
}

- (void)initSwipeGesture
{
    _leftSwipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeGestureRecognizerAction:)];
    _leftSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    [self.chatViewController.view addGestureRecognizer:_leftSwipeGestureRecognizer];
    
    _rightSwipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeGestureRecognizerAction:)];
    _rightSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.chatViewController.view addGestureRecognizer:_rightSwipeGestureRecognizer];
}

- (void)swipeGestureRecognizerAction:(UISwipeGestureRecognizer *)recognize
{
    if (kLoginManager.isWhiteBoardOpen) return;

    switch (recognize.direction)
    {
        case UISwipeGestureRecognizerDirectionRight:
        {
            if (!isLeftDisplay)
            {
                self.excelView.hidden = NO;
                [self.chatViewController showButtons:YES];
                [UIView animateWithDuration:0.3 animations:^{
                    self.excelView.frame =  CGRectMake(0, self.excelView.frame.origin.y, self.excelView.frame.size.width, self.excelView.frame.size.height);
                } completion:^(BOOL finished) {
                }];
                isLeftDisplay = YES;
            }
        }
            break;
            
        case UISwipeGestureRecognizerDirectionLeft:
        {
            if (isLeftDisplay)
            {
                [UIView animateWithDuration:0.3 animations:^{
                    [self.chatViewController showButtons:NO];
                    self.excelView.frame =  CGRectMake(-ScreenWidth, self.excelView.frame.origin.y, self.excelView.frame.size.width, self.excelView.frame.size.height);
                } completion:^(BOOL finished) {
                    self.excelView.hidden = YES;
                }];
                isLeftDisplay = NO;
            }
        }
            break;
        default:
            break;
    }
}
- (void)enableSwipeGesture:(BOOL)enable{
    _rightSwipeGestureRecognizer.enabled = enable;
    _leftSwipeGestureRecognizer.enabled = enable;
}
- (void)dealloc {
    [self.excelView removeFromSuperview];
    self.excelView = nil;
}

@end
