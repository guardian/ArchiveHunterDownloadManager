//
//  ServerComms.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 07/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DownloadQueueManager.h"

@interface ServerComms : NSObject

- (id _Nonnull)init;

- (BOOL) initiateDownload:(NSString * _Nonnull)token
                withError:(NSError *_Nullable *_Nullable)err
        completionHandler:(void (^ _Nonnull)(NSDictionary *_Nullable data, NSError *_Nullable err))completionBlock;

- (NSURLSessionDataTask *_Nullable) itemRetrievalTask:(NSURL *_Nonnull)retrievalLink
                                             forEntry:(NSManagedObject* _Nonnull)entry
                                    completionHandler:(void (^ _Nonnull)(NSURL* _Nullable downloadUrl, NSError* _Nullable err)) completionBlock;

- (BOOL)performItemDownload:(NSURL* _Nonnull)actualDownloadUrl
                   forEntry:(NSManagedObject* _Nonnull )entry
                    manager:(DownloadQueueManager* _Nonnull )mgr;

- (void)setEntryError:(NSError *)err forEntry:(NSManagedObject *)entry;

@property (atomic, strong) NSURLSession* _Nonnull session;
@property (readonly, strong) dispatch_queue_t _Nonnull replyQueue;
@end
