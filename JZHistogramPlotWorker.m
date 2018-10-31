//
//  JZHistogramPlotWorker.m
//  podbean
//
//  Created by JackyZ on 14/7/2016.
//  Copyright © 2016 Podbean. All rights reserved.
//

#import "JZHistogramPlotWorker.h"
#import "TheAmazingAudioEngine.h"
#import <Accelerate/Accelerate.h>
#include <libkern/OSAtomic.h>
#import <AVFoundation/AVFoundation.h>

const Float32 kAdjust0DB_jz = 1.5849e-13;

#define kBufferLength 2048 // In frames; higher values mean oscilloscope spans more time
#define kMaxConversionSize 4096

@interface JZHistogramPlotWorker () {
    
    AudioBufferList *_conversionBuffer;
    
    // ftt setup
    FFTSetup fftSetup;
    COMPLEX_SPLIT A;
    int log2n, n, nOver2;
    float sampleRate, *dataBuffer;
    size_t bufferCapacity, index;
    
    // buffers
    float *heightsByFrequency, *speeds, *times, *tSqrts, *vts, *deltaHeights;
}

@property (nonatomic, strong) AEFloatConverter *floatConverter;
@property (strong, nonatomic) NSMutableArray *heightsByTime;

@end

@implementation JZHistogramPlotWorker

@synthesize numOfBins;
@synthesize gain;

#pragma mark - Update Buffers
- (void)setSampleData:(float *)data length:(int)length {
    // fill the buffer with our sampled data. If we fill our buffer, run the
    // fft.
    int inNumberFrames = length;
    int read = (int)(bufferCapacity - index);
    if (read > inNumberFrames) {
        memcpy((float *)dataBuffer + index, data,
               inNumberFrames * sizeof(float));
        index += inNumberFrames;
    } else {
        // if we enter this conditional, our buffer will be filled and we should
        // perform the FFT.
        memcpy((float *)dataBuffer + index, data, read * sizeof(float));
        
        // reset the index.
        index = 0;
        
        // fft
        vDSP_ctoz((COMPLEX *)dataBuffer, 2, &A, 1, nOver2);
        vDSP_fft_zrip(fftSetup, &A, 1, log2n, FFT_FORWARD);
        vDSP_ztoc(&A, 1, (COMPLEX *)dataBuffer, 2, nOver2);
        
        // convert to dB
        Float32 one = 1, zero = 0;
        vDSP_vsq(dataBuffer, 1, dataBuffer, 1, inNumberFrames);
        vDSP_vsadd(dataBuffer, 1, &kAdjust0DB_jz, dataBuffer, 1, inNumberFrames);
        vDSP_vdbcon(dataBuffer, 1, &one, dataBuffer, 1, inNumberFrames, 0);
        vDSP_vthr(dataBuffer, 1, &zero, dataBuffer, 1, inNumberFrames);
        
        // aux
        float mul = (sampleRate / bufferCapacity) / 2;
        int minFrequencyIndex = self.minFrequency / mul;
        int maxFrequencyIndex = self.maxFrequency / mul;
        int numDataPointsPerColumn = (maxFrequencyIndex - minFrequencyIndex) / numOfBins;
        float maxHeight = 0;
        
        for (NSUInteger i = 0; i < numOfBins; i++) {
            // calculate new column height
            float avg = 0;
            vDSP_meanv(dataBuffer + minFrequencyIndex +
                       i * numDataPointsPerColumn,
                       1, &avg, numDataPointsPerColumn);
            CGFloat columnHeight = MIN(avg * self.gain, 100-10);
            maxHeight = MAX(maxHeight, columnHeight);
            
            // set column height, speed and time if needed
            if (columnHeight > heightsByFrequency[i]) {
                heightsByFrequency[i] = columnHeight;
                speeds[i] = 0;
                times[i] = 0;
            }
        }
        
        //NSLog(@"max h:%@", @(maxHeight));
        if (_currentHeight < maxHeight) {
            _currentHeight =  maxHeight;
        }

    }
}

- (CGFloat)currentHeight {
    CGFloat ret = _currentHeight;
    _currentHeight = 0;
    //NSLog(@"currentHeight:%@", @(ret));
    return ret;
}

- (void)setupWithAudioController:(AEAudioController *)audioController {
    
    self.floatConverter = [[AEFloatConverter alloc] initWithSourceFormat:audioController.audioDescription];
    _conversionBuffer = AEAllocateAndInitAudioBufferList(_floatConverter.floatingPointAudioDescription, kMaxConversionSize);
    
    // default attributes
    self.maxFrequency = 10000;
    self.minFrequency = 1200;
    self.numOfBins = 30;
    self.padding = 2 / 10.0;
    self.gain = 1;
    self.gravity = 6;
    
    // ftt setup
    dataBuffer = (float *)malloc(kBufferLength * sizeof(float));
    log2n = log2f(kBufferLength);
    n = 1 << log2n;
    assert(n == kBufferLength);
    nOver2 = kBufferLength / 2;
    bufferCapacity = kBufferLength;
    index = 0;
    A.realp = (float *)malloc(nOver2 * sizeof(float));
    A.imagp = (float *)malloc(nOver2 * sizeof(float));
    fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
    
    // configure audio session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    sampleRate = session.sampleRate;
    
    // create buffers
    heightsByFrequency = (float *)calloc(sizeof(float), numOfBins);
    speeds = (float *)calloc(sizeof(float), numOfBins);
    times = (float *)calloc(sizeof(float), numOfBins);
    tSqrts = (float *)calloc(sizeof(float), numOfBins);
    vts = (float *)calloc(sizeof(float), numOfBins);
    deltaHeights = (float *)calloc(sizeof(float), numOfBins);
}

#pragma mark - Callback
-(AEAudioControllerAudioCallback)receiverCallback {
    return &audioCallback;
}

static void audioCallback(__unsafe_unretained JZHistogramPlotWorker *THIS,
                          __unsafe_unretained AEAudioController *audioController,
                          void *source,
                          const AudioTimeStamp *time,
                          UInt32 frames,
                          AudioBufferList *audio) {
    // Convert audio
    AEFloatConverterToFloatBufferList(THIS->_floatConverter, audio, THIS->_conversionBuffer, frames);
    
    // Get a pointer to the audio buffer that we can advance
    float *audioPtr = THIS->_conversionBuffer->mBuffers[0].mData;
    [THIS setSampleData:audioPtr length:frames];
}


@end
