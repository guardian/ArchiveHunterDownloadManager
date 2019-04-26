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

@property (atomic, strong, nullable) NSNumber* totalSize;
@property (atomic, strong, nullable) NSNumber* bytesDownloaded;
@property (atomic, strong, nullable) NSNumber* downloadRate;

@property (nonatomic, copy) void (^_Nullable progressCb)(NSNumber *_Nonnull bytesDownloaded, NSNumber *_Nonnull totalSize, id _Nullable userData);
@property (atomic, strong, nullable) DownloadDelegate* downloadDelegate;


//internal properties
@property NSNumber* _Nullable _writeFd;
@property NSMutableData* _Nullable _writeBuffer;
@property CURL* _Nullable _curlPtr;
@property NSMutableData* _Nullable downloadBuffer;
@property time_t _startTimestamp;
@property time_t _finishTimestamp;

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
