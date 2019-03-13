//
//  DownloadDelegate.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 08/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DownloadDelegate : NSObject <NSURLDownloadDelegate>
@property (weak, atomic) NSManagedObject *entry;
@property (weak, atomic) NSNumber *downloadedSoFar;
@property (readonly) dispatch_queue_t replyQueue;
@property (strong, readonly) id downloadQueueManager;

- (id)init:(dispatch_queue_t)queue;
- (id)initWithEntry:(NSManagedObject *)entry dispatchQueue:(dispatch_queue_t)queue withManager:(id)downloadQueueManager;

- (void)downloadDidBegin:(NSURLDownload *)download;
- (void)download:(NSURLDownload *)download didCreateDestination:(NSString *)path;
- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length;
- (BOOL)download:(NSURLDownload *)download shouldDecodeSourceDataOfMIMEType:(NSString *)encodingType;
- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error;
- (void)downloadDidFinish:(NSURLDownload *)download;
@end
