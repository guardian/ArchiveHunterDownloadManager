//
//  BulkOperations.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 08/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DownloadQueueManager.h"

typedef enum BulkOperationStatus {
    BO_READY=0,
    BO_RUNNING,
    BO_COMPLETED,
    BO_ERRORED,
    BO_PARTIAL,
    BO_WAITING_USER_INPUT,
    BO_INVALID,
    BO_WAITING_CHECKSUM,
    BO_VALIDATING_CHECKSUM,
    BO_VALIDAION_FAILED,
} BulkOperationStatus;

@interface BulkOperations : NSObject

@property (weak, nonatomic) NSManagedObjectContext *moc;
@property (strong, atomic) DownloadQueueManager *qManager;

- (id) init;
- (id) initWithQueueManager:(DownloadQueueManager *)mgr;

+ (BOOL) bulkForEach:(NSManagedObject *)bulk managedObjectContext:(NSManagedObjectContext *)moc withError:(NSError **)err block:(void (^)(NSManagedObject *))block;
+ (BOOL) bulkForAll:(NSManagedObjectContext *)moc withError:(NSError **)err block:(void (^)(NSManagedObject *))block ;
+ (void) updateMasterOnItemComplete:(NSManagedObject *)item;

- (BulkOperationStatus) startBulk:(NSManagedObject *)bulk autoStart:(BOOL)autoStart;
- (BOOL) prepareBulkEntries:(NSManagedObject *)bulk withError:(NSError **)err;
- (void) setupDownloadEntry:(NSManagedObject *)entry withBulk:(NSManagedObject *)bulk;


- (NSString *)stripCommonPathComponents:(NSString *)bulkPath forEntryPath:(NSString *)entryPath;

@end
