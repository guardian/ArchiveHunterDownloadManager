//
//  EtagCalculatorTests.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "EtagCalculator.h"

@interface EtagCalculatorTests : XCTestCase

@end

@implementation EtagCalculatorTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    system("curl https://s3-eu-west-1.amazonaws.com/gnm-multimedia-cdn/interactive/speedtest/testfile.dat > /tmp/testfile.3");
    system("curl https://s3-eu-west-1.amazonaws.com/gnm-multimedia-cdn/interactive/speedtest/testmpfile.dat > /tmp/testfile.4");
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    
}

- (void)testEtagCalculatorMT {
    NSError *err=nil;
    EtagCalculator *calc = [[EtagCalculator alloc] initForFilepath:@"/tmp/testfile.4" forChunkSize:8388608 withThreads:4];
    
    NSString *etag = [calc executeWithError:&err];
    XCTAssertNotNil(etag);
    if(err){
        NSLog(@"test error: %@", [err localizedDescription]);
    }
    XCTAssertNil(err);
    NSLog(@"etag was %@", etag);
    XCTAssertEqual([etag compare:@"ee32e01c6f0941f94330fc994dc6f31d-2"], NSOrderedSame);
}

- (void)testEtagCalculatorSingle {
    NSError *err=nil;
    EtagCalculator *calc = [[EtagCalculator alloc] initForFilepath:@"/tmp/testfile.3" forChunkSize:1024*200 withThreads:4];
    
    NSString *etag = [calc executeWithError:&err];
    XCTAssertNotNil(etag);
    if(err){
        NSLog(@"test error: %@", [err localizedDescription]);
    }
    XCTAssertNil(err);
    NSLog(@"etag was %@", etag);
    XCTAssertEqual([etag compare:@"fb16181d067d2dd96368d52d2de3fe2d"], NSOrderedSame);
}

@end
