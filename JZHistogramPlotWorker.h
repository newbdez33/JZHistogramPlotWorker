//
//  JZHistogramPlotWorker.h
//  podbean
//
//  Created by JackyZ on 14/7/2016.
//  Copyright © 2016 Podbean. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TheAmazingAudioEngine.h"

@interface JZHistogramPlotWorker : NSObject<AEAudioReceiver>

/// The upper bound of the frequency range the audio plot will display. Default:
/// 10000Hz
@property (nonatomic) float maxFrequency;

/// The lower bound of the frequency range the audio plot will display. Default:
/// 1200Hz
@property (nonatomic) float minFrequency;

/// The number of bins in the audio plot. Default: 30
@property (nonatomic) NSUInteger numOfBins;

/// The padding of each bin in percent width. Default: 0.1
@property (nonatomic) CGFloat padding;

/// The gain applied to the height of each bin. Default: 10
@property (nonatomic) CGFloat gain;

/// A float that specifies the vertical gravitational acceleration applied to
/// each bin. Default: 10 pixel/sec^2
@property (nonatomic) float gravity;


@property (nonatomic) CGFloat currentHeight;

- (void)setSampleData:(float *)data length:(int)length;

@end
