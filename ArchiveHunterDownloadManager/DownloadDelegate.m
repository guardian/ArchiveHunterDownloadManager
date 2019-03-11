//
//  DownloadDelegate.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 08/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "DownloadDelegate.h"
#import "BulkOperations.h"

@implementation DownloadDelegate
- (id)init
{
    self = [super init];
    _downloadedSoFar = [NSNumber numberWithLongLong:0];
    _entry = nil;
    return self;
}

- (id)initWithEntry:(NSManagedObject *)entry
{
    self = [super init];
    _entry = entry;
    _downloadedSoFar = [NSNumber numberWithLongLong:0];
    return self;
}

- (void)downloadDidBegin:(NSURLDownload *)download
{
    NSLog(@"download started: %@", [[download request] URL]);
    [[self entry] setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  @"",@"lastError",
                                                  [NSNumber numberWithInt:BO_RUNNING], @"status"
                                                  ,nil]];
    
}

- (void)download:(NSURLDownload *)download didCreateDestination:(NSString *)path
{
    NSLog(@"created file for download: %@", path);
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length
{
    NSLog(@"download received data of length %lu", length);
    
    [self setDownloadedSoFar:[NSNumber numberWithLongLong:[[self downloadedSoFar] longLongValue]+length]];
    NSNumber *totalSize = (NSNumber *)[[self entry] valueForKey:@"fileSize"];
    
    NSNumber *newProgress = [NSNumber numberWithDouble:[[self downloadedSoFar] doubleValue] / [totalSize doubleValue]];
    
    NSLog(@"downloadedSoFar: %@ totalSize %@ newProgress %@", _downloadedSoFar, totalSize, newProgress);
    [[self entry] setValue:newProgress forKey:@"downloadProgress"];
}

//we don't want to decode anything automatically
- (BOOL)download:(NSURLDownload *)download shouldDecodeSourceDataOfMIMEType:(NSString *)encodingType
{
    return NO;
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
    NSLog(@"Download %@ failed with error %@", [download request], error);
    
    [[self entry] setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [error localizedDescription],@"lastError",
                                                  [NSNumber numberWithInt:BO_ERRORED], @"status"
                                                  ,nil]];
    
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
    NSLog(@"Download %@ completed", [download request]);
    
    [[self entry] setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  @"",@"lastError",
                                                  [NSNumber numberWithInt:BO_COMPLETED], @"status"
                                                  ,nil]];
}

@end
