//
//  PreferencesController.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 06/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "PreferencesController.h"

@interface PreferencesController ()

@end

@implementation PreferencesController
@synthesize httpServer;

- (id) init {
//    self = [super init];
//    httpServer = [[HTTPServer alloc] init];
//    [httpServer setServerPort:4567];
//    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

/**
 turn a dictionary into a query string
 */
- (NSString *)queryParamString:(NSDictionary *)dictParams {
    NSMutableArray *parts = [NSMutableArray arrayWithCapacity:[dictParams count]];
    
    for(NSString *key in dictParams){
        [parts addObject:[NSString stringWithFormat:@"%@=%@", key, [dictParams objectForKey:key]]];
    }
    
    return [parts componentsJoinedByString:@"&"];
}


- (IBAction)authorizeClicked:(id)sender {
//    NSUserDefaults *dfl = [NSUserDefaults standardUserDefaults];
//    
//    NSURL *testAuthURL = [NSURL URLWithString:
//                          [NSString stringWithFormat:@"https://%@/checkLogin", [dfl valueForKey:@"serverHost"]]];
//    
//    NSURLRequest *rq = [NSURLRequest requestWithURL:testAuthURL];
//    NSURLSession *sess = [NSURLSession sharedSession];
//    
//    NSURLSessionTask *tsk = [sess dataTaskWithURL:testAuthURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//        NSHTTPURLResponse *httpResponse=(NSHTTPURLResponse *)response;
//        
//        switch([httpResponse statusCode]){
//            case 301:
//                [self setIsAuthenticated:[NSNumber numberWithBool:FALSE]];
//                [httpResponse ]
//                break;
//            case 200:
//                [self setIsAuthenticated:[NSNumber numberWithBool:TRUE]];
//                break;
//                
//        }
//    }];
//    
//    //NSURLSessionDownloadTask *dld = [sess downloadTaskWithURL:testAuthURL];
//    [dld did]
    
}

@end
