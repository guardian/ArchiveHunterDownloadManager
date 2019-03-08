//
//  BulkOperations.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 08/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//
#import <Cocoa/Cocoa.h>

#import "BulkOperations.h"

@implementation BulkOperations

- (NSString *_Nullable)getDownloadPath:(NSManagedObject *) bulk {
    @try {
        return [bulk valueForKey:@"destinationPath"];
    } @catch (NSException *exception) {
        NSLog(@"caught exception: %@", exception);
        return nil;
    }
}
- (BulkOperationStatus) startBulk:(NSManagedObject *)bulk {
    /*
     check that the download path exists and is a directory. If not, put us into a waiting state.
     */
    //the valueForKey check fails if there is no value for the key. how to fix?
    NSError *err;
    NSString *downloadPath = [self getDownloadPath:bulk];
    
    NSLog(@"downloadPath is %@", downloadPath);

    if(downloadPath && [downloadPath length]>0){
        BOOL isDir;
        BOOL exists = [[NSFileManager  defaultManager] fileExistsAtPath:downloadPath isDirectory:&isDir];
        if(exists && isDir){
            [self prepareBulkEntries:bulk withError:&err];
            [bulk setValue:[NSNumber numberWithInteger:BO_READY] forKey:@"status"];
            return BO_READY;
        } else {
            [bulk setValue:[NSNumber numberWithInteger:BO_WAITING_USER_INPUT] forKey:@"status"];
            return BO_WAITING_USER_INPUT;   //as a convenience
        }
    } else {
        //downloadpath has not been set yet
        [bulk setValue:[NSNumber numberWithInteger:BO_WAITING_USER_INPUT] forKey:@"status"];
        return BO_WAITING_USER_INPUT;   //as a convenience
    }
}

- (BOOL) prepareBulkEntries:(NSManagedObject *)bulk withError:(NSError **)err {
    //query CoreData for all Downloadentities for this bulk
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"DownloadEntity"];
    
    [req setPredicate:[NSPredicate predicateWithFormat:@"parent == %@", bulk]];
    NSArray *results = [_moc executeFetchRequest:req error:err];
    NSLog(@"prepareBulkEntries got %@", results);
    
    if(!results) return NO; //caller should already have the error through withError parameter
    
    for(NSManagedObject *entry in results){
        [self setupDownloadEntry:entry withBulk:bulk];
    }
    return YES;
}

- (void) setupDownloadEntry:(NSManagedObject *)entry withBulk:(NSManagedObject *)bulk {
    //don't mess with entries that are running or have completed
    if([(NSNumber *)[entry valueForKey:@"status"] integerValue]==BO_COMPLETED ||
       [(NSNumber *)[entry valueForKey:@"status"] integerValue]==BO_RUNNING) return;
    
    //FIXME: should remove common path components.
    NSString *localDestString = [[entry valueForKey:@"path"] stringByAppendingPathComponent:[entry valueForKey:@"name"]];
    
    NSString *fileDestPath = [[bulk valueForKey:@"destinationPath"] stringByAppendingPathComponent:localDestString];
    
    [entry setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                           fileDestPath, @"destinationFile",
                                           [NSNumber numberWithInteger:BO_READY], @"status",
                                           [NSNumber numberWithFloat:0.0], @"downloadProgress", nil]];
    
    
}
@end
