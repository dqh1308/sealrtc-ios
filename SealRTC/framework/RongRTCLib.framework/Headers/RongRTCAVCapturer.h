//
//  RongRTCAVCaptureOutputStream.h
//  RongRTCLib
//
//  Created by RongCloud on 2019/1/8.
//  Copyright © 2019年 RongCloud. All rights reserved.
//

#import "RongRTCAVOutputStream.h"
#import <CoreMedia/CoreMedia.h>
#import <UIKit/UIKit.h>
#import "RongRTCVideoCaptureParam.h"
#import "RongRTCDefine.h"
#import "RongRTCAudioMixerEngine.h"

NS_ASSUME_NONNULL_BEGIN

@class RongRTCLocalVideoView;
@class RTCPeerConnectionFactory;
@class RongRTCVideoCaptureParam;

/*!
 音视频采集管理实例
 */
@interface RongRTCAVCapturer : RongRTCAVOutputStream

/*!
 初始化
 
 @discussion
 初始化
 
 @warning
 不可用
 
 @remarks 资源管理
 @return 失败
 */
- (instancetype)init NS_UNAVAILABLE;

/*!
 初始化
 
 @discussion
 初始化
 
 @warning
 不可用
 
 @remarks 资源管理
 @return 失败
 */
- (instancetype)new NS_UNAVAILABLE;

/*!
 初始化
 
 @param pars 采集参数
 @param tag 标识
 @discussion
 初始化
 
 @warning
 不可用
 
 @remarks 资源管理
 @return 失败
 */
- (instancetype)initWithParameters:(nullable RongRTCStreamParams*)pars
                               tag:(NSString*)tag NS_UNAVAILABLE;

/*!
 获取单例对象
 
 @discussion
 获取单例对象
 
 @remarks 资源管理
 @return 采集器单例对象
 */
+ (instancetype)sharedInstance;

/*!
 通话前设置音视频采集参数
 
 @param params 参数
 @discussion
 通话前设置音视频采集参数, 通话过程中设置无效
 
 @remarks 资源管理
*/
- (void)setCaptureParam:(RongRTCVideoCaptureParam*)params;

/*!
 关闭/打开麦克风
 
 @param disable YES 关闭,NO 打开
 @discussion
 关闭/打开麦克风
 
 @remarks 音频配置
 */
- (void)setMicrophoneDisable:(BOOL)disable;

/*!
 切换前后摄像头
 
 @discussion
 切换前后摄像头
 
 @remarks 视频配置
 */
- (void)switchCamera;

/*!
 切换使用外放/听筒
 
 @param useSpeaker YES 使用扬声器  NO 不使用
 @discussion
 切换使用外放/听筒
 
 @remarks 音频配置
 @return 接入外设时, 如蓝牙音箱等 返回 NO
 */
- (BOOL)useSpeaker:(BOOL)useSpeaker;

/*!
 开启音视频采集
 
 @discussion
 开启音视频采集
 
 @remarks 资源管理
 */
- (void)startCapture;

/*!
 关闭音视频采集
 
 @discussion
 关闭音视频采集
 
 @remarks 资源管理
 */
- (void)stopCapture;

/*!
 采集运行中关闭或打开摄像头
 
 @param disable YES 关闭  NO 打开
 @discussion
 采集运行中关闭或打开摄像头
 
 @remarks 视频配置
 */
- (void)setCameraDisable:(BOOL)disable;

/*!
 设置通话过程中的视频分辨率
 */
@property (nonatomic,readonly) RongRTCVideoSizePreset videoSizePreset;

/*!
 设置通话过程中视频帧率
 */
@property (nonatomic,readonly) RongRTCVideoFPS videoFrameRate;

/*!
 当前摄像头的位置
 */
@property (nonatomic,readonly) RongRTCDeviceCamera cameraPosition;

/*!
 设置摄像头采集方向,默认以 AVCaptureVideoOrientationPortrait 角度进行采集
 */
@property (nonatomic,assign) AVCaptureVideoOrientation videoOrientation;

/*!
 接收到音频或者发送音频时的音频数据,用户可以直接处理该音频数据
 */
@property (nonatomic,copy,nullable) RongRTCAudioPCMBufferCallback audioBufferCallback;

/*!
 引擎底部开始视频编码并发送之前会往上层抛一个回调,用户可以修改和调整 CMSampleBufferRef 数据,然后返回一个 CMSampleBufferRef 数据,如果返回空或者没有实现该回调,则会使用默认视频数据传输
 
 注：如果用户传正常数据,则内部会自行 CFRelease CMSampleBufferRef 对象,上层不需要再考虑释放问题
 */
@property (nonatomic,copy,nullable) RongRTCVideoCMSampleBufferCallback videoSendBufferCallback;

/*!
 本地摄像头采集的视频在即将预览前会往上层抛一个视频帧回调,用户可以处理视频帧数据之后然后回传给 RTC,RTC 使用用户处理的视频帧进行预览
 
 注：如果用户传正常数据,则内部会自行 CFRelease CMSampleBufferRef 对象,上层不需要再考虑释放问题
 */
@property (nonatomic,copy,nullable) RongRTCVideoCMSampleBufferCallback videoDisplayBufferCallback;

/*!
 设置视频媒体数据的渲染界面
 
 @param render 渲染界面
 @discussion
 设置视频媒体数据的渲染界面
 
 @remarks 视频配置
 */
- (void)setVideoRender:(nullable RongRTCLocalVideoView *)render;

/*!
 混音音频 PCM 数据
 
 @param pcmBuffer 声音 buffer
 @param action 设置混音模式
 @discussion
 混合 PCM 数据,单声道,16 bit signed, 48000 采样率,外置 mic 和网络音频流场景可以
 通过该方法实现外置 mic 的混合以及替换的逻辑, 目前只支持下面两种使用方式: action: RTCAudioActionOnlyMix, RTCAudioActionReplace
 
 内部会保证时间同步,上层请注意往里面写的频率（写入速度太快容易导致内部缓冲区满而导致丢失数据）
 另外如果仅仅是文件声音混合,请直接使用 RongRTCAudioMixerEngine,使用更加简单方便
 
 @remarks 音频流处理
 @return 混音是否成功
 */
- (BOOL)writePCMBuffer:(NSData *)pcmBuffer action:(RTCAudioAction)action;

/*!
 设置音乐演奏模式
 
 @param mode RongRTCAudioScenarioMusicPlayMode 音乐演奏模式, RongRTCAudioScenarioMusicNomalPlay 常规演奏模式,默认模式
 @discussion
 设置音乐演奏模式
 
 @remarks 音频流处理
 @return 设置是否成功
 */
- (BOOL)changeMusicPlayMode:(RongRTCAudioScenarioMusicPlayMode)mode;

/*!
 将所有远端用户静音
 
 @param mute 是否静音所有远端用户, YES 禁止  NO 允许
 @discussion
 将所有远端用户静音, 注: 该功能只是不播放接收到的音频数据
 
 @remarks 音频流处理
 */
- (void)muteAllRemoteAudio:(BOOL)mute;

@end

NS_ASSUME_NONNULL_END
