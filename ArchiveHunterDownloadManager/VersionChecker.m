//
//  VersionChecker.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 04/11/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "VersionChecker.h"

@implementation VersionChecker
- (id)initWithServerPath:(NSString*)serverPath {
    _serverPath = serverPath;
    return self;
}

/**
 returns an NSNumber containing the build version as recorded in the bundle
 returns nil if the string can't be converted
 */
- (NSNumber *) getCurrentVersionNumber {
    NSString *ourCurrentBuildStr = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    f.numberStyle = NSNumberFormatterNoStyle;
    NSNumber *result = [f numberFromString:ourCurrentBuildStr];
    if(result==nil) {
        NSLog(@"Could not convert provided build number '%@' to integer, assuming we are on dev.", ourCurrentBuildStr);
    }
    return result;
}

- (void) performVersionCheck:(void (^)(NSNumber* currentBuildNumber, NSDictionary* remoteBuildInfo))needsUpdateHandler {
    NSError *err;
    NSString *checkUrl = [NSString stringWithFormat:@"%@/lookup", [self serverPath]];
    
    NSString *buildBranch = (NSString *)[[NSBundle mainBundle] objectForInfoDictionaryKey:@"BuildBranch"];
    
    NSDictionary *lookupBodyContent = [NSDictionary dictionaryWithObjectsAndKeys:@"archivehunter-download-manager",@"productName",
                                       buildBranch, @"branch", [NSNumber numberWithBool:TRUE], @"alwaysShowMaster", nil];
    
    NSLog(@"version update check - sending %@ to %@", lookupBodyContent, checkUrl);
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:lookupBodyContent options:0 error:&err];
    NSString *jsonDataCheck = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"version update check - request body %@", jsonDataCheck);
    
    NSURLSession *sess = [NSURLSession sharedSession];
    
    NSMutableURLRequest *rq = [[NSMutableURLRequest alloc] init];
    [rq setURL:[NSURL URLWithString:checkUrl]];
    [rq setHTTPMethod:@"GET"];
    [rq setHTTPBody:jsonData];
    
    NSURLSessionTask *t = [sess dataTaskWithRequest:rq completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"Received response from version check");
        NSHTTPURLResponse *realResponse = (NSHTTPURLResponse *)response;
        
        if([realResponse statusCode]!=200){
            NSString *errorBodyString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"Versions server replied with an error: code %ld message %@", (long)[realResponse statusCode], errorBodyString);
            return;
        }
        
        id returnedData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSArray *returnedArray = (NSArray *)returnedData;
        
        NSDictionary *onBranchUpdate = [returnedArray objectAtIndex:0];
        
        NSLog(@"Latest build on our branch %@ is %@ from %@", buildBranch, [onBranchUpdate objectForKey:@"buildId"], [onBranchUpdate objectForKey:@"timestamp"]);
        
        NSNumber *currentBuildNumber = [self getCurrentVersionNumber];
        NSLog(@"Our build number is %@", currentBuildNumber);
        
        if(currentBuildNumber!=nil && [onBranchUpdate objectForKey:@"buildId"]!=nil){
            NSNumber *remoteVersion = (NSNumber *)[onBranchUpdate objectForKey:@"buildId"];
            if([remoteVersion integerValue]>[currentBuildNumber integerValue]){
                NSLog(@"Update is required, remote has version %@", remoteVersion);
                needsUpdateHandler(currentBuildNumber, onBranchUpdate);
            } else {
                NSLog(@"We don't need an update");
            }
        }
    }];
    
    [t resume];
}
@end
