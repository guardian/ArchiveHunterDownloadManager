//
//  BulkDownloadStats.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 11/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "BulkDownloadStats.h"
#import "BulkOperations.h"

@implementation BulkDownloadStats

- (id)init
{
    self = [super init];
    _totalCount=0;
    _successCount=0;
    _errorCount=0;
    _waitingCount=0;
    return self;
}

- (id)initWithBulk:(NSManagedObject *)bulk
{
    self = [super init];
    _bulk = bulk;
    _totalCount=0;
    _successCount=0;
    _errorCount=0;
    _waitingCount=0;
    [self countup];
    return self;
}

- (void)countup
{
    for(NSManagedObject *entry in [[self bulk] valueForKey:@"entities"]){
        ++_totalCount;
        BulkOperationStatus status = [(NSNumber *)[entry valueForKey:@"status"] intValue];
        switch(status){
            case BO_COMPLETED:
                _successCount++;
                break;
            case BO_ERRORED:
                _errorCount++;
                break;
            case BO_READY:
                _readyCount++;
                break;
            case BO_RUNNING:
                _runningCount++;
            case BO_WAITING_USER_INPUT:
                _waitingCount++;
            case BO_INVALID:
                _invalidCount++;
            case BO_PARTIAL:
                //not relevant for items
                break;
        }
    }
}
@end
