//
//  DownloadQueueManager.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 12/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum queueStatus {
    Q_WAITING=0,
    Q_BUSY,
    Q_FULL
} QueueStatus;

@interface DownloadQueueManager : NSObject
@property (readonly) QueueStatus status;
@property (readwrite) NSUInteger concurrency;

- (id) init;
- (id) initWithConcurrency:(NSUInteger) concurrency;
- (void)addToQueue:(NSManagedObject *)entry;
- (void)informCompleted:(NSManagedObject *)entry bulkOperationStatus:(NSUInteger)status shouldRetry:(BOOL)shouldRetry;
@end
