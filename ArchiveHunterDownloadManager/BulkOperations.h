//
//  BulkOperations.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 08/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum BulkOperationStatus {
    BO_READY=0,
    BO_RUNNING,
    BO_COMPLETED,
    BO_ERRORED,
    BO_WAITING_USER_INPUT
} BulkOperationStatus;

@interface BulkOperations : NSObject

@property (weak, nonatomic) NSManagedObjectContext *moc;

- (BulkOperationStatus) startBulk:(NSManagedObject *)bulk;
- (BOOL) prepareBulkEntries:(NSManagedObject *)bulk withError:(NSError **)err;
- (void) setupDownloadEntry:(NSManagedObject *)entry withBulk:(NSManagedObject *)bulk;

@end
