//
//  NotificationsHelper.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 11/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "NotificationsHelper.h"

@implementation NotificationsHelper

+ (void)showNotification:(NSString *)body withId:(NSString *_Nullable)identifier withTitle:(NSString *_Nonnull)title withImageNamed:(NSString *)imageName
{
    NSUserNotification *not = [[NSUserNotification alloc] init];
    [not setInformativeText:body];
    [not setTitle:title];
    [not setIdentifier:identifier];
    
    NSUserNotificationCenter *cen = [NSUserNotificationCenter defaultUserNotificationCenter];
    [cen deliverNotification:not];
}

+ (NSString *)bestDescription:(NSManagedObject *)bulk
{
    NSError *matchErr;
    NSRegularExpression *xtractor = [NSRegularExpression regularExpressionWithPattern:@"^([^:]*):(.*)$"
                                                                             options:NSRegularExpressionCaseInsensitive
                                                                               error:&matchErr];
    
    NSString *path = [bulk valueForKey:@"destinationPath"];
    if(path && [path length]>0){
        return [[path lastPathComponent] length]==0 ? path : [path lastPathComponent];
    } else {
        NSString *desc = [bulk valueForKey:@"downloadDescription"];
        NSArray <NSTextCheckingResult *> *matches = [xtractor matchesInString:desc options:0 range:NSMakeRange(0, [desc length])];
        if(!matches || [matches count]<2){
            return desc;
        } else {
            NSString *srcPath = [desc substringWithRange:[[matches objectAtIndex:1] range]];
            return [srcPath lastPathComponent];
        }
    }
}

+ (void)showBulkCompletedNotification:(NSManagedObject *)bulk
{
    NSString *bodyText = [NotificationsHelper bestDescription:bulk];
    NSString *idString = [NSString stringWithFormat:@"%lx", (void *)bulk];
    
    [NotificationsHelper showNotification:bodyText
                                   withId:idString
                                withTitle:@"Media download completed"
                           withImageNamed:@"AppIcon"];
}

+ (void)showBulkFailedNotification:(NSManagedObject *)bulk
{
    NSString *bodyText = [NotificationsHelper bestDescription:bulk];
    NSString *idString = [NSString stringWithFormat:@"%lx", (void *)bulk];
    
    [NotificationsHelper showNotification:bodyText
                                   withId:idString
                                withTitle:@"Media download failed"
                           withImageNamed:@"AppIcon"];
}

+ (void)showPartialFailedNotification:(NSManagedObject *)bulk
{
    NSString *bodyText = [NotificationsHelper bestDescription:bulk];
    NSString *idString = [NSString stringWithFormat:@"%lx", (void *)bulk];
    
    [NotificationsHelper showNotification:bodyText
                                   withId:idString
                                withTitle:@"Some items failed to download"
                           withImageNamed:@"AppIcon"];
}
@end
