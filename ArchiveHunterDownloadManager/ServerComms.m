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

- (NSURLDownload *)performItemDownload:(NSURL *)actualDownloadUrl forEntry:(NSManagedObject *)entry {
    DownloadDelegate *del = [[DownloadDelegate alloc] initWithEntry:entry];
    NSURLRequest *req = [NSURLRequest requestWithURL:actualDownloadUrl];
    
    NSURLDownload *dld = [[NSURLDownload alloc] initWithRequest:req delegate:del];
    [dld setDestination:[entry valueForKey:@"destinationFile"] allowOverwrite:YES];
    [dld setDeletesFileUponFailure:YES];

    return dld;
}

- (NSURLSessionDataTask *) itemRetrievalTask:(NSURL *)retrievalLink forEntry:(NSManagedObject *)entry {
    NSURLSession *sess = [NSURLSession sharedSession];
    
    return [sess dataTaskWithURL:retrievalLink completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSError *parseError=nil;
        
        if(error){
            [self setEntryError:error forEntry:entry];
        } else {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&parseError];
            if(json){
                NSString *actualDownloadUrl = [json valueForKey:@"entry"];
                NSLog(@"Actual download URL for %@ is %@" , retrievalLink, actualDownloadUrl);
                [self performItemDownload:[NSURL URLWithString:actualDownloadUrl] forEntry:entry];
            } else {
                NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                NSLog(@"Could not parse JSON from server: %@", parseError);
                [self setEntryError:parseError forEntry:entry];
            }
        }
    }];
}
@end
