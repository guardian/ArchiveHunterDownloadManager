//
//  HttpHeadInfo.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "HttpHeadInfo.h"

@implementation HttpHeadInfo
@synthesize eTag;
@synthesize size;
@synthesize modTime;

@synthesize acceptRanges;
@synthesize contentType;
@synthesize server;

@synthesize proto;
@synthesize statusCode;
@synthesize statusString;

- (void) dumpForDebug
{
    NSLog(@"eTag: %@", eTag);
    NSLog(@"Size: %@", size);
    NSLog(@"modTime: %@", modTime);
    NSLog(@"Accept Ranges: %@", acceptRanges);
    NSLog(@"Content Type: %@", contentType);
    NSLog(@"Server: %@", server);  
}
@end
