//
//  NotificationsHelper.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 11/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NotificationsHelper : NSObject
+ (void)showBulkCompletedNotification:(NSManagedObject *)bulk;
+ (void)showBulkFailedNotification:(NSManagedObject *)bulk;
+ (void)showPartialFailedNotification:(NSManagedObject *)bulk;
@end
