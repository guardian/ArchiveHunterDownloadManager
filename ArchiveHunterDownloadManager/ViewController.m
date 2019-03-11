//
//  ViewController.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 05/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "ViewController.h"

@implementation ViewController
@synthesize appDelegate;
@synthesize bulkSelectionIndices;

- (id) init {
    self = [super init];
    _downloadEntryFilterPredicate = [NSPredicate predicateWithValue:FALSE];
    [self setPossiblePriotities:[NSArray arrayWithObjects:@"High",@"Normal",@"Low",@"Ignore", nil]];
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    NSLog(@"observeValueForKeyPath: %@", keyPath);
    
    if([keyPath compare:@"selectionIndex"]==NSOrderedSame){
        [self setDownloadEntryFilterPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            NSManagedObject *entry = (NSManagedObject *)evaluatedObject;
            NSManagedObject *parent = [entry valueForKey:@"parent"];
            return [parent valueForKey:@"id"]== [[[self bulkArrayController] selection] valueForKey:@"id"];
        }]];
    }
}
- (void)viewDidLoad {
    [super viewDidLoad];

    [_bulkArrayController addObserver:self forKeyPath:@"selectionIndex" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial context:nil];
    
    // Do any additional setup after loading the view.
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (IBAction)testClicked:(id)sender {
    NSError *err;
    NSManagedObjectContext *ctx = [[self appDelegate] managedObjectContext];
    
    NSManagedObject* ent=[NSEntityDescription insertNewObjectForEntityForName:@"DownloadEntity" inManagedObjectContext:ctx];
    [ent setValuesForKeysWithDictionary:
     [NSDictionary dictionaryWithObjectsAndKeys:
      @"test1",@"name",
      [NSNumber numberWithDouble:0.5], @"downloadProgress",
      @"Normal", @"priority",
      nil]
     ];
    [ctx save:&err];
    if(err){
        NSLog(@"Could not save: %@", err);
    }
}

- (IBAction)editClicked:(id)sender {
    NSWindow *window = [[self view] window];
    NSArray *selection = [_bulkArrayController selectedObjects];
    if([selection count]==0){
        NSAlert *alrt = [[NSAlert alloc] init];
        [alrt setInformativeText:@"You must select a bulk entry to edit"];
        [alrt beginSheetModalForWindow:window completionHandler:^(NSInteger result){
            
        }];
    } else {
        NSManagedObject *selectedBulk = [selection objectAtIndex:0];
        [self askUserForPath:selectedBulk];
    }
}

- (IBAction)runClicked:(id)sender {
    NSWindow *window = [[self view] window];
    NSError *err;
    
    BOOL result = [BulkOperations bulkForAll:[[self appDelegate] managedObjectContext] withError:&err block:^(NSManagedObject *bulk){
        [[[self appDelegate] bulkOperations] startBulk:bulk];
    }];
    
    if(!result){
        NSAlert *alrt = [NSAlert alertWithError:err];
        [alrt beginSheetModalForWindow:window completionHandler:nil];
    }
    
}

- (IBAction)revealClicked:(id)sender {
    NSWindow *window = [[self view] window];
    NSArray *selection = [_bulkArrayController selectedObjects];
    if([selection count]==0){
        NSAlert *alrt = [[NSAlert alloc] init];
        [alrt setInformativeText:@"You must select a bulk entry to reveal"];
        [alrt beginSheetModalForWindow:window completionHandler:^(NSInteger result){
            
        }];
    } else {
        NSManagedObject *selectedBulk = [selection objectAtIndex:0];
        
        NSString *bulkDir = [selectedBulk valueForKey:@"destinationPath"];
        if(bulkDir){
            [[NSWorkspace sharedWorkspace] openFile:bulkDir];
        } else {
            NSAlert *alrt = [[NSAlert alloc] init];
            [alrt setInformativeText:@"You need to set a download path before reveal in finder can work"];
            [alrt beginSheetModalForWindow:window completionHandler:^(NSInteger result){
                
            }];
        }
    }
}
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

- (void) showErrorBox:(NSString *)msg {
    NSWindow *window = [[self view] window];

    NSAlert *alrt = [[NSAlert alloc] init];
    [alrt setInformativeText:msg];
    [alrt beginSheetModalForWindow:window completionHandler:nil];
}


@end
