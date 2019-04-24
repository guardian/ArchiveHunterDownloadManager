//
//  MMappedFile.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "MMappedFile.h"
#include <sys/mman.h>
#include <errno.h>
extern int errno;

@implementation MMappedFile

- (id) initWithFile:(NSString *)filePath
{
    self = [super init];
    _fileName = filePath;
    return self;
}

- (int) mProtForOpenFlag:(int)oFlag
{
    if(oFlag&O_WRONLY) return PROT_WRITE;
    if(oFlag&O_RDWR) return PROT_READ|PROT_WRITE;
    if(oFlag&O_RDONLY) return PROT_READ;
    //if(oFlag&O_CREAT) return PROT_WRITE;
    return 0;
}

/**
 open the given filepath as an mmap
 */
- (bool) open:(int)oFlag withSize:(size_t)size withError:(NSError **)err;
{
    __size = size;
    if(oFlag&O_CREAT){
        __fd = open([[self fileName] cStringUsingEncoding:NSUTF8StringEncoding], oFlag, S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP|S_IROTH);
    } else {
        __fd = open([[self fileName] cStringUsingEncoding:NSUTF8StringEncoding], oFlag);
    }
    if(__fd==-1){
        if(err){
            *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        }
        return false;
    }

    //extend file to given length. This is necessary when to avoid memory protection errors.
    if(ftruncate(__fd, size)==-1){
        close(__fd);
        __fd=0;
        if(err){
            *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        }
        return false;
    }
    
    _raw_ptr = (char *)mmap(NULL, size, [self mProtForOpenFlag:oFlag], MAP_SHARED|MAP_NOCACHE, __fd, 0);    //MAP_NOCACHE tells the OS it can reclaim these pages early
    if(_raw_ptr==MAP_FAILED){
        close(__fd);
        __fd=0;
        if(err){
            *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        }
        return false;
    }
    return true;
}

/**
 unmap and close the current file
 */
- (bool) close
{
    //FIXME: should make sync optional in arguments
    if(_raw_ptr){
        msync(_raw_ptr,__size, MS_SYNC);
        munmap(_raw_ptr, __size);
        _raw_ptr = NULL;
    }
    if(__fd){
        fsync(__fd);
        close(__fd);
    }
    //REVISIT: should handle errors a bit more
    return true;
}

/**
 return an NSMutableData that can be used to access the map
 */
//- (NSMutableData *)dataForMap
//{
//    if(!_raw_ptr) return nil;
//    return [NSMutableData dataWithBytes:_raw_ptr length:__size];
//}

/**
 push some bytes into the mapped file
 */
- (bool) write:(char *)bytes withLength:(size_t)len withOffset:(size_t)off
{
    if(!_raw_ptr) return false;
    if(off+len > __size) return false;
    
    memcpy(_raw_ptr + off, bytes, len);
    return true;
}
@end
