//
//  BulkOperationsTests.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 11/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BulkOperations.h"

@interface BulkOperationsTests : XCTestCase

@end

@implementation BulkOperationsTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testStripCommonPathComponentsFromRoot {
    BulkOperations *op = [[BulkOperations alloc] init];
    
    NSString *result = [op stripCommonPathComponents:@"/path/to/my" forEntryPath:@"/path/to/my/download/directory"];
    NSLog(@"stripCommonPathComponents: %@",result);
    XCTAssertEqual([result compare:@"/path/to/my/download/directory"], NSOrderedSame);
}

- (void)testStripCommonPathComponentsFromMiddle {
    BulkOperations *op = [[BulkOperations alloc] init];
    
    NSString *result = [op stripCommonPathComponents:@"/path/to/my/downloads" forEntryPath:@"downloads/projectname/media"];
    NSLog(@"stripCommonPathComponents: %@",result);
    XCTAssertEqual([result compare:@"/path/to/my/downloads/projectname/media"], NSOrderedSame);
}

- (void)testStripCommonPathComponentsCompletelyDifferent {
    BulkOperations *op = [[BulkOperations alloc] init];
    
    NSString *result = [op stripCommonPathComponents:@"/path/to/my/downloads" forEntryPath:@"projectname/media"];
    NSLog(@"stripCommonPathComponents: %@",result);
    XCTAssertEqual([result compare:@"/path/to/my/downloads/projectname/media"], NSOrderedSame);
}

- (void)testStripCommonPathComonentsBucketRoot {
    BulkOperations *op = [[BulkOperations alloc] init];
    
    NSString *result = [op stripCommonPathComponents:@"/path/to/my" forEntryPath:@""];
    NSLog(@"stripCommonPathComponents: %@",result);
    XCTAssertEqual([result compare:@"/path/to/my"], NSOrderedSame);
}

@end
