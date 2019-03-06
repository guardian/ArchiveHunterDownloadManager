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
    self = [super init];
    httpServer = [[HTTPServer alloc] init];
    [httpServer setServerPort:4567];
    return self;
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
    NSUserDefaults *dfl = [NSUserDefaults standardUserDefaults];
    
    [httpServer start];
    
    if([httpServer lastError]){
        NSAlert *a=[NSAlert alertWithError:[httpServer lastError]];
        [a runModal];
    }
    
    //see https://developers.google.com/identity/protocols/OAuth2InstalledApp
    NSDictionary *queryParams = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"client_id",[dfl valueForKey:@"googleAppId"],
                                 @"redirect_uri", 
                                 nil];
    
    NSString *urlString = [NSString stringWithFormat:@"https://accounts.google.com/o/oauth2/v2/auth?%@",
                           [self queryParamString:queryParams]
                           ];
    
    NSURL *authUrl = [NSURL URLWithString:urlString];
    
    [[NSWorkspace sharedWorkspace] openURL:authUrl];
}

@end
