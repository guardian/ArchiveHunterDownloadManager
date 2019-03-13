//
//  DownloadQueueEntry.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 12/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "DownloadQueueEntry.h"

@implementation DownloadQueueEntry
@synthesize retryCount;

- (id) initWithEntry:(NSManagedObject *)entry
{
    self = [super init];
    _managedObject = entry;
    return self;
}
@end
