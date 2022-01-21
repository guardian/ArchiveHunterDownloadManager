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
    
    NSUserDefaults *dfl = [NSUserDefaults standardUserDefaults];
    
    NSUInteger concurrency = [[dfl valueForKey:@"maxConcurrentDownloads"] integerValue];
    
    _queueManager = [[DownloadQueueManager alloc] initWithConcurrency:concurrency];
    _bulkOperations = [[BulkOperations alloc] initWithQueueManager:[self queueManager]];
    _serverComms = [[ServerComms alloc] init];
    
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    NSUserDefaults *dfl = [NSUserDefaults standardUserDefaults];
    
    [dfl addObserver:self forKeyPath:@"maxConcurrentDownloads" options:NSKeyValueObservingOptionNew context:nil];
    
    //at first startup, ensure autoStart is on
    if([dfl valueForKey:@"autoStart"]==nil) [dfl setValue:[NSNumber numberWithBool:YES] forKey:@"autoStart"];
    
     [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
}

- (void)applictionWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if([keyPath compare:@"maxConcurrentDownloads"]==NSOrderedSame){
        NSLog(@"updated concurrent downloads setting");
        NSNumber *newValue=[change valueForKey:NSKeyValueChangeNewKey];
        [_queueManager setConcurrency:[newValue integerValue]];
    }
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
- (NSManagedObject *) createNewBulk:(NSDictionary *)bulkMetadata retrievalToken:(NSString *)retrievalToken forServerType:(NSString *)serverType
{
    NSManagedObjectContext *ctx = [self managedObjectContext];
    
    NSManagedObject* ent=[NSEntityDescription insertNewObjectForEntityForName:@"BulkDownload" inManagedObjectContext:ctx];

    [ent setValuesForKeysWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [bulkMetadata objectForKey:@"description"], @"downloadDescription",
                                         [bulkMetadata objectForKey:@"id"], @"id",
                                         retrievalToken, @"retrievalToken",
                                         [NSNumber numberWithInteger:0], @"Status",
                                         [bulkMetadata objectForKey:@"userEmail"], @"userEmail",
                                         [NSNumber numberWithLongLong:0], @"totalSize",
                                         [NSNumber numberWithLongLong:0], @"amountDownloaded",
                                         serverType, @"serverSource",
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
        NSString *token = [components objectAtIndex:2];
        [self initialiseDownloadFromUrl:token forServerType:@"archivehunter"];
    } else if([[components objectAtIndex:1] compare:@"vaultdownload"]==NSEqualToComparison){
        NSString *token = [components objectAtIndex:2];
        [self initialiseDownloadFromUrl:token forServerType:@"vaultdoor"];
    } else {
        NSAlert *a = [[NSAlert alloc] init];
        [a setMessageText:@"Couldn't understand URL"];
        [a setInformativeText:[NSString stringWithFormat:@"The provided custom URL %@ is not valid, second part did not identify a download type", urlString]];
        [a runModal];
    }
}

- (void) initialiseDownloadFromUrl:(NSString *)token forServerType:(NSString *)serverType
{
    NSError *err;
    NSLog(@"Got bulk download with onetime token %@", token);
    
    BOOL result = [_serverComms initiateDownload:token forServerSource:serverType withError:&err completionHandler:^(NSDictionary *_Nullable data, NSError *err){
        NSError *localErr=nil;
        
        if(err){
            NSLog(@"Download error: %@", err);
            
            if([[err domain] compare:@"servercomms"]!=NSOrderedSame){
                NSString *errorString = [NSString stringWithFormat:@"%@", err];
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:@"Download Error"];
                
                NSString *truncatedErrorString = [errorString length]>256 ? [errorString substringToIndex:256] : errorString;
                
                [alert setInformativeText:[NSString stringWithFormat:@"A download error occured: %@", truncatedErrorString]];
                [alert addButtonWithTitle:@"Okay"];
                [alert runModal];
            }
        } else {
            //NSLog(@"Got data: %@", data);
            NSDictionary *metadata = [data objectForKey:@"metadata"];
            
            if([self haveBulkEntryFor:[metadata valueForKey:@"id"] withError:&localErr]){
                [(ViewController *)_mainViewController showErrorBox:@"You already have this bulk in your download queue"];
            } else {
                NSManagedObject *bulk = [self createNewBulk:metadata
                                             retrievalToken:[data objectForKey:@"retrievalToken"]
                                              forServerType: serverType];
                
                [self getEntities:bulk];
                
                [[self managedObjectContext] save:&err];
                if(err){
                    NSLog(@"could not save data store: %@", err);
                }
                
                if( [ [bulk valueForKey:@"totalSize"] isEqualToNumber:[NSNumber numberWithInt:0] ]) {
                    NSLog(@"There are no items to download!");
                    NSAlert *alert = [[NSAlert alloc] init];
                    [alert setMessageText:@"Download Error"];
                    [alert setInformativeText:[NSString stringWithFormat:@"There are no items to download!"]];
                    [alert addButtonWithTitle:@"Okay"];
                    [alert runModal];
                    [[self managedObjectContext] deleteObject:bulk];
                } else {
                    [self asyncSetupDownload:bulk];
                }
            }
        }
    }];
    if(!result){
        NSLog(@"Download failed: %@", err);
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
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL autoStart = [[defaults valueForKey:@"autoStart"] boolValue];
    
    NSLog(@"asyncSetupDownlaod");
    
    if(![[self bulkOperations] moc]) [[self bulkOperations] setMoc:[self managedObjectContext]];
    
    if(![[self managedObjectContext] save:&err]){
        NSLog(@"Could not save managed objects: %@", err);
    }
    
    dispatch_queue_t targetQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    dispatch_async(targetQueue, ^{
        NSError *err;
        NSLog(@"asyncSetupDownload - in block");
        BulkOperationStatus status = [_bulkOperations startBulk:bulk autoStart:autoStart];
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
                
		dispatch_async(dispatch_get_main_queue(), ^{
			NSString *errorString = [NSString stringWithFormat:@"%@", err];
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:@"Save Error"];
			[alert setInformativeText:[NSString stringWithFormat:@"A saving error occured: %@", [errorString substringToIndex:256]]];
			[alert addButtonWithTitle:@"Okay"];
			[alert runModal];
		});
            }
        }
    });
}

- (NSString *_Nullable)getReterievalToken:(NSManagedObject *) bulk {
    @try {
        return [bulk valueForKey:@"retrievalToken"];
    } @catch (NSException *exception) {
        NSLog(@"Caught exception: %@", exception);
        return nil;
    }
}

- (NSString *_Nullable)getServerType:(NSManagedObject *) bulk {
    @try {
        return [bulk valueForKey:@"serverSource"];
    } @catch (NSException *exception) {
        NSLog(@"Caught exception: %@", exception);
        return nil;
    }
}

- (NSString *) hostNameForServerSource:(NSString *)serverSource
{
    NSLog(@"hostNameForServerSource: source is %@", serverSource);
    
    if([serverSource compare:@"vaultdoor" options:0]==NSEqualToComparison){
        return [[NSUserDefaults standardUserDefaults] valueForKey:@"vaultDoorHost"];
    } else {
        return [[NSUserDefaults standardUserDefaults] valueForKey:@"serverHost"];
    }
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
        NSNumber *versionNo = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleShortVersionString"];
        
        NSString *dataStoreFilename = [NSString stringWithFormat:@"coredata-%@.storedata", versionNo];
        NSURL *url = [applicationDocumentsDirectory URLByAppendingPathComponent:dataStoreFilename];
        NSLog(@"Loading persistent data from %@", url);
        
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

- (void) getEntities:(NSManagedObject *)bulk {
    NSString *token = [self getReterievalToken:bulk];
    if (token == nil) {
        NSLog(@"token is nil so getEntities can not continue.");
        return;
    }
    NSString *serverType = [self getServerType:bulk];
    if (serverType == nil) {
        NSLog(@"serverType is nil so getEntities can not continue.");
        return;
    }
    NSString *serverHost = [self hostNameForServerSource:serverType];
    NSURL *apiURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/bulkv2/%@/summarystream", serverHost, token]];
    NSData *urlData = [NSData dataWithContentsOfURL:apiURL];
    NSString *strData = [[NSString alloc]initWithData:urlData encoding:NSUTF8StringEncoding];
    NSArray *arrayOfEntities = [strData componentsSeparatedByString:@"\n"];
    long long totalSize = 0;
    
    for(NSString *jsonString in arrayOfEntities) {
        NSData* jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        NSError * error=nil;
        NSDictionary * inputDic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];
        [self createNewEntry:inputDic parent:bulk];
        NSNumber *fileSize = [inputDic valueForKey:@"fileSize"];
        totalSize = [fileSize longLongValue] + totalSize;
    }
        
    [bulk setValue:[NSNumber numberWithLongLong:totalSize] forKey:@"totalSize"];
}
@end
