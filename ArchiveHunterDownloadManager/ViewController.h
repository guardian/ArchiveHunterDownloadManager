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
@property (weak, nonatomic) IBOutlet NSArrayController *downloadsArrayController;

@property (readwrite, strong, nonatomic) IBOutlet NSArray* possiblePriotities;

@property (strong, atomic) NSPredicate* downloadEntryFilterPredicate;
@property (strong, atomic) NSIndexSet *bulkSelectionIndices;
@property (strong, atomic) NSNumber* hideCompleted;

@property (strong, atomic) NSArray<NSString *>* displayOptions;
@property (strong, atomic) NSString *selectedDisplayOption;

- (void) askUserForPath:(NSManagedObject *)bulk;
- (void) showErrorBox:(NSString *)msg;

- (void) forceDownloadItemListRefresh;

@end

