//
//  DownloadDelegate.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 08/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "DownloadDelegate.h"
#import "BulkOperations.h"
#import "DownloadQueueManager.h"

@implementation DownloadDelegate
- (id)init:(dispatch_queue_t)queue
{
    self = [super init];
    _replyQueue = queue;
    _downloadedSoFar = [NSNumber numberWithLongLong:0];
    _entry = nil;
    return self;
}

- (id)initWithEntry:(NSManagedObject *)entry dispatchQueue:(dispatch_queue_t)queue withManager:(id)downloadQueueManager
{
    self = [super init];
    _replyQueue = queue;
    _entry = entry;
    _downloadedSoFar = [NSNumber numberWithLongLong:0];
    _downloadQueueManager = downloadQueueManager;
    return self;
}

- (void)downloadDidBegin:(NSURLDownload *)download
{
    NSLog(@"%@ download started", [[self entry] valueForKey:@"destinationFile"]);
    [[self entry] setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  @"",@"lastError",
                                                  [NSNumber numberWithInt:BO_RUNNING], @"status"
                                                  ,nil]];
    
}

- (void)download:(NSURLDownload *)download didCreateDestination:(NSString *)path
{
    NSLog(@"%@ created file for download: %@", [[self entry] valueForKey:@"destinationFile"], path);
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length
{
//    NSLog(@"download received data of length %lu", length);
    
    [self setDownloadedSoFar:[NSNumber numberWithLongLong:[[self downloadedSoFar] longLongValue]+length]];
    NSNumber *totalSize = (NSNumber *)[[self entry] valueForKey:@"fileSize"];
    
    NSNumber *newProgress = [NSNumber numberWithDouble:[[self downloadedSoFar] doubleValue] / [totalSize doubleValue]];
    
    //NSLog(@"downloadedSoFar: %@ totalSize %@ newProgress %@", _downloadedSoFar, totalSize, newProgress);
    [[self entry] setValue:newProgress forKey:@"downloadProgress"];
}

//we don't want to decode anything automatically
- (BOOL)download:(NSURLDownload *)download shouldDecodeSourceDataOfMIMEType:(NSString *)encodingType
{
    NSLog(@"%@ shouldDecode", [[self entry] valueForKey:@"destinationFile"]);
    return NO;
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
    NSLog(@"Download %@ failed with error %@", [[self entry] valueForKey:@"destinationFile"], error);

    NSString *errorString = [NSString stringWithFormat:@"%@", error];
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"File Download Error"];
    [alert setInformativeText:[NSString stringWithFormat:@"A file download error occured: %@", [errorString substringToIndex:256]]];
    [alert addButtonWithTitle:@"Okay"];
    [alert runModal];
    
    [[self entry] setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [error localizedDescription],@"lastError",
                                                  [NSNumber numberWithInt:BO_ERRORED], @"status"
                                                  ,nil]];
    [(DownloadQueueManager *)_downloadQueueManager informCompleted:[self entry]
                                               bulkOperationStatus:BO_ERRORED
                                                       shouldRetry:FALSE];
    
    dispatch_async(_replyQueue, ^{
        //this should perform the MOC save
        [BulkOperations updateMasterOnItemComplete:[self entry]];
    });
    
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
    NSLog(@"Download %@ completed", [download request]);
    
    [[self entry] setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  @"",@"lastError",
                                                  [NSNumber numberWithInt:BO_COMPLETED], @"status"
                                                  ,nil]];
    
    [(DownloadQueueManager *)_downloadQueueManager informCompleted:[self entry]
                                               bulkOperationStatus:BO_COMPLETED
                                                       shouldRetry:FALSE];
    dispatch_async(_replyQueue, ^{
        [BulkOperations updateMasterOnItemComplete:[self entry]];
    });
}

@end
