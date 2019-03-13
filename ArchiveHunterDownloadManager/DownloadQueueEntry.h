//
//  DownloadQueueEntry.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 12/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DownloadQueueEntry : NSObject
@property (readonly, strong,atomic) NSManagedObject *managedObject;
@property (readwrite, strong, atomic) NSNumber *retryCount;

- (id) initWithEntry:(NSManagedObject *)entry;

@end
