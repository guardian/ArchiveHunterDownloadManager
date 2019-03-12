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

@implementation DownloadQueueManager
NSMutableArray<DownloadQueueEntry *> *_waitingQueue;
NSMutableArray<DownloadQueueEntry *> *_activeItems;
ServerComms *serverComms;

- (id)init
{
    self = [super init];
    serverComms = [[ServerComms alloc] init];
    _waitingQueue = [NSMutableArray array];
    _activeItems = [NSMutableArray array];
    _status = Q_WAITING;
    _concurrency = 4;
    return self;
}

- (id) initWithConcurrency:(NSUInteger) concurrency
{
    self = [super init];
    serverComms = [[ServerComms alloc] init];
    _waitingQueue = [NSMutableArray array];
    _activeItems = [NSMutableArray array];
    _status = Q_WAITING;
    _concurrency = concurrency;
    return self;
}

- (void)addToQueue:(NSManagedObject *)entry
{
    NSLog(@"addToQueue");
    [_waitingQueue addObject:[[DownloadQueueEntry alloc] initWithEntry:entry]];
    [self pullNextItem];
}

/**
 check how many jobs are running and pull from queue if necessary
 */
- (void)pullNextItem
{
    NSLog(@"pullNextItem");
    NSInteger spareCapacity = _concurrency - [_activeItems count];
    NSLog(@"spareCapacity: %lu", spareCapacity);
    
    //we are already running at capacity
    if(spareCapacity<=0){   //spareCapacity could be negative, if the user has reduced the capacity in prefs while downloads are active.
        NSLog(@"No spare capacity available");
        if(_status!=Q_FULL){
            [self willChangeValueForKey:@"status"];
            _status = Q_FULL;
            [self didChangeValueForKey:@"status"];
        }
    } else { //we have spare capacity
        for(NSUInteger n=0;n<spareCapacity;++n){
            DownloadQueueEntry *entry = [_waitingQueue objectAtIndex:0];
            [_waitingQueue removeObjectAtIndex:0];
            if([self performItemDownload:[entry managedObject]]){
                [_activeItems addObject:entry];
            }
        }
    }
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
- (BOOL) performItemDownload:(NSManagedObject *)entry {
    NSLog(@"performItemDownload");
    BulkOperationStatus entryStatus = (BulkOperationStatus)[(NSNumber *)[entry valueForKey:@"status"] integerValue];
    if(entryStatus!=BO_READY && entryStatus!=BO_ERRORED){
        NSLog(@"Can't start a download in state %d", entryStatus);
        return FALSE;
    }
    
    NSManagedObject *parent = [entry valueForKey:@"parent"];
    NSString *retrievalToken = [parent valueForKey:@"retrievalToken"];
    NSURL *retrievalLink = [self getRetrievalLinkUrl:[entry valueForKey:@"fileId"] withRetrievalToken:retrievalToken];
    
    if(!retrievalLink) return FALSE;
    
    NSURLSessionDataTask *retrievalTask = [serverComms itemRetrievalTask:retrievalLink forEntry:entry];
    
    [retrievalTask resume];
    return TRUE;
}

/**
 called by BulkOperations to inform us that something finished
 */
- (void)informCompleted:(NSManagedObject *)entry bulkOperationStatus:(BulkOperationStatus)status shouldRetry:(BOOL)shouldRetry
{
    NSUInteger matchingIndex;
    NSIndexSet *fullSet;
    DownloadQueueEntry *queueEntry;
    
    //find the matching index by pointer equality, should work as we are all in the same process
    fullSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_activeItems count])];
    
    matchingIndex = [fullSet indexWithOptions:NSEnumerationConcurrent
                                  passingTest:^BOOL (NSUInteger idx, BOOL *stop){
                                      id indexPtr = [_activeItems objectAtIndex:idx];
                                      return indexPtr==entry;
                                  }];
    
    switch(status){
        case BO_COMPLETED:
            //completed, just remove from the active queue
            [_activeItems removeObjectAtIndex:matchingIndex];
            break;
        case BO_ERRORED:
            //errored, if we want to retry bump the retry index and requeue
            queueEntry = (DownloadQueueEntry *)[_activeItems objectAtIndex:matchingIndex];
            [_activeItems removeObjectAtIndex:matchingIndex];
            if(shouldRetry){
                [queueEntry setRetryCount:[NSNumber numberWithInteger:[[queueEntry retryCount] integerValue]+1]];
            }
            break;
        default:
            NSLog(@"informCompleted called for an object in state %d which is not completed!", status);
    }
    [self pullNextItem];
}
@end
