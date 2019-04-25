//
//  ChunkDigest.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "ChunkDigest.h"

@implementation ChunkDigest
- (id) init:(NSData *)digest forIndex:(NSInteger) index
{
    self=[super init];
    _digest = digest;
    _index = index;
    return self;
}
@end
