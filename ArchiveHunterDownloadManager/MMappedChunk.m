//
//  MMappedChunk.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "MMappedChunk.h"

@implementation MMappedChunk

- (id) init:(MMappedFile*)file forRange:(NSRange)range withIndex:(NSInteger) index
{
    self = [super init];
    [self setFile:file];
    [self setFileRange:range];
    [self setIndex:index];
    _terminationMarker=false;
    return self;
}

- (id) initForTerminationMarker:(MMappedFile *) file
{
    self = [super init];
    [self setFile:file];
    _terminationMarker = true;
    return self;
}

- (bool) loadInData {
//    _data = [_file read:_fileRange.length fromOffset:_fileRange.location withError:nil];
//    if(!_data) return false;
//    return true;
    _buffer = [_file peekBytesAtOffset:_fileRange.location];
    if(!_buffer) return false;
    return true;
}

@end
