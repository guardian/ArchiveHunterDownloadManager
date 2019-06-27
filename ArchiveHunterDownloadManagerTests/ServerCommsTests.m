//
//  ServerCommsTests.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 27/06/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <CoreData/CoreData.h>
#import "ServerComms.h"

@interface ServerCommsTests : XCTestCase
@property (atomic) NSManagedObjectContext *managedObjectContext;
@end

@implementation ServerCommsTests

- (void) setUp {
    //This resource is the same name as your xcdatamodeld contained in your project
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"ArchiveHunterDownloadManager" withExtension:@"momd"];
    NSAssert(modelURL, @"Failed to locate momd bundle in application");
    // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
    NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    NSAssert(mom, @"Failed to initialize mom from URL: %@", modelURL);
    
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [moc setPersistentStoreCoordinator:coordinator];
    [self setManagedObjectContext:moc];

}

- (void) tearDown {
    
}

- (void) testSetEntryErrorWithLocalizedDescription {
    NSDictionary *userInfoDict = [NSDictionary dictionaryWithObjectsAndKeys:@"some error description",@"localizedDescription", nil];
    
    NSError *testError = [NSError errorWithDomain:@"ArchiveHunter" code:2 userInfo:userInfoDict];
    
    NSManagedObject *obj = [NSEntityDescription insertNewObjectForEntityForName:@"DownloadEntity" inManagedObjectContext:[self managedObjectContext]];
    
    ServerComms *toTest = [[ServerComms alloc] init];
    [toTest setEntryError:testError forEntry:obj];
    
    NSString *setError = [obj valueForKey:@"lastError"];
    NSLog(@"set %@", setError);
    
    XCTAssertEqual([setError compare:@"some error description"], NSOrderedSame);
}
@end
