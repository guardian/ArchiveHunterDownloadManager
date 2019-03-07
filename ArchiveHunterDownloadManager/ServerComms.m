//
//  ServerComms.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 07/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "ServerComms.h"

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


@end
