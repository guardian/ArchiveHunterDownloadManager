//
//  AppDelegate.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 05/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ServerComms.h"
#import "BulkOperations.h"
#import "DownloadQueueManager.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate>

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readwrite, weak, atomic) IBOutlet NSViewController *mainViewController;
@property (readonly, strong, atomic) DownloadQueueManager *queueManager;

@property (readonly, strong, atomic) ServerComms *serverComms;
@property (readonly, strong, atomic) BulkOperations *bulkOperations;

- (void) asyncSetupDownload:(NSManagedObject *)bulk;
- (void) getEntities:(NSManagedObject *)bulk;
@end

