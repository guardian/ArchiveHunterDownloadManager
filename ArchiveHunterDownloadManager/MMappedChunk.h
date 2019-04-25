//
//  MMappedChunk.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMappedFile.h"

@interface MMappedChunk : NSObject
@property bool terminationMarker;
@property NSRange fileRange;
@property const char* buffer;
@property NSInteger index;
//@property NSData* data;
@property (weak) MMappedFile *file;

- (id) init:(MMappedFile*)file forRange:(NSRange)range withIndex:(NSInteger) index;
- (id) initForTerminationMarker:(MMappedFile *) file;

//actually reference the data. This is done just-in-time for performance reasons.
- (bool) loadInData;
@end
