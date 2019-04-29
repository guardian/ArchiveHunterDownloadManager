//
//  DownloadQueueManager.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 12/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "DownloadQueueManager.h"
#import "DownloadQueueEntry.h"
#import "BulkOperations.h"
#import "ServerComms.h"
#import "EtagCalculator.h"

@implementation DownloadQueueManager
dispatch_queue_t checksumQueue;

ServerComms *serverComms;

- (id)init
{
    self = [super init];
    serverComms = [[ServerComms alloc] init];
    checksumQueue = dispatch_queue_create("ChecksumQueue", nil);
    return self;
}

- (id) initWithConcurrency:(NSUInteger) concurrency
{
    self = [super init];
    serverComms = [[ServerComms alloc] init];
    checksumQueue = dispatch_queue_create("ChecksumQueue", nil);
    return self;
}

/**
 read the user defaults and build a URL to get the download URL from the server
 */
- (NSURL *_Nullable) getRetrievalLinkUrl:(NSString *)entryId withRetrievalToken:(NSString *)retrievalToken {
    NSString *hostName = [[NSUserDefaults standardUserDefaults] valueForKey:@"serverHost"];
    if(!hostName){
        NSLog(@"ERROR: You need to set the hostname");
        return nil;
    }
    
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/bulk/%@/get/%@", hostName, retrievalToken, entryId]];
}



/**
 actually do an item download
 */
- (BOOL) performItemAction:(NSManagedObject *)entry {
    NSLog(@"performItemDownload");
    BulkOperationStatus entryStatus = (BulkOperationStatus)[(NSNumber *)[entry valueForKey:@"status"] integerValue];
    if(entryStatus!=BO_READY && entryStatus!=BO_ERRORED){
        NSLog(@"Can't start a download in state %d", entryStatus);
        return FALSE;
    }
    
    NSManagedObject *parent = [entry valueForKey:@"parent"];
    NSString *retrievalToken = [parent valueForKey:@"retrievalToken"];
    NSURL *retrievalLink = [self getRetrievalLinkUrl:[entry valueForKey:@"fileId"] withRetrievalToken:retrievalToken];
    
    if(!retrievalLink) {
        NSLog(@"Could not get retrieval URL for %@", [entry valueForKey:@"name"]);
        return FALSE;
    }
    
    NSURLSessionDataTask *retrievalTask = [serverComms itemRetrievalTask:retrievalLink forEntry:entry
                                                       completionHandler:^(NSURL * _Nullable downloadUrl, NSError * _Nullable err) {
                                                           if(err){
                                                               NSLog(@"failed to start download: %@", err);
                                                               [self removeFromQueue:entry];
                                                               [self pullNextItem];
                                                           } else {
                                                               BOOL result = [serverComms performItemDownload:downloadUrl forEntry:entry manager:self];
                                                               if(!result){
                                                                   NSLog(@"Failed to start download.");
                                                                   [self removeFromQueue:entry];
                                                                   [self pullNextItem];
                                                               }
                                                           }
    
    }];
    
    [retrievalTask resume];
    return TRUE;
}

/**
 called by BulkOperations to inform us that something finished
 */
- (void)informCompleted:(NSManagedObject *)entry
             toFilePath:(NSString *)filePath
    bulkOperationStatus:(BulkOperationStatus)status
            shouldRetry:(BOOL)shouldRetry
{
    dispatch_async([self _commandDispatchQueue], ^{
        NSUInteger matchingIndex;
        NSIndexSet *fullSet;
        DownloadQueueEntry *queueEntry;
        
        fullSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[self _activeItems] count])];
        
        matchingIndex = [fullSet indexWithOptions:NSEnumerationConcurrent
                                      passingTest:^BOOL (NSUInteger idx, BOOL *stop){
                                          DownloadQueueEntry  *indexPtr = [[self _activeItems] objectAtIndex:idx];
                                          
                                          return [[indexPtr managedObject] valueForKey:@"fileId"]==[entry valueForKey:@"fileId"];
                                      }];
        if(matchingIndex==-1 | matchingIndex>[[self _activeItems] count]){
            NSLog(@"could not find a matching item for %@ in the active items list", entry);
            [self pullNextItem];
            return;
        }
        
        switch(status){
            case BO_WAITING_CHECKSUM:
                [[self _activeItems] removeObjectAtIndex:matchingIndex];
                [self startChecksum:entry forFilePath:filePath];
                break;
            case BO_COMPLETED:
                //completed, just remove from the active queue
                [[self _activeItems] removeObjectAtIndex:matchingIndex];
            
                break;
            case BO_ERRORED:
                //errored, if we want to retry bump the retry index and requeue
                queueEntry = (DownloadQueueEntry *)[[self _activeItems] objectAtIndex:matchingIndex];
                [[self _activeItems] removeObjectAtIndex:matchingIndex];
                if(shouldRetry){
                    [queueEntry setRetryCount:[NSNumber numberWithInteger:[[queueEntry retryCount] integerValue]+1]];
                }
                break;
            default:
                NSLog(@"informCompleted called for an object in state %d which is not completed!", status);
        }
        [self pullNextItem];
    });
}

- (NSUInteger) getChecksumThreads
{
    NSNumber *prefsValue = [[NSUserDefaults standardUserDefaults] valueForKey:@"checksumThreads"];
    if(prefsValue){
        return [prefsValue unsignedIntegerValue];
    } else {
        return 4;
    }
}

- (void)startChecksum:(NSManagedObject *)entry forFilePath:(NSString *)filePath
{
    dispatch_async(checksumQueue, ^{
        NSError *err=nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [entry setValue:[NSNumber numberWithInt:BO_VALIDATING_CHECKSUM] forKey:@"status"];
        });
        
        NSInteger likelyChunkSize = [EtagCalculator estimateLikelyChunksizeForFilesize:[entry valueForKey:@"fileSize"]
                                                                       andExistingEtag:[entry valueForKey:@"eTag"]];
        NSLog(@"likely chunk size is %lu", likelyChunkSize);
        
        EtagCalculator *calc = [[EtagCalculator alloc] initForFilepath:filePath
                                                          forChunkSize:likelyChunkSize
                                                           withThreads:[self getChecksumThreads]];
        NSString *etag = [calc executeWithError:&err];
        if(!etag){
            NSLog(@"eTag verification on %@ failed: %@", filePath, err);
            dispatch_async(dispatch_get_main_queue(), ^{
                [entry setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [err localizedDescription], @"lastError",
                                                     [NSNumber numberWithInt:BO_VALIDAION_FAILED], @"status",
                                                     nil]];
            });
        } else {
            NSLog(@"Calculated etag %@ for %@", etag, [entry valueForKey:@"path"]);
            dispatch_async(dispatch_get_main_queue(), ^{
                [entry setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSString stringWithFormat:@"%@/%@", [entry valueForKey:@"eTag"], etag], @"eTag",
                                                       [NSNumber numberWithInt:BO_COMPLETED], @"status",
                                                       nil]];
            });
        }
    });
}
@end
