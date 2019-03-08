//
//  ViewController.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 05/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

@interface ViewController : NSViewController

@property (weak,nonatomic) IBOutlet AppDelegate* appDelegate;
@property (weak, nonatomic) IBOutlet NSArrayController *bulkArrayController;

@property (readwrite, strong, nonatomic) IBOutlet NSArray* possiblePriotities;

- (void) askUserForPath:(NSManagedObject *)bulk;

@end

