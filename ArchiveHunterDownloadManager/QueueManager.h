//
//  QueueManager.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 26/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DownloadQueueEntry.h"

typedef enum queueStatus {
    Q_WAITING=0,
    Q_BUSY,
    Q_FULL
} QueueStatus;

@interface QueueManager : NSObject
@property (readonly) QueueStatus status;
@property (readwrite) NSUInteger concurrency;

//internal properties
@property NSMutableArray<DownloadQueueEntry *> *_waitingQueue;
@property NSMutableArray<DownloadQueueEntry *> *_activeItems;
//we use a serial queue to ensure that multithreaded options don't screw us up
@property dispatch_queue_t _commandDispatchQueue;

//public methods
- (id) init;
- (id) initWithConcurrency:(NSUInteger) concurrency;
- (void)addToQueue:(NSManagedObject *)entry;
- (void)removeFromQueue:(NSManagedObject *)entry;

//internal methods
- (void)pullNextItem;

//override these in a subclass to actually do something
- (BOOL) performItemAction:(NSManagedObject *)entry;
- (void)informCompleted:(NSManagedObject *)entry bulkOperationStatus:(NSUInteger)status shouldRetry:(BOOL)shouldRetry;
@end

