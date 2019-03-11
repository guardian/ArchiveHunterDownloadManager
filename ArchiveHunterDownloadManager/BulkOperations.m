//
//  BulkOperations.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 08/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//
#import <Cocoa/Cocoa.h>

#import "BulkOperations.h"
#import "BulkDownloadStats.h"

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
            if([self prepareBulkEntries:bulk withError:&err]){
                [bulk setValue:[NSNumber numberWithInteger:BO_READY] forKey:@"status"];
                
                BulkOperationStatus st = [self kickoffBulks:bulk withError:&err];
                if(st!=BO_READY){
                    NSLog(@"Could not start kickoff: %@", err);
                }
                return st;
            } else {
                NSLog(@"Could not prepare bulk entries: %@",err);
                return BO_ERRORED;
            }
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
    
    NSArray *results = [bulk valueForKey:@"entities"];
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

//find the location of the first common portion of both path arrays
- (NSInteger)findStartPosition:(NSArray *)bulkPathParts forEntryPath:(NSArray *)entryPathParts
{
    NSUInteger n;
    
    for(n=0;n<[bulkPathParts count];++n){
        if([[bulkPathParts objectAtIndex:n] compare:[entryPathParts objectAtIndex:0]]==NSOrderedSame) break;
    }
    if(n==[bulkPathParts count]) return -1; //there were no common portions
    return n;
}

//find the location of the last common portion (overlap) of both path arrays
- (NSInteger)findLastCommonPosition:(NSArray *)bulkPathParts forEntryPath:(NSArray *)entryPathParts startingAt:(NSInteger) startPoint
{
    NSUInteger n;
    
    for(n=startPoint;n<[bulkPathParts count];++n){
        //NSLog(@"bulk: %@", [bulkPathParts objectAtIndex:n]);
        //NSLog(@"entry: %@", [entryPathParts objectAtIndex:n-startPoint]);
        
        if([[bulkPathParts objectAtIndex:n] compare:[entryPathParts objectAtIndex:n-startPoint]]!=NSOrderedSame) break;
    }
    return n;
}

- (NSString *)stripCommonPathComponents:(NSString *)bulkPath forEntryPath:(NSString *)entryPath
{
    NSArray <NSString *> *bulkPathParts = [bulkPath pathComponents];
    NSArray <NSString *> *entryPathParts = [entryPath pathComponents];
    
    if([[entryPathParts objectAtIndex:0] compare:@"/"]==NSOrderedSame){
        NSRange stripRange;
        stripRange.location=1;
        stripRange.length=[entryPathParts count]-1;
        entryPathParts = [entryPathParts subarrayWithRange:stripRange];
    }
    NSInteger startPosition = [self findStartPosition:bulkPathParts forEntryPath:entryPathParts];
    //NSInteger lastCommonPosition = [self findLastCommonPosition:bulkPathParts forEntryPath:entryPathParts startingAt:startPosition];
    
    //NSLog(@"startPosition: %lu, lastCommonPosition: %lu", startPosition, lastCommonPosition);
    
    NSArray *pathPrefixParts;
    //start with bulk part prefix
    if(startPosition<0){    //there was no overlap in the two paths, so concatenate them together
        NSRange prefixRange;
        prefixRange.location=[[bulkPathParts objectAtIndex:0] compare:@"/"]==NSOrderedSame ? 1:0;
        prefixRange.length = [bulkPathParts count]-1;
        pathPrefixParts = [bulkPathParts subarrayWithRange:prefixRange];
    } else {                //we got an overlap, strip off the overlapping part of the first path
        NSRange prefixRange;
        prefixRange.location=[[bulkPathParts objectAtIndex:0] compare:@"/"]==NSOrderedSame ? 1:0;
        prefixRange.length = startPosition-1;
        pathPrefixParts = [bulkPathParts subarrayWithRange:prefixRange];
    }
    //skip the common portion
    
    //finish with the parts from the entry
    NSString *finalPath=[[pathPrefixParts arrayByAddingObjectsFromArray:entryPathParts ] componentsJoinedByString:@"/"];
    
    //re-add a leading / if it was present on the original path
    if([[bulkPathParts objectAtIndex:0] compare:@"/"]==NSOrderedSame){
        return [NSString stringWithFormat:@"/%@", finalPath];
    } else {
        return finalPath;
    }
}

- (void) setupDownloadEntry:(NSManagedObject *)entry withBulk:(NSManagedObject *)bulk {
    //don't mess with entries that are running or have completed
    if([(NSNumber *)[entry valueForKey:@"status"] integerValue]==BO_COMPLETED ||
       [(NSNumber *)[entry valueForKey:@"status"] integerValue]==BO_RUNNING) return;
    
    NSString *localDestString = [
                                 [self stripCommonPathComponents:[bulk valueForKey:@"destinationPath"] forEntryPath:[entry valueForKey:@"path"]
                                  ] stringByAppendingPathComponent:[entry valueForKey:@"name"]];
    
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
            if([[entry valueForKey:@"fileSize"] longLongValue]>0){
                [self performItemDownload:entry];
            } else {
                [entry setValue:[NSNumber numberWithInt:BO_INVALID] forKey:@"status"];
            }
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

/**
 update master bulk status when a download completes or fails
*/
+ (void)updateMasterOnItemComplete:(NSManagedObject *)item
{
    NSError *saveErr=nil;
    NSManagedObject *bulk = [item valueForKey:@"parent"];
    NSDictionary *updates;
    
    BulkDownloadStats *stats = [[BulkDownloadStats alloc] initWithBulk:bulk];
    
    if([stats runningCount]>0){
        updates = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:BO_RUNNING], @"status", nil];
    } else if([stats successCount]==[stats totalCount]){
        updates = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:BO_COMPLETED], @"status", nil];
    } else if([stats successCount]+[stats invalidCount]==[stats totalCount]) {
        updates = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:BO_COMPLETED], @"status", nil];
    } else if([stats waitingCount]>0){
        updates = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:BO_WAITING_USER_INPUT], @"status", nil];
    } else if([stats errorCount]==[stats totalCount]){
        updates = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:BO_ERRORED], @"status", nil];
    } else if([stats errorCount]>0){
        updates = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:BO_ERRORED], @"partial", nil];
    }
    
    [bulk setValuesForKeysWithDictionary:updates];
    
    [[item managedObjectContext] save:&saveErr];
    if(saveErr){
        NSLog(@"ERROR: Could not save data store: %@", saveErr);
    }
}


@end
