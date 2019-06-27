//
//  DownloadQueueManager.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 12/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "QueueManager.h"


@interface DownloadQueueManager : QueueManager
- (id) init;
- (id) initWithConcurrency:(NSUInteger) concurrency;

- (void)informCompleted:(NSManagedObject *)entry toFilePath:(NSString *)filePath bulkOperationStatus:(NSUInteger)status shouldRetry:(BOOL)shouldRetry;

@property (nonatomic, copy, nullable) void (^completedCallback)(NSManagedObject *, NSString *, NSUInteger, BOOL);
@end
