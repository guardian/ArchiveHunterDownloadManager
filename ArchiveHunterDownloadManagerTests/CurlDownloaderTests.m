//
//  CurlDownloaderTests.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CurlDownloader.h"

@interface CurlDownloaderTests : XCTestCase

@end

@implementation CurlDownloaderTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

/**
 getUrlInfo should populate the headInfo object with content from the HTTP header
 */
- (void)testGetUrlInfo {
    NSError *err = NULL;
    CurlDownloader *downloader = [[CurlDownloader alloc] initWithChunkSize:4096];
    
    bool result = [downloader getUrlInfo:[NSURL URLWithString:@"https://s3-eu-west-1.amazonaws.com/gnm-multimedia-cdn/interactive/speedtest/testfile.dat"] withError:&err];
    
    XCTAssertEqual(result, true);
    XCTAssertEqual(err, NULL);
    XCTAssertEqual([[[downloader headInfo] eTag] compare:@"\"fb16181d067d2dd96368d52d2de3fe2d\""], NSOrderedSame);
    XCTAssertEqual([[downloader headInfo] size], [NSNumber numberWithLongLong:102400]);
    XCTAssertEqual([[[downloader headInfo] acceptRanges] compare:@"bytes"], NSOrderedSame);
    XCTAssertEqual([[[downloader headInfo] contentType] compare:@"application/x-ns-proxy-autoconfig"], NSOrderedSame);
    XCTAssertEqual([[[downloader headInfo] server] compare:@"AmazonS3"], NSOrderedSame);
}

/**
 getUrlInfo should handle HTTP errors by returning false and setting the error parameter
 */
- (void)testGetUrlInfoErrors {
    NSError *err = NULL;
    CurlDownloader *downloader = [[CurlDownloader alloc] initWithChunkSize:4096];
    
    bool result = [downloader getUrlInfo:[NSURL URLWithString:@"https://s3-eu-west-1.amazonaws.com/gnm-multimedia-cdn/invalid-url-here"] withError:&err];
    
    XCTAssertEqual(result, false);
    XCTAssertNotNil(err);
    XCTAssertEqual([err code], 403);
    NSLog(@"'%@'", [[err userInfo] valueForKey:@"statusString"]);
    
    XCTAssertEqual([[[err userInfo] valueForKey:@"statusString"] compare:@"Forbidden"], NSOrderedSame);
}

/**
 the header callback should extract key and value from the header then call back to the main class to set the relevant value in headInfo
 */
-(void) testHeaderCallback {
    CurlDownloader *downloader = [[CurlDownloader alloc] initWithChunkSize:4096];
    XCTAssertNotEqual([downloader headInfo], NULL);
    NSString *testLine = @"ETag: \"some-etag\"";
    
    header_callback((char *)[testLine cStringUsingEncoding:NSUTF8StringEncoding], 1, [testLine length], (__bridge void *)downloader);
    
    XCTAssertNotEqual([downloader headInfo], NULL);
    NSLog(@"etag is %@", [[downloader headInfo] eTag]);
    XCTAssertEqual([[[downloader headInfo] eTag] compare:@"\"some-etag\""], NSOrderedSame);
}

@end
