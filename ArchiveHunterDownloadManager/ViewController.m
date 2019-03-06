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

- (id) init {
    self = [super init];
    [self setPossiblePriotities:[NSArray arrayWithObjects:@"High",@"Normal",@"Low",@"Ignore", nil]];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

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
@end
