//
//  MMappedFile.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMappedFile : NSObject

@property NSString* fileName;

//internal properties
@property int _fd;
@property char* raw_ptr;
@property long long _size;

- (id) initWithFile:(NSString *)filePath;

- (bool) open:(int)oFlag withSize:(size_t)size withError:(NSError **)err;
//if reading only, you can use this one which determines the size from the filesystem
- (bool) open:(int)oFlag withError:(NSError **)err;

- (bool) close;
//- (NSMutableData *)dataForMap;
- (bool) write:(char *)bytes withLength:(size_t)len withOffset:(size_t)off;
- (NSData *) read:(size_t)len fromOffset:(size_t)off withError:(NSError **)err;
- (const char *) peekBytesAtOffset:(size_t)off;

//internal methods
- (int) mProtForOpenFlag:(int)oFlag;
@end
