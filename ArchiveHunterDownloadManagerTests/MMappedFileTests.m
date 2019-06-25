//
//  MMappedFileTests.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MMappedFile.h"

@interface MMappedFileTests : XCTestCase

@end

@implementation MMappedFileTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/testfile.1" error:nil];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/testfile.1" error:nil];
}

/**
 mProtForOpenFlag should return appropriate memory flags for the given filesystem mode
 */
- (void) testmProtForOpenFlag{
    MMappedFile *f = [[MMappedFile alloc] initWithFile:@"/tmp/testfile.2"];
    XCTAssertEqual([f mProtForOpenFlag:O_CREAT|O_EXCL|O_WRONLY], PROT_WRITE);
    XCTAssertEqual([f mProtForOpenFlag:O_RDONLY], PROT_READ);
    XCTAssertEqual([f mProtForOpenFlag:O_WRONLY], PROT_WRITE);
    XCTAssertEqual([f mProtForOpenFlag:O_RDWR], PROT_WRITE|PROT_READ);
}

- (void) hexDumpString:(NSString *)str
{
    for(int n=0;n<[str length]; ++n){
        NSLog(@"0x%02x", [str characterAtIndex:n]);
    }
}

/**
 we should be able to create a file and write to it via mmap
 */
- (void)testMmapedFileCreate {
    NSError *err = nil;
    MMappedFile *f = [[MMappedFile alloc] initWithFile:@"/tmp/testfile.1"];
    
    bool result = [f open:O_CREAT|O_EXCL|O_RDWR withSize:11 withError:&err];
    
    XCTAssertTrue(result);
    XCTAssertNil(err);
    
    if(result){
        //NSMutableData *data = [f dataForMap];
        NSString *testString=@"Hello world";
        
        //[data replaceBytesInRange:r withBytes:[testString cStringUsingEncoding:NSISOLatin1StringEncoding]];
        [f write:(char *)[testString cStringUsingEncoding:NSISOLatin1StringEncoding] withLength:[testString length] withOffset:0];
        XCTAssertTrue([f close]);
        
        NSString *readBack = [[NSString stringWithContentsOfFile:@"/tmp/testfile.1"
                                                        encoding:NSISOLatin1StringEncoding
                                                           error:&err] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        
        XCTAssertEqual([readBack compare:@"Hello world"], NSOrderedSame);
    }
}


@end
