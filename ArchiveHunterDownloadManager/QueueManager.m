//
//  QueueManager.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 26/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "QueueManager.h"
#import "DownloadQueueEntry.h"
#import "BulkOperations.h"

@implementation QueueManager

- (id)init
{
    self = [super init];
    __waitingQueue = [NSMutableArray array];
    __activeItems = [NSMutableArray array];
    _status = Q_WAITING;
    _concurrency = 4;
    __commandDispatchQueue = dispatch_queue_create(NULL,nil);
    return self;
}

- (id) initWithConcurrency:(NSUInteger) concurrency
{
    self = [super init];
    __waitingQueue = [NSMutableArray array];
    __activeItems = [NSMutableArray array];
    _status = Q_WAITING;
    _concurrency = concurrency;
    __commandDispatchQueue = dispatch_queue_create(NULL,nil);
    return self;
}

- (void)addToQueue:(NSManagedObject *)entry
{
    dispatch_async(__commandDispatchQueue, ^{
        NSLog(@"addToQueue");
        [__waitingQueue addObject:[[DownloadQueueEntry alloc] initWithEntry:entry]];
        [self pullNextItem];
    });
}

- (void) removeFromQueue:(NSManagedObject *)entry
{
    dispatch_async([self _commandDispatchQueue], ^{
        NSLog(@"removeFromQueue for %@", [entry valueForKey:@"name"]);
        NSIndexSet* fullSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[self _activeItems] count])];
        NSUInteger matchingIndex = [fullSet indexWithOptions:NSEnumerationConcurrent
                                                 passingTest:^BOOL (NSUInteger idx, BOOL *stop){
                                                     DownloadQueueEntry  *indexPtr = [[self _activeItems] objectAtIndex:idx];
                                                     
                                                     return [[indexPtr managedObject] valueForKey:@"fileId"]==[entry valueForKey:@"fileId"];
                                                 }];
        
        NSLog(@"removeFromQueue: index is %lu for %@", matchingIndex, [entry valueForKey:@"name"]);
        if(matchingIndex!=-1) [[self _activeItems] removeObjectAtIndex:matchingIndex];
    });
}

/**
 find a DownloadQueueEntry for the provided archive entry
 returns Null if there is not one in the queue
 */
//- (DownloadQueueEntry *_Nullable)findDownloadEntry:(NSManagedObject *)forSource
//{
//    NSString *sourceFileId = [forSource valueForKey:@"fileId"];
//    
//    for(DownloadQueueEntry *ent in __waitingQueue){
//        NSString *otherFileId = [[ent managedObject] valueForKey:@"fileId"];
//        if([otherFileId compare:sourceFileId]==NSOrderedSame) return ent;
//    }
//    return NULL;
//}

/**
 check how many jobs are running and pull from queue if necessary
 */
- (void)pullNextItem
{
    NSLog(@"pullNextItem");
    NSInteger spareCapacity = [self concurrency] - [__activeItems count];
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
        if([__waitingQueue count]==0){
            [self willChangeValueForKey:@"status"];
            _status = Q_WAITING;
            [self didChangeValueForKey:@"status"];
        } else {
            [self willChangeValueForKey:@"status"];
            _status = Q_BUSY;
            [self didChangeValueForKey:@"status"];
            NSUInteger jobsToPull = [__waitingQueue count]>spareCapacity ? spareCapacity : [__waitingQueue count];
            
            for(NSUInteger n=0;n<jobsToPull;++n){
                DownloadQueueEntry *entry = [__waitingQueue objectAtIndex:0];
                [__waitingQueue removeObjectAtIndex:0];
                if([self performItemAction:[entry managedObject]]){
                    [__activeItems addObject:entry];
                } else {
                    NSLog(@"unable to start download");
                }
            }
        }
    }
}

- (BOOL) performItemAction:(NSManagedObject *)entry {
    return NO;
}

/**
 called by BulkOperations to inform us that something finished
 */
- (void)informCompleted:(NSManagedObject *)entry
    bulkOperationStatus:(BulkOperationStatus)status
            shouldRetry:(BOOL)shouldRetry
{

}

@end
