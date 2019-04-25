//
//  CurlDownloader.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HttpHeadInfo.h"
#import "MMappedFile.h"
#import "DownloadDelegate.h"
#include <curl/curl.h>


size_t header_callback(char *buffer,   size_t size,   size_t nitems,   void *userdata);

@interface CurlDownloader : NSObject
//public properties
@property NSNumber* chunkSize;
@property NSURL* url;
@property NSString* filePath;
@property NSNumber* skipVerification;   //actually boolean
@property HttpHeadInfo* headInfo;
@property MMappedFile* currentFile;

@property NSNumber* totalSize;
@property NSNumber* bytesDownloaded;

@property (nonatomic, copy) void (^progressCb)(NSNumber* bytesDownloaded, NSNumber* totalSize, id userData);
@property (atomic,strong) DownloadDelegate* downloadDelegate;

//internal properties
@property NSNumber* _writeFd;
@property NSMutableData* _writeBuffer;
@property CURL* _curlPtr;
@property NSMutableData* downloadBuffer;

//public methods
- (id) initWithChunkSize:(NSInteger)chunkSize;

- (bool) startDownloadSync:(NSURL *)url
            toFilePath:(NSString *)filePath
                 withError:(NSError **)err;

- (bool) startDownloadAsync:(NSURL *)url
                 toFilePath:(NSString *)filePath
                  withError:(NSError **)err;

//internal methods
- (bool)getUrlInfo:(NSURL *)url withError:(NSError **)err;

- (void) gotNewHeader:(NSString *)headerName withValue:(NSString *)headerValue;
- (size_t) gotBytes:(char *)ptr withSize:(size_t)size withCount:(int)nmemb;

@end
