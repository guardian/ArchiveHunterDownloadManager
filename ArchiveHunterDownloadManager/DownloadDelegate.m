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
    
    NSNumber* updateDividerCurrentValue = [[NSUserDefaults standardUserDefaults] valueForKey:@"uiUpdateDivider"];
    if(updateDividerCurrentValue){
        _updateDivider = [updateDividerCurrentValue integerValue];
    } else {
        _updateDivider = 100;
    }
    NSLog(@"UI update divider is %lu", _updateDivider);
    __updateCounter=0;
    
    return self;
}

- (id)initWithEntry:(NSManagedObject *)entry dispatchQueue:(dispatch_queue_t)queue withManager:(id)downloadQueueManager
{
    self = [super init];
    _replyQueue = queue;
    _entry = entry;
    _downloadedSoFar = [NSNumber numberWithLongLong:0];
    _downloadQueueManager = downloadQueueManager;
    NSNumber* updateDividerCurrentValue = [[NSUserDefaults standardUserDefaults] valueForKey:@"uiUpdateDivider"];
    if(updateDividerCurrentValue){
        _updateDivider = [updateDividerCurrentValue integerValue];
    } else {
        _updateDivider = 100;
    }
    NSLog(@"UI update divider is %lu", _updateDivider);
    
    __updateCounter=0;
    return self;
}

- (void)downloadDidBegin:(NSURL *)url withEtag:(NSString *)etag
{
    NSLog(@"%@ download started", [[self entry] valueForKey:@"destinationFile"]);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self entry] setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      @"",@"lastError",
                                                      [NSNumber numberWithInt:BO_RUNNING], @"status",
                                                      etag, @"eTag",
                                                      nil]];
    });
    
}

- (void)download:(NSURL *)url didCreateDestination:(NSString *)path
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"%@ created file for download: %@", [[self entry] valueForKey:@"destinationFile"], path);
    });
}

- (void)download:(NSURL *)url downloadedBytes:(NSNumber *)bytes fromTotal:(NSNumber *)total inSeconds:(time_t)seconds withData:(id)data
{

    NSNumber *newProgress = [NSNumber numberWithDouble:[bytes doubleValue] / [total doubleValue]];
    
    NSNumber *newBps;
    if(seconds>0){
        newBps = [NSNumber numberWithDouble:[bytes doubleValue]/(double)seconds];
    } else {
        newBps = nil;
    }
    
    ++__updateCounter;
    if(__updateCounter>_updateDivider || [bytes longLongValue]==[total longLongValue]){
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *err=NULL;
            NSManagedObject *bulk = [[self entry] valueForKey:@"parent"];
            long long currentProgress = [(NSNumber *)[bulk valueForKey:@"amountDownloaded"] longLongValue];
            
            [bulk setValue:[NSNumber numberWithLongLong:currentProgress+[bytes longLongValue]] forKey:@"amountDownloaded"];
            
            [[self entry] setValue:newProgress forKey:@"downloadProgress"];
            [[self entry] setValue:newBps forKey:@"downloadSpeedBytes"];
//            [[bulk managedObjectContext] save:&err];
//            if(err){
//                NSLog(@"Could not save bulk data: %@", err);
//            }
        });
        if(__updateCounter>_updateDivider) __updateCounter=0;
    }
}


- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
    

    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Download %@ failed with error %@", [[self entry] valueForKey:@"destinationFile"], error);
        NSString *errorString = [NSString stringWithFormat:@"%@", error];
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"File Download Error"];
        
        NSString *truncatedErrorString = [errorString length]>256 ? [errorString substringToIndex:256] : errorString;
        
        [alert setInformativeText:[NSString stringWithFormat:@"A file download error occured: %@", truncatedErrorString]];
        [alert addButtonWithTitle:@"Okay"];
        [alert runModal];
    
        [[self entry] setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      [error localizedDescription],@"lastError",
                                                      [NSNumber numberWithInt:BO_ERRORED], @"status",
                                                      nil, @"downloadSpeedBytes",
                                                      nil]];
        [(DownloadQueueManager *)_downloadQueueManager informCompleted:[self entry]
                                                   bulkOperationStatus:BO_ERRORED
                                                           shouldRetry:FALSE];
    });
    
    dispatch_async(_replyQueue, ^{
        //this should perform the MOC save
        [BulkOperations updateMasterOnItemComplete:[self entry]];
    });
    
}

- (void)downloadDidFinish:(NSURLDownload *)download toFilePath:(NSString *)filePath
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self entry] setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      @"",@"lastError",
                                                      [NSNumber numberWithInt:BO_WAITING_CHECKSUM], @"status",
                                                      nil, @"downloadSpeedBytes",
                                                      nil]];
        [(DownloadQueueManager *)_downloadQueueManager informCompleted:[self entry]
                                                            toFilePath:filePath
                                                   bulkOperationStatus:BO_WAITING_CHECKSUM
                                                           shouldRetry:FALSE];
        dispatch_async(_replyQueue, ^{
            [BulkOperations updateMasterOnItemComplete:[self entry]];
        });
        
    });
    

}

@end
