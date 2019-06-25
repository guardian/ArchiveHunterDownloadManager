//
//  DownloadRateTransformer.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 26/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "DownloadRateTransformer.h"

@implementation DownloadRateTransformer

- (NSArray<NSString*>*) sizeTokens {
    return [NSArray arrayWithObjects:@"B/s",@"KB/s",@"MB/s",@"GB/s",@"TB/s",nil];
}

@end
