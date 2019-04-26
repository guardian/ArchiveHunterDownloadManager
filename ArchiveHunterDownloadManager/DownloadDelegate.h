//
//  DownloadDelegate.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 08/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/**
 this started life as an NSURLDownloadDelegate, but has been modified since moving to libcurl
 */
@interface DownloadDelegate : NSObject
@property (weak, atomic) NSManagedObject *entry;
@property (weak, atomic) NSNumber *downloadedSoFar;
@property (readonly) dispatch_queue_t replyQueue;
@property (strong, readonly) id downloadQueueManager;
@property NSUInteger updateDivider; //only update UI on this after this many library updates
@property NSUInteger _updateCounter;

- (id)init:(dispatch_queue_t)queue;
- (id)initWithEntry:(NSManagedObject *)entry dispatchQueue:(dispatch_queue_t)queue withManager:(id)downloadQueueManager;

- (void)downloadDidBegin:(NSURL *)url;
- (void)download:(NSURL *)url didCreateDestination:(NSString *)path;
- (void)download:(NSURL *)url downloadedBytes:(NSNumber *)bytes fromTotal:(NSNumber *)total inSeconds:(time_t)seconds withData:(id)data;
- (void)download:(NSURL *)url didFailWithError:(NSError *)error;
- (void)downloadDidFinish:(NSURL *)url;
@end
