//
//  ServerComms.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 07/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "ServerComms.h"
#import "DownloadDelegate.h"
#import "BulkOperations.h"

@implementation ServerComms

- (id)init {
    self = [super init];
    _session = [NSURLSession sharedSession];
    _replyQueue = dispatch_queue_create("com.gu.ArchiveHunterDownloadManager.ServerComms",NULL );
    return self;
}


/**
 use the provided one-off token to start download from server.
 call the given completionHandler block when that is done.
 */
- (BOOL) initiateDownload:(NSString *)token
               withError:(NSError **)err
       completionHandler:(void (^)(NSDictionary *_Nullable data, NSError *err))completionBlock
{
    NSString *serverHost = [[NSUserDefaults standardUserDefaults] objectForKey:@"serverHost" ];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/bulk/%@", serverHost, token]];
    
    NSLog(@"Download URL is %@", url);
    
    NSURLSessionDataTask *t = [_session dataTaskWithURL:url
        completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
    {
        NSError *parseError=NULL;
        NSLog(@"in completionHandler, response is %@", response);
        
         if(error){
             completionBlock(nil, error);
             NSAlert *alert = [[NSAlert alloc] init];
             [alert setMessageText:@"Network Error"];
             [alert setInformativeText:@"A network error occured. Please check if the server domain name is set correctly in the Preferences window."];
             [alert addButtonWithTitle:@"Okay"];
             [alert runModal];
         } else {
             
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&parseError];
            
            completionBlock(json, parseError);
         }
    }];
    [t resume];
    if([t error] && err){
        *err = [[t error] copy];
        return NO;
    } else {
        return YES;
    }
}

- (void)setEntryError:(NSError *)err forEntry:(NSManagedObject *)entry {
    [entry setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [err localizedDescription],@"lastError",
                                                  [NSNumber numberWithInt:BO_ERRORED], @"status"
                                                  ,nil]];
}

- (void)performItemDownload:(NSURL *)actualDownloadUrl
                   forEntry:(NSManagedObject *)entry
                    manager:(DownloadQueueManager *)mgr
{
    NSError *err=nil;
    BOOL isDir;
    
    DownloadDelegate *del = [[DownloadDelegate alloc] initWithEntry:entry dispatchQueue:[self replyQueue] withManager:mgr];
    NSURLRequest *req = [NSURLRequest requestWithURL:actualDownloadUrl];
    
    //check that the directory for destination file exists
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *dir = [(NSString *)[entry valueForKey:@"destinationFile"] stringByDeletingLastPathComponent];
    
    if([fileManager fileExistsAtPath:dir isDirectory:&isDir]){
        if(!isDir){
            NSLog(@"%@ already exists and isn't a directory", dir);
            [entry setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSString stringWithFormat:@"A file already exists at %@", dir],@"lastError", 
                                                   [NSNumber numberWithInteger:BO_ERRORED], @"status",
                                                   nil]];
            return;
        }
    } else {
        [fileManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&err];
        if(err){
            NSLog(@"%@: could not create: %@", dir, err);
            [entry setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   @"lastError", [err localizedDescription],
                                                   @"status", [NSNumber numberWithInt:BO_ERRORED],
                                                   nil]];
            return;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        //this must be done on the main thread to get at the primary runloop
        NSURLDownload *dld = [[NSURLDownload alloc] initWithRequest:req delegate:del];
        
        if(!dld){
            NSLog(@"Error - could not start download.");
        }
        NSLog(@"Downloading %@ to %@", actualDownloadUrl, [entry valueForKey:@"destinationFile"]);
        [dld setDestination:[entry valueForKey:@"destinationFile"] allowOverwrite:YES];
        [dld setDeletesFileUponFailure:YES];
    });
}

- (NSURLSessionDataTask *) itemRetrievalTask:(NSURL *)retrievalLink
                                    forEntry:(NSManagedObject *)entry
                                     manager:(DownloadQueueManager *)mgr
{
    NSURLSession *sess = [NSURLSession sharedSession];
    
    return [sess dataTaskWithURL:retrievalLink completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSError *parseError=nil;
        
        if(error){
            [self setEntryError:error forEntry:entry];
        } else {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&parseError];
            if(json){
                //NSString *actualDownloadUrl = [(NSString *)[json valueForKey:@"entry"] stringByRemovingPercentEncoding];
                NSString *actualDownloadUrl = [json valueForKey:@"entry"];
                
                NSLog(@"Actual download URL for %@ is %@" , retrievalLink, actualDownloadUrl);
                NSURL *downloadURL = [NSURL URLWithString:actualDownloadUrl];
                
                if(downloadURL){
                    [self performItemDownload:downloadURL forEntry:entry manager:mgr];
                } else {
                    NSLog(@"Could not create NSURL from %@", actualDownloadUrl);
                }
            } else {
                NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                NSLog(@"Could not parse JSON from server: %@", parseError);
                [self setEntryError:parseError forEntry:entry];
            }
        }
    }];
}
@end
