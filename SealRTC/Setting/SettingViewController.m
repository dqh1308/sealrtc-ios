//
//  SettingViewController.m
//  RongCloud
//
//  Created by LiuLinhong on 16/11/11.
//  Copyright © 2016年 Beijing Rongcloud Network Technology Co. , Ltd. All rights reserved.
//

#import "SettingViewController.h"
#import "CommonUtility.h"
#import "SXAlertView.h"
#import "LoginViewController.h"
#import "UIView+Toast.h"

static NSUserDefaults *settingUserDefaults = nil;

@interface SettingViewController ()<UITextFieldDelegate>
{
    UITapGestureRecognizer *tapGestureRecognizer;
}
@end


@implementation SettingViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"setting_title", nil);
    self.view.backgroundColor = [UIColor whiteColor];

    [self loadPlistData];
    
    self.settingTableViewDelegateSourceImpl = [[SettingTableViewDelegateSourceImpl alloc] initWithViewController:self];
    self.settingPickViewDelegateImpl = [[SettingPickViewDelegateImpl alloc] initWithViewController:self];
    self.settingTextFieldDelegateImpl = [[SettingTextFieldDelegateImpl alloc] initWithViewController:self];
    self.settingViewBuilder = [[SettingViewBuilder alloc] initWithViewController:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self loadPlistData];
    self.sectionNumber = 6;
    [self.settingViewBuilder.tableView reloadData];
    self.settingViewBuilder.userIDTextField.text = kLoginManager.userID;
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.settingViewBuilder.resolutionRatioPickview remove];
    self.navigationItem.rightBarButtonItem = nil;
    [self.navigationController.navigationBar removeGestureRecognizer:tapGestureRecognizer];
}

- (BOOL)navigationShouldPopOnBackButton
{
    return YES;
}

#pragma mark - load default plist data
- (void)loadPlistData
{
    settingUserDefaults = [SettingViewController shareSettingUserDefaults];
    
    self.resolutionRatioArray = [CommonUtility getPlistArrayByplistName:Key_ResolutionRatio];
    self.frameRateArray = [CommonUtility getPlistArrayByplistName:Key_FrameRate];
    self.codeRateArray = [CommonUtility getPlistArrayByplistName:Key_CodeRate];
    self.codingStyleArray = [CommonUtility getPlistArrayByplistName:Key_CodingStyle];
    
    [self.settingViewBuilder.tinyStreamSwitch setOn:kLoginManager.isTinyStream];
}

#pragma mark - connect style witch action
- (void)gpuSwitchAction
{
    [kLoginManager setIsGPUFilter:self.settingViewBuilder.gpuSwitch.on];
}

- (void)tinyStreamSwitchAction
{
    [kLoginManager setIsTinyStream:self.settingViewBuilder.tinyStreamSwitch.on];
}

- (void)autoTestAction
{
    [kLoginManager setIsAutoTest:self.settingViewBuilder.autoTestSwitch.on];
}

- (void)waterMarkAction
{
    [kLoginManager setIsWaterMark:self.settingViewBuilder.waterMarkSwitch.on];
}

- (void)audioScenarioAction {
    [kLoginManager setIsAudioScenarioMusic:self.settingViewBuilder.audioScenarioSwitch.on];
}


#pragma mark - tap gesture action
- (void)longPressedGestureAction:(UILongPressGestureRecognizer *)gesture {
    UILongPressGestureRecognizer *press = (UILongPressGestureRecognizer *)gesture;
    if (press.state == UIGestureRecognizerStateBegan) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        if (kLoginManager.userID && kLoginManager.userID.length > 0) {
            pasteboard.string = kLoginManager.userID;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.view makeToast:NSLocalizedString(@"setting_userid_tip", nil) duration:1.5 position:CSToastPositionCenter];
            });
        }
    }
}

#pragma mark - share setting UserDefaults
+ (NSUserDefaults *)shareSettingUserDefaults
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        settingUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"settingUserDefaults"];
    });
    return settingUserDefaults;
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait ;
}

@end
