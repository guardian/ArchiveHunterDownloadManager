//
//  DownloadTaskDelegate.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 08/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "DownloadTaskDelegate.h"
#import "BulkOperations.h"

@implementation DownloadTaskDelegate

- (id) init {
    self = [super init];
    return self;
}

- (id) initWithDownloadEntity:(NSManagedObject *)target {
    self = [super init];
    [self setDownloadItem:target];
    return self;
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location
{
    [[self downloadItem] setValue:[NSNumber numberWithInteger:BO_COMPLETED] forKey:@"status"];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    double progress = (double)totalBytesWritten / [(NSNumber *)[[self downloadItem] valueForKey:@"fileSize"]doubleValue];
    [[self downloadItem] setValue:[NSNumber numberWithDouble:progress] forKey:@"downloadProgress"];
}

@end
