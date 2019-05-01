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
#import "CurlDownloader.h"

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
             NSLog(@"error making initial contact: %@", error);
             dispatch_async(dispatch_get_main_queue(), ^{
                 completionBlock(nil, error);
                 NSAlert *alert = [[NSAlert alloc] init];
                 [alert setMessageText:@"Network Error"];
                 [alert setInformativeText:@"A network error occured. Please check if the server domain name is set correctly in the Preferences window."];
                 [alert addButtonWithTitle:@"Okay"];
                 [alert runModal];
             });
         } else if([(NSHTTPURLResponse*)response statusCode]!=200){
             NSLog(@"Error making initial contact: server returned %@", response);
             dispatch_async(dispatch_get_main_queue(), ^{
                 NSError *ownError = [[NSError alloc] initWithDomain:@"servercomms"
                                                                code:[(NSHTTPURLResponse*)response statusCode]
                                                            userInfo:nil];
                 
                 completionBlock(nil, ownError);
                 
                 NSAlert *alert = [[NSAlert alloc] init];
                 [alert setMessageText:@"Server Error"];
                 NSString *errorString = [NSString stringWithFormat:@"A server error occurred with code %lu. Please retry, if this continues to occur inform multimediatech@theguardian.com", [(NSHTTPURLResponse*)response statusCode]];
                 
                 [alert setInformativeText:errorString];
                 [alert addButtonWithTitle:@"Okay"];
                 [alert runModal];
             });
         } else {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&parseError];
             dispatch_async(dispatch_get_main_queue(), ^{
                 completionBlock(json, parseError);
             });
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
    dispatch_async(dispatch_get_main_queue(), ^{
        [entry setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      [err localizedDescription],@"lastError",
                                                      [NSNumber numberWithInt:BO_ERRORED], @"status"
                                                      ,nil]];
    });
}

- (BOOL)performItemDownload:(NSURL *)actualDownloadUrl
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
            dispatch_async(dispatch_get_main_queue(), ^{
                [entry setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSString stringWithFormat:@"A file already exists at %@", dir],@"lastError", 
                                                       [NSNumber numberWithInteger:BO_ERRORED], @"status",
                                                       nil]];
            });
            return FALSE;
        }
    } else {
        [fileManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&err];
        if(err){
            NSLog(@"%@: could not create: %@", dir, err);
            dispatch_async(dispatch_get_main_queue(), ^{
                [entry setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [err localizedDescription], @"lastError",
                                                       [NSNumber numberWithInt:BO_ERRORED], @"status",
                                                       nil]];
            });
            return FALSE;
        }
    }
    
    if([fileManager fileExistsAtPath:[entry valueForKey:@"destinationFile"]]){
        NSNumber* shouldOverwrite = [[NSUserDefaults standardUserDefaults] valueForKey:@"overwriteSelected"];
        if(!shouldOverwrite || ![shouldOverwrite boolValue]){
            dispatch_async(dispatch_get_main_queue(), ^{
                [entry setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       @"The file already exists", @"lastError",
                                                       [NSNumber numberWithInt:BO_ERRORED], @"status",
                                                       nil]];
            });
            return FALSE;
        } else {
            NSLog(@"Deleting existing file %@ because user prefs say we can", [entry valueForKey:@"destinationFile"]);
            BOOL result = [fileManager removeItemAtPath:[entry valueForKey:@"destinationFile"] error:&err];
            if(!result){
                dispatch_async(dispatch_get_main_queue(), ^{
                    [entry setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [err localizedDescription], @"lastError",
                                                           [NSNumber numberWithInt:BO_ERRORED], @"status",
                                                           nil]];
                });
                return FALSE;
            }
        }
    }

    CurlDownloader *downloader = [[CurlDownloader alloc] initWithChunkSize:4096];
    [downloader setDownloadDelegate:del];
    
    bool result = [downloader startDownloadAsync:actualDownloadUrl
                                      toFilePath:[entry valueForKey:@"destinationFile"]
                                       withError:&err];
    
    if(!result){
        NSLog(@"Could not start download for %@", [entry valueForKey:@"destinationFile"]);
        if(err){
            dispatch_async(dispatch_get_main_queue(), ^{
                [entry setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [err localizedDescription], @"lastError",
                                                       [NSNumber numberWithInt:BO_ERRORED], @"status",
                                                       nil]];
            });
        }
        return FALSE;
    }
    return TRUE;

}

/**
 retrieve the physical download URL from the server. This takes the form of an S3 presigned URL
 */
- (NSURLSessionDataTask *) itemRetrievalTask:(NSURL *)retrievalLink
                                    forEntry:(NSManagedObject *)entry
                           completionHandler:(void (^ _Nonnull)(NSURL *downloadUrl, NSError *_Nullable err))completionBlock
{
    NSURLSession *sess = [NSURLSession sharedSession];
    
    NSLog(@"itemRetrievalTask for %@", [entry valueForKey:@"name"]);
    
    return [sess dataTaskWithURL:retrievalLink completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSError *parseError=nil;
        
        if(error){
            NSLog(@"Could not retrieve actual download URL for %@: %@", [entry valueForKey:@"name"], error);
            [self setEntryError:error forEntry:entry];
            completionBlock(nil, error);
        } else {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&parseError];
            if(json){
                NSString *actualDownloadUrl = [json valueForKey:@"entry"];
                
                //NSLog(@"Actual download URL for %@ is %@" , retrievalLink, actualDownloadUrl);
                NSURL *downloadURL = [NSURL URLWithString:actualDownloadUrl];
                
                if(downloadURL){
                    completionBlock(downloadURL,nil);
                } else {
                    NSLog(@"Could not create NSURL from %@", actualDownloadUrl);
                }
            } else {
                NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                NSLog(@"Could not parse JSON from server: %@", parseError);
                [self setEntryError:parseError forEntry:entry];
                completionBlock(nil, parseError);
            }
        }
    }];
}
@end
