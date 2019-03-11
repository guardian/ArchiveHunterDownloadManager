//
//  BulkDownloadStats.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 11/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BulkDownloadStats : NSObject
@property (weak, readwrite, atomic) NSManagedObject *bulk;

@property (readonly) NSInteger totalCount;
@property (readonly) NSInteger successCount;
@property (readonly) NSInteger errorCount;
@property (readonly) NSInteger waitingCount;
@property (readonly) NSInteger runningCount;
@property (readonly) NSInteger readyCount;
@property (readonly) NSInteger invalidCount;

- (id)init;
- (id)initWithBulk:(NSManagedObject *)bulk;
- (void)countup;
@end
