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


- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (IBAction)overwriteSelectorChanged:(id)sender {
    NSLog(@"overwriteSelected: %@", [self overwriteSelected]);
}

@end
