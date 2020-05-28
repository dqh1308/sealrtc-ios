//
//  RongRTCFileCapturer.m
//  RongRTCLib
//
//  Created by jfdreamyang on 2019/1/18.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RongRTCFileCapturer.h"

NSString *const kIMFileVideoCapturerErrorDomain = @"cn.rongcloud.RongRTCFileVideoCapturer";

typedef NS_ENUM(NSInteger, IMFileVideoCapturerErrorCode) {
    RongRTCFileVideoCapturerErrorCode_CapturerRunning = 2000,
    RongRTCFileVideoCapturerErrorCode_FileNotFound
};

typedef NS_ENUM(NSInteger, RongRTCFileVideoCapturerStatus) {
    RongRTCFileVideoCapturerStatusNotInitialized,
    RongRTCFileVideoCapturerStatusStarted,
    RongRTCFileVideoCapturerStatusStopped
};

@implementation RongRTCFileCapturer
{
    AVAssetReader *_reader;
    AVAssetReaderTrackOutput *_outVideoTrack;
    AVAssetReaderTrackOutput *_outAudioTrack;
    RongRTCFileVideoCapturerStatus _status;
    CMTime _lastPresentationTime;
    dispatch_queue_t _frameQueue;
    NSURL *_fileURL;
    
    Float64 _currentMediaTime;
    Float64 _currentVideoTime;
    NSThread* _audioDecodeThread;
}

-(void)startCapturingFromFilePath:(NSString *)filePath onError:(RongRTCVideoCapturerErrorBlock)errorBlock{
    // 可以矫正由于时间偏差导致输出不准确的问题，也可以解决循环播放导致的中间播放延迟，中间会丢弃一部分视频帧
    _currentMediaTime = CACurrentMediaTime();
    _currentVideoTime = CACurrentMediaTime();
    _currentPath = filePath;
    
    if (_status == RongRTCFileVideoCapturerStatusStarted) {
        NSError *error =
        [NSError errorWithDomain:kIMFileVideoCapturerErrorDomain
                            code:RongRTCFileVideoCapturerErrorCode_CapturerRunning
                        userInfo:@{NSUnderlyingErrorKey : @"Capturer has been started."}];
        
        errorBlock(error);
        return;
    } else {
        _status = RongRTCFileVideoCapturerStatusStarted;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *pathForFile = filePath;
        self->_lastPresentationTime = CMTimeMake(0, 0);
        self->_fileURL = [NSURL fileURLWithPath:pathForFile];
        [self setupReaderOnError:errorBlock];
    });
}
- (void)setupReaderOnError:(RongRTCVideoCapturerErrorBlock)errorBlock {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:_fileURL options:nil];
    NSArray *allTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    _lastPresentationTime = CMTimeMakeWithSeconds(0.0, 1);
    _reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    if (error) {
        errorBlock(error);
        return;
    }
    
    NSDictionary *options = @{
                              (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
                              };
    _outVideoTrack =
    [[AVAssetReaderTrackOutput alloc] initWithTrack:allTracks.firstObject outputSettings:options];
    [_reader addOutput:_outVideoTrack];
    [self setupAudioTrakOutput:asset];
    [_reader startReading];
    if (!_audioDecodeThread) {
        _audioDecodeThread = [[NSThread alloc] initWithTarget:self selector:@selector(audioDecode) object:nil];
    }
    [_audioDecodeThread start];
    [self readNextBuffer];
}

- (void)stopCapture {
    _status = RongRTCFileVideoCapturerStatusStopped;
}

- (void)setupAudioTrakOutput:(AVURLAsset*)asset {
    AVAssetTrack* audioTrack = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    AudioStreamBasicDescription asbd = RongRTCAudioMixer.writeAsbd;
     NSDictionary* settings = @{AVFormatIDKey:               @(kAudioFormatLinearPCM),
                                AVSampleRateKey:             @(asbd.mSampleRate),
                                AVNumberOfChannelsKey:       @(asbd.mChannelsPerFrame),
                                AVLinearPCMIsNonInterleaved: @(NO)};
    _outAudioTrack = [[AVAssetReaderTrackOutput alloc] initWithTrack:audioTrack outputSettings:settings];
    if ([_reader canAddOutput:_outAudioTrack]) {
        [_reader addOutput:_outAudioTrack];
    }
}

- (void)audioDecode {
    SInt64 sampleTime = 0;
    while (true) {
        CMSampleBufferRef sample = [_outAudioTrack copyNextSampleBuffer];
        if (!sample) {
            break;
        }
        AudioBufferList abl = {0};
        CMBlockBufferRef blockBuffer;
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sample,
                                                                NULL,
                                                                &abl,
                                                                sizeof(abl),
                                                                NULL,
                                                                NULL,
                                                                0,
                                                                &blockBuffer);
        CMItemCount count =  CMSampleBufferGetNumSamples(sample);
        [[RongRTCAudioMixer sharedEngine] writeAudioBufferList:&abl frames:(UInt32)count sampleTime:sampleTime playback:YES];
        sampleTime += count;
        CFRelease(blockBuffer);
        CFRelease(sample);
        if(_status == RongRTCFileVideoCapturerStatusStopped) {
            break;
        }
    }

    [_audioDecodeThread cancel];
    _audioDecodeThread = nil;
}

#pragma mark - Private

- (nullable NSString *)pathForFileName:(NSString *)fileName {
    NSArray *nameComponents = [fileName componentsSeparatedByString:@"."];
    if (nameComponents.count != 2) {
        return nil;
    }
    
    NSString *path =
    [[NSBundle mainBundle] pathForResource:nameComponents[0] ofType:nameComponents[1]];
    return path;
}

- (dispatch_queue_t)frameQueue {
    if (!_frameQueue) {
        _frameQueue = dispatch_queue_create("org.webrtc.filecapturer.video", DISPATCH_QUEUE_SERIAL);
//        dispatch_set_target_queue(_frameQueue,
//                                  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
    }
    return _frameQueue;
}

- (void)readNextBuffer {
       __weak typeof(self) weakSelf = self;
    if (_status == RongRTCFileVideoCapturerStatusStopped) {
        [_reader cancelReading];
        _reader = nil;
        return;
    }
    
    if (_reader.status == AVAssetReaderStatusCompleted) {
        [_reader cancelReading];
        _reader = nil;
        [self.delegate didReadCompleted];
        [self setupReaderOnError:nil];
        return;
    }
    
    CMSampleBufferRef sampleBuffer = [_outVideoTrack copyNextSampleBuffer];
    if (!sampleBuffer) {
        dispatch_async([weakSelf frameQueue], ^{
            [weakSelf readNextBuffer];
        });
        
        return;
    }
    if (CMSampleBufferGetNumSamples(sampleBuffer) != 1 || !CMSampleBufferIsValid(sampleBuffer) ||
        !CMSampleBufferDataIsReady(sampleBuffer)) {
        CFRelease(sampleBuffer);
        [self readNextBuffer];
        return;
    }
    
    [self publishSampleBuffer:sampleBuffer];
}

- (void)publishSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    Float64 presentationDifference =
    CMTimeGetSeconds(CMTimeSubtract(presentationTime, _lastPresentationTime));
    _lastPresentationTime = presentationTime;
    __weak typeof(self) weakSelf = self;
    if (isnan(presentationDifference)) {
        CFRelease(sampleBuffer);
        dispatch_async([weakSelf frameQueue], ^{
            [weakSelf readNextBuffer];
        });
        return;
    }
    _currentVideoTime += presentationDifference;
    _currentMediaTime = CACurrentMediaTime();
    
    Float64 delta = fabs(_currentMediaTime - _currentVideoTime);
    if (delta > 0.5) {
        CFRelease(sampleBuffer);
        dispatch_async([weakSelf frameQueue], ^{
            [weakSelf readNextBuffer];
        });
        return;
    }
    int64_t presentationDifferenceRound = lroundf(presentationDifference * NSEC_PER_SEC);
    
    __block dispatch_source_t timer = [self createStrictTimer];
    // Strict timer that will fire |presentationDifferenceRound| ns from now and never again.
    dispatch_source_set_timer(timer,
                              dispatch_time(DISPATCH_TIME_NOW, presentationDifferenceRound),
                              DISPATCH_TIME_FOREVER,
                              0);
    dispatch_source_set_event_handler(timer, ^{
        dispatch_source_cancel(timer);
        timer = nil;
        
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (!pixelBuffer) {
            CFRelease(sampleBuffer);
            dispatch_async([weakSelf frameQueue], ^{
                [weakSelf readNextBuffer];
            });
            return;
        }
        
        [self.delegate didOutputSampleBuffer:sampleBuffer];
        dispatch_async([weakSelf frameQueue], ^{
            [self readNextBuffer];
        });

    });
    if (@available(iOS 10.0, *)) {
        dispatch_activate(timer);
    } else {
        // Fallback on earlier versions
    }
}

- (dispatch_source_t)createStrictTimer {
    dispatch_source_t timer = dispatch_source_create(
                                                     DISPATCH_SOURCE_TYPE_TIMER, 0, DISPATCH_TIMER_STRICT, [self frameQueue]);
    return timer;
}

- (void)dealloc {
    [self stopCapture];
}
@end
