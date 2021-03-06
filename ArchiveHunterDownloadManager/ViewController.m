//
//  ViewController.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 05/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "ViewController.h"
#import "NotificationsHelper.h"

@implementation ViewController
@synthesize appDelegate;
@synthesize bulkSelectionIndices;

- (id) init {
    self = [super init];
    _downloadEntryFilterPredicate = [NSPredicate predicateWithValue:FALSE];
    _hideCompleted = [NSNumber numberWithBool:YES];
    _showSetupProgressbar = [NSNumber numberWithBool:NO];
    _setupProgress = [NSNumber numberWithFloat:0.0];
    
    [self setPossiblePriotities:[NSArray arrayWithObjects:@"High",@"Normal",@"Low",@"Ignore", nil]];
    return self;
}

- (NSPredicate *)getUpdatedPredicate {
    return [NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        NSManagedObject *entry = (NSManagedObject *)evaluatedObject;
        NSManagedObject *parent = [entry valueForKey:@"parent"];
        BOOL shouldHideCompleted = [[self hideCompleted] boolValue];
        NSString *currentDisplayOption = [self selectedDisplayOption];
        
        enum BulkOperationStatus itemStatus = (enum BulkOperationStatus)[[entry valueForKey:@"status"] integerValue];

//        BO_READY=0,
//        BO_RUNNING,
//        BO_COMPLETED,
//        BO_ERRORED,
//        BO_PARTIAL,
//        BO_WAITING_USER_INPUT,
//        BO_INVALID,
//        BO_WAITING_CHECKSUM,
//        BO_VALIDATING_CHECKSUM,
//        BO_VALIDAION_FAILED,

        if (shouldHideCompleted && (itemStatus == BO_COMPLETED)) {
            return false;
        } else if([parent valueForKey:@"id"] != [[[self bulkArrayController] selection] valueForKey:@"id"]){
            return false;
        } else if([currentDisplayOption compare:@"Only show running and errors"]==NSOrderedSame &&
                  (itemStatus==BO_PARTIAL||
                   itemStatus==BO_ERRORED||
                   itemStatus==BO_RUNNING||
                   itemStatus==BO_VALIDATING_CHECKSUM||
                   itemStatus==BO_WAITING_CHECKSUM||
                   itemStatus==BO_VALIDAION_FAILED)){
            return true;
        } else if([currentDisplayOption compare:@"Show everything"]==NSOrderedSame){
            return true;
        } else if([currentDisplayOption compare:@"Only show completed"]==NSOrderedSame && itemStatus==BO_COMPLETED){
            return true;
        } else {
            return false;
        }
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if([keyPath compare:@"selectionIndex"]==NSOrderedSame){
        [self setDownloadEntryFilterPredicate:[self getUpdatedPredicate]];
    } else if([keyPath compare:@"hideCompleted"]==NSOrderedSame){
        [self setDownloadEntryFilterPredicate:[self getUpdatedPredicate]];
    } else if([keyPath compare:@"selectedDisplayOption"]==NSOrderedSame){
        NSLog(@"updated display option: %@", [change valueForKey:NSKeyValueChangeNewKey]);
        [self setDownloadEntryFilterPredicate:[self getUpdatedPredicate]];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[[self appDelegate] queueManager] setCompletedCallback:
        ^(NSManagedObject *entry, NSString *filepath, NSUInteger status, BOOL shouldRetry) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self forceDownloadItemListRefresh];
            });
        }
     ];
    
    [self setDisplayOptions:[NSArray arrayWithObjects:@"Show everything",@"Only show running and errors",@"Only show completed", nil]];
    [self setSelectedDisplayOption:@"Show everything"];
    
    [_bulkArrayController addObserver:self forKeyPath:@"selectionIndex" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial context:nil];
    [self addObserver:self forKeyPath:@"hideCompleted" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial context:nil];
    
    [self addObserver:self forKeyPath:@"selectedDisplayOption" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial context:nil];
    // Do any additional setup after loading the view.
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

/**
 gets the NSManagedObject pointer for the currently selected bulk.
 displays an alert panel with 'failureMessage' if nothing is selected
 otherwise calls the provided block passing the NSManagedObject pointer as the argument
 */
- (void)withSelectedBulk:(NSString *)failureMessage block:(void(^)(NSManagedObject *))block
{
    NSWindow *window = [[self view] window];
    NSArray *selection = [_bulkArrayController selectedObjects];
    if([selection count]==0){
        NSAlert *alrt = [[NSAlert alloc] init];
        [alrt setInformativeText:failureMessage];
        [alrt beginSheetModalForWindow:window completionHandler:^(NSInteger result){
            
        }];
    } else {
        NSManagedObject *selectedBulk = [selection objectAtIndex:0];
        
        block(selectedBulk);
    }
}

/**
 user has clicked the "cog" button, show the edit box
 */
- (IBAction)editClicked:(id)sender {
    [self withSelectedBulk:@"You must select a bulk entry to edit" block:^(NSManagedObject *selectedBulk){
        [self askUserForPath:selectedBulk];
    }];
}

/**
 user has clicked the "reload" button, start off downloads
 */
- (IBAction)runClicked:(id)sender {
    NSWindow *window = [[self view] window];
    NSError *err;
    
    BOOL result = [BulkOperations bulkForAll:[[self appDelegate] managedObjectContext] withError:&err block:^(NSManagedObject *bulk){
        [[[self appDelegate] bulkOperations] startBulk:bulk autoStart:TRUE];
    }];
    
    if(!result){
        NSAlert *alrt = [NSAlert alertWithError:err];
        [alrt beginSheetModalForWindow:window completionHandler:nil];
    }
    
}

/**
 user has clicked the "folder" button, reveal the download location in Finder
 */
- (IBAction)revealClicked:(id)sender {
    NSWindow *window = [[self view] window];
    [self withSelectedBulk:@"You must select a bulk entry to reveal" block:^(NSManagedObject *selectedBulk){
        NSString *bulkDir = [selectedBulk valueForKey:@"destinationPath"];
        if(bulkDir){
            [[NSWorkspace sharedWorkspace] openFile:bulkDir];
        } else {
            NSAlert *alrt = [[NSAlert alloc] init];
            [alrt setInformativeText:@"You need to set a download path before reveal in finder can work"];
            [alrt beginSheetModalForWindow:window completionHandler:^(NSInteger result){
                
            }];
        }
    }];
}

/**
 user has clicked the "minus" button, remove the bulk and its contents from the memory store
 */
- (IBAction)removeBulkClicked:(id)sender
{
    NSWindow *window = [[self view] window];
    [self withSelectedBulk:@"You must select a bulk entry to remove" block:^(NSManagedObject *selectedBulk){
        NSError *iterationError=nil, *saveError=nil;
        NSManagedObjectContext *moc = [[self appDelegate] managedObjectContext];
        BulkOperationStatus status = [(NSNumber *)[selectedBulk valueForKey:@"status"] intValue];
        if(status==BO_RUNNING){
            [self showErrorBox:@"You can't remove a download that is in progress"];
        } else {
            //first remove all of the downloads
            [BulkOperations bulkForEach:selectedBulk managedObjectContext:moc withError:&iterationError block:^(NSManagedObject *entry){
                [moc deleteObject:entry];
            }];
            
            if(iterationError){
                NSAlert *alrt = [NSAlert alertWithError:iterationError];
                [alrt beginSheetModalForWindow:window completionHandler:nil];
            } else {
                [moc deleteObject:selectedBulk];
                [moc save:&saveError];
                if(saveError){
                    NSAlert *alrt = [NSAlert alertWithError:iterationError];
                    [alrt beginSheetModalForWindow:window completionHandler:nil];
                }
            }
        }
    }];
}

/**
 user has clicked the "reset running" button, go through all "running" status downloads and reset them to "ready"
 */
- (IBAction)resetRunningClicked:(id)sender
{
    NSWindow *window = [[self view] window];
    [self withSelectedBulk:@"You must select a bulk entry" block:^(NSManagedObject *selectedBulk) {
        NSError *iterationError=nil;
        NSManagedObjectContext *moc = [[self appDelegate] managedObjectContext];
        BulkOperationStatus status = [(NSNumber *)[selectedBulk valueForKey:@"status"] intValue];
        
        if(status==BO_RUNNING){
            [self showErrorBox:@"You can't reset job status while the download is in progress. Stop it first then try again"];
        } else {
            [BulkOperations bulkForEach:selectedBulk managedObjectContext:moc withError:&iterationError block:^(NSManagedObject *entry) {
                BulkOperationStatus itemStatus = [[entry valueForKey:@"status"] intValue];
                if(itemStatus==BO_RUNNING) [entry setValue:[NSNumber numberWithInteger:BO_READY] forKey:@"status"];
            }];
            
            if(iterationError){
                NSAlert *alrt = [NSAlert alertWithError:iterationError];
                [alrt beginSheetModalForWindow:window completionHandler:nil];
            }
            [moc save:nil];
        }
    }];
}

- (IBAction)stopDownload:(id)sender
{
    [self withSelectedBulk:@"You must select a bulk entry" block:^(NSManagedObject *selectedBulk) {
        NSError *iterationError=nil;
        NSManagedObjectContext *moc = [[self appDelegate] managedObjectContext];
        
        //remove each potentially pending download from the queue
        [BulkOperations bulkForEach:selectedBulk managedObjectContext:moc withError:&iterationError block:^(NSManagedObject *entry) {
            [[[self appDelegate] queueManager] removeFromQueue:entry];
        }];
        
        if([[selectedBulk valueForKey:@"status"] intValue]!=BO_COMPLETED){
            [selectedBulk setValue:[NSNumber numberWithInteger:BO_PARTIAL] forKey:@"status"];
        }
        [moc save:nil];
    }];
    
}

- (IBAction)testMessageClicked:(id)sender
{
    NSWindow *window = [[self view] window];
    NSArray *selection = [_bulkArrayController selectedObjects];
    if([selection count]==0){
        NSAlert *alrt = [[NSAlert alloc] init];
        [alrt setInformativeText:@"You must select a bulk entry to reveal"];
        [alrt beginSheetModalForWindow:window completionHandler:^(NSInteger result){
            
        }];
    } else {
        NSManagedObject *selectedBulk = [selection objectAtIndex:0];
        [NotificationsHelper showPartialFailedNotification:selectedBulk];
    }
}

/**
 pop up an Open dialog to ask the user where they want to save this bulk download
 */
- (void) askUserForPath:(NSManagedObject *)bulk {
    NSWindow *window = [[self view] window];
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setPrompt:@"Download path"];
    [panel setMessage:[NSString stringWithFormat:@"Please select a folder to download %@", [bulk valueForKey:@"downloadDescription"]]];
    [panel setCanCreateDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setCanChooseDirectories:YES];
    [panel beginSheetModalForWindow:window completionHandler:^(NSInteger result){
        NSURL *selectedUrl = [panel URL];
        NSString *newDownloadPath;
        
        switch(result){
            case NSFileHandlingPanelOKButton:
                newDownloadPath = [[selectedUrl filePathURL] path];
                NSLog(@"new download path is %@", newDownloadPath);
                
                [bulk setValue:newDownloadPath forKey:@"destinationPath"];

                [[self appDelegate] asyncSetupDownload:bulk];
                break;
            default:
                NSLog(@"user cancelled save");
                break;
        }
    }];
}

/**
 simple helper method to show an error box as a window-modal sheet
 */
- (void) showErrorBox:(NSString *)msg {
    NSWindow *window = [[self view] window];

    NSAlert *alrt = [[NSAlert alloc] init];
    [alrt setInformativeText:msg];
    [alrt beginSheetModalForWindow:window completionHandler:nil];
}

- (NSUInteger) countEntriesForBulk:(NSManagedObject *)bulk {
    NSArray *entries = [bulk valueForKey:@"entities"];
    return [entries count];
}

/**
 User has clicked the "Retry" button
 */
- (IBAction)retryClicked:(id)sender
{
    NSWindow *window = [[self view] window];
    
    
//    NSUInteger total_count = [[_bulkArrayController content] count];
//    NSLog(@"Got total count %lu", (unsigned long)total_count);
    
    
    [self withSelectedBulk:@"You must select a bulk entry" block:^(NSManagedObject *selectedBulk) {
        NSUInteger total_count = [self countEntriesForBulk:selectedBulk];
        NSLog(@"Got total count %lu", (unsigned long)total_count);
        [self setShowSetupProgressbar:[NSNumber numberWithBool:YES]];
        
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *iterationError=nil;
            NSManagedObjectContext *moc = [[self appDelegate] managedObjectContext];
            
            [BulkOperations bulkForEach:selectedBulk managedObjectContext:moc withError:&iterationError block:^(NSManagedObject *entry) {
                NSUInteger count=0;
                [[[self appDelegate] bulkOperations] startBulk:selectedBulk autoStart:TRUE];
                [self setSetupProgress:[NSNumber numberWithDouble:(double)count/(double)total_count]];
                ++count;
            }];
            
            if(iterationError){
                NSAlert *alrt = [NSAlert alertWithError:iterationError];
                dispatch_async(dispatch_get_main_queue(),^{
                    [alrt beginSheetModalForWindow:window completionHandler:nil];
                });
            }
            [moc save:nil];
        });
    }];
}

- (void) forceDownloadItemListRefresh
{
    //[[[self appDelegate] managedObjectContext] reset];
    [[self bulkArrayController] fetch:self];
}
@end
