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

- (id) init {
    self = [super init];
    _serverComms = [[ServerComms alloc] init];
    return self;
}

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
    NSError *err=nil;
    NSString *downloadPath = [self getDownloadPath:bulk];
    
    NSLog(@"downloadPath is %@", downloadPath);

    if(downloadPath && [downloadPath length]>0){
        BOOL isDir;
        BOOL exists = [[NSFileManager  defaultManager] fileExistsAtPath:downloadPath isDirectory:&isDir];
        if(exists && isDir){
            [self prepareBulkEntries:bulk withError:&err];
            [bulk setValue:[NSNumber numberWithInteger:BO_READY] forKey:@"status"];
            
            BulkOperationStatus st = [self kickoffBulks:bulk withError:&err];
            if(st!=BO_READY){
                NSLog(@"Could not start kickoff: %@", err);
            }
            return st;
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

+ (BOOL) bulkForAll:(NSManagedObjectContext *)moc withError:(NSError **)err block:(void (^)(NSManagedObject *))block {
    //query CoreData for all BulkDownloads
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"BulkDownload"];
    
    NSArray *results = [moc executeFetchRequest:req error:err];
    
    if(!results) return NO; //caller should already have the error through withError parameter
    
    for(NSManagedObject *entry in results){
        block(entry);
    }
    return YES;
}

+ (BOOL) bulkForEach:(NSManagedObject *)bulk managedObjectContext:(NSManagedObjectContext *)moc withError:(NSError **)err block:(void (^)(NSManagedObject *))block {
    //query CoreData for all Downloadentities for this bulk
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"DownloadEntity"];
    
    [req setPredicate:[NSPredicate predicateWithFormat:@"parent == %@", bulk]];
    NSArray *results = [moc executeFetchRequest:req error:err];
    NSLog(@"bulkForEach got %@ from %@", results, bulk);
    
    if(!results) return NO; //caller should already have the error through withError parameter
    
    for(NSManagedObject *entry in results){
        block(entry);
    }
    return YES;
}

- (BOOL) prepareBulkEntries:(NSManagedObject *)bulk withError:(NSError **)err {
    return [BulkOperations bulkForEach:bulk managedObjectContext:_moc withError:err block:^(NSManagedObject *entry){
        [self setupDownloadEntry:entry withBulk:bulk];
    }];
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

- (BulkOperationStatus) kickoffBulks:(NSManagedObject *)bulk withError:(NSError **)err {
    BulkOperationStatus status = (BulkOperationStatus)[(NSNumber *)[bulk valueForKey:@"status"] integerValue];
    if(status!=BO_READY && status!=BO_ERRORED){
        NSLog(@"Can't start a bulk operation in state %d", status);
        return status;
    }
    
    [bulk setValue:[NSNumber numberWithInteger:BO_RUNNING] forKey:@"status"];
    
    dispatch_queue_t targetQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    BOOL result = [BulkOperations bulkForEach:bulk managedObjectContext:_moc withError:err block:^(NSManagedObject *entry){
        dispatch_async(targetQueue, ^{
            [self performItemDownload:entry];
        });
    }];
    
    if(result){
        return BO_RUNNING;
    } else {
        return BO_ERRORED;
    }
}

/**
 actually do an item download
 */
- (void) performItemDownload:(NSManagedObject *)entry {
    BulkOperationStatus entryStatus = (BulkOperationStatus)[(NSNumber *)[entry valueForKey:@"status"] integerValue];
    if(entryStatus!=BO_READY && entryStatus!=BO_ERRORED){
        NSLog(@"Can't start a download in state %d", entryStatus);
        return;
    }
    
    NSManagedObject *parent = [entry valueForKey:@"parent"];
    NSString *retrievalToken = [parent valueForKey:@"retrievalToken"];
    NSURL *retrievalLink = [self getRetrievalLinkUrl:[entry valueForKey:@"fileId"] withRetrievalToken:retrievalToken];
    
    if(!retrievalLink) return;
    
    NSURLSessionDataTask *retrievalTask = [[self serverComms] itemRetrievalTask:retrievalLink forEntry:entry];
    
    [retrievalTask resume];
}

- (NSURL *_Nullable) getRetrievalLinkUrl:(NSString *)entryId withRetrievalToken:(NSString *)retrievalToken {
    NSString *hostName = [[NSUserDefaults standardUserDefaults] valueForKey:@"serverHost"];
    if(!hostName){
        NSLog(@"ERROR: You need to set the hostname");
        return nil;
    }
    
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/bulk/%@/get/%@", hostName, retrievalToken, entryId]];
}
@end
