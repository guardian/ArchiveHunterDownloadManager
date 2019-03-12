//
//  AppDelegate.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 05/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "AppDelegate.h"
#import "ServerComms.h"

#import "ViewController.h"

@interface AppDelegate ()

- (IBAction)saveAction:(id)sender;

@end

@implementation AppDelegate

- (id)init {
    self = [super init];
    [self registerMyApp];
    _serverComms = [[ServerComms alloc] init];
    _bulkOperations = [[BulkOperations alloc] init];
    
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
     [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
}

- (void)applictionWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (void)registerMyApp {
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(getUrl:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}


/**
ensure that the Notification Center pops-up our notifications
 */
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
     shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}


/**
 create a new data entry based on the info from the server
*/
- (NSManagedObject *) createNewBulk:(NSDictionary *)bulkMetadata retrievalToken:(NSString *)retrievalToken {
    NSManagedObjectContext *ctx = [self managedObjectContext];
    
    NSManagedObject* ent=[NSEntityDescription insertNewObjectForEntityForName:@"BulkDownload" inManagedObjectContext:ctx];

    [ent setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [bulkMetadata objectForKey:@"description"], @"downloadDescription",
                                         [bulkMetadata objectForKey:@"id"], @"id",
                                         retrievalToken, @"retrievalToken",
                                         [NSNumber numberWithInteger:0], @"Status",
                                         [bulkMetadata objectForKey:@"userEmail"], @"userEmail",
                                         nil]];
    return ent;
}

- (NSManagedObject *) createNewEntry:(NSDictionary *)entrySynop parent:(NSManagedObject *) parent {
    NSManagedObjectContext *ctx = [self managedObjectContext];
    
    NSManagedObject* ent=[NSEntityDescription insertNewObjectForEntityForName:@"DownloadEntity" inManagedObjectContext:ctx];
    NSString *objPath = [entrySynop objectForKey:@"path"];
    
    NSArray *pathParts = [objPath pathComponents];
    NSLog(@"%@", [pathParts lastObject]);
    
    NSRange allButLastRange;
    allButLastRange.location=0;
    allButLastRange.length=[pathParts count]-1;
    
    NSString *pathOnly = [[pathParts subarrayWithRange:allButLastRange] componentsJoinedByString:@"/"];
    
    [ent setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                         (NSString *)[entrySynop objectForKey:@"entryId"], @"fileId",
                                         [pathParts lastObject], @"name",
                                         pathOnly, @"path",
                                         parent, @"parent",
                                         [entrySynop objectForKey:@"fileSize"], @"fileSize",
                                         nil]];
    return ent;
}

//URL handling
- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString * urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    // Now you can parse the URL and perform whatever action is needed }
    NSArray<NSString *> *components = [urlString componentsSeparatedByString:@":"];
    NSLog(@"Got request: %@", components);
    if([[components objectAtIndex:1] compare:@"bulkdownload"]==NSEqualToComparison){
        NSError *err;
        NSString *token = [components objectAtIndex:2];
        NSLog(@"Got bulk download with onetime token %@", token);
        
        BOOL result = [_serverComms initiateDownload:token withError:&err completionHandler:^(NSDictionary *_Nullable data, NSError *err){
            NSError *localErr=nil;
            
            if(err){
                NSLog(@"Download error: %@", err);
            } else {
                NSLog(@"Got data: %@", data);
                NSDictionary *metadata = [data objectForKey:@"metadata"];
                
                if([self haveBulkEntryFor:[metadata valueForKey:@"id"] withError:&localErr]){
                    [(ViewController *)_mainViewController showErrorBox:@"You already have this bulk in your download queue"];
                } else {
                    NSManagedObject *bulk = [self createNewBulk:metadata retrievalToken:[data objectForKey:@"retrievalToken"]];
                    
                    for(NSDictionary *entrySynop in [data objectForKey:@"entries"]){
                        [self createNewEntry:entrySynop parent:bulk];
                    }
                    
                    [[self managedObjectContext] save:&err];
                    if(err){
                        NSLog(@"could not save data store: %@", err);
                    }
                    [self asyncSetupDownload:bulk];
                }
            }
        }];
        if(!result){
            NSLog(@"Download failed: %@", err);
        }
    }
}

- (BOOL) haveBulkEntryFor:(NSString *) bulkId withError:(NSError **)err{
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"BulkDownload"];
    [req setPredicate:[NSPredicate predicateWithFormat:@"id == %@", bulkId]];
    
    NSArray *results = [[self managedObjectContext] executeFetchRequest:req error:err];
    if(!results) return NO;
    
    return [results count]>0;
}

//run setup for a bulk. Do this in the background.
- (void) asyncSetupDownload:(NSManagedObject *)bulk {
    NSError *err;
    
    if(![[self bulkOperations] moc]) [[self bulkOperations] setMoc:[self managedObjectContext]];
    
    if(![[self managedObjectContext] save:&err]){
        NSLog(@"Could not save managed objects: %@", err);
    }
    
    dispatch_queue_t targetQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    dispatch_async(targetQueue, ^{
        NSError *err;
        
        BulkOperationStatus status = [_bulkOperations startBulk:bulk];
        if(status==BO_WAITING_USER_INPUT){
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *err=nil;
                [(ViewController *)_mainViewController askUserForPath:bulk];
                [[self managedObjectContext] save:&err];
            });
        } else {
            NSLog(@"Status is %d", status);
            NSLog(@"bulk is %@", bulk);
            if(![[self managedObjectContext] save:&err]){
                NSLog(@"Could not save managed objects: %@", err);
            }
        }
    });
}

//
#pragma mark - Core Data stack

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize managedObjectContext = _managedObjectContext;

- (NSURL *)applicationDocumentsDirectory {
    // The directory the application uses to store the Core Data store file. This code uses a directory named "com.gu.ArchiveHunterDownloadManager" in the user's Application Support directory.
    NSURL *appSupportURL = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
    return [appSupportURL URLByAppendingPathComponent:@"com.gu.ArchiveHunterDownloadManager"];
}

- (NSManagedObjectModel *)managedObjectModel {
    // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
    if (_managedObjectModel) {
        return _managedObjectModel;
    }
	
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"ArchiveHunterDownloadManager" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
    if (_persistentStoreCoordinator) {
        return _persistentStoreCoordinator;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationDocumentsDirectory = [self applicationDocumentsDirectory];
    BOOL shouldFail = NO;
    NSError *error = nil;
    NSString *failureReason = @"There was an error creating or loading the application's saved data.";
    
    // Make sure the application files directory is there
    NSDictionary *properties = [applicationDocumentsDirectory resourceValuesForKeys:@[NSURLIsDirectoryKey] error:&error];
    if (properties) {
        if (![properties[NSURLIsDirectoryKey] boolValue]) {
            failureReason = [NSString stringWithFormat:@"Expected a folder to store application data, found a file (%@).", [applicationDocumentsDirectory path]];
            shouldFail = YES;
        }
    } else if ([error code] == NSFileReadNoSuchFileError) {
        error = nil;
        [fileManager createDirectoryAtPath:[applicationDocumentsDirectory path] withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    if (!shouldFail && !error) {
        NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
        NSURL *url = [applicationDocumentsDirectory URLByAppendingPathComponent:@"OSXCoreDataObjC.storedata"];
        if (![coordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:url options:nil error:&error]) {
            coordinator = nil;
        }
        _persistentStoreCoordinator = coordinator;
    }
    
    if (shouldFail || error) {
        // Report any error we got.
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[NSLocalizedDescriptionKey] = @"Failed to initialize the application's saved data";
        dict[NSLocalizedFailureReasonErrorKey] = failureReason;
        if (error) {
            dict[NSUnderlyingErrorKey] = error;
        }
        error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        [[NSApplication sharedApplication] presentError:error];
    }
    return _persistentStoreCoordinator;
}

- (NSManagedObjectContext *)managedObjectContext {
    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
    if (_managedObjectContext) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];

    return _managedObjectContext;
}

#pragma mark - Core Data Saving and Undo support

- (IBAction)saveAction:(id)sender {
    // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }
    
    NSError *error = nil;
    if ([[self managedObjectContext] hasChanges] && ![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
    return [[self managedObjectContext] undoManager];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    // Save changes in the application's managed object context before the application terminates.
    
    if (!_managedObjectContext) {
        return NSTerminateNow;
    }
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }
    
    if (![[self managedObjectContext] hasChanges]) {
        return NSTerminateNow;
    }
    
    NSError *error = nil;
    if (![[self managedObjectContext] save:&error]) {

        // Customize this code block to include application-specific recovery steps.              
        BOOL result = [sender presentError:error];
        if (result) {
            return NSTerminateCancel;
        }

        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];

        NSInteger answer = [alert runModal];
        
        if (answer == NSAlertFirstButtonReturn) {
            return NSTerminateCancel;
        }
    }

    return NSTerminateNow;
}

@end
