//
//  ChunkDigest.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ChunkDigest : NSObject
@property NSInteger index;
@property NSData *digest;

- (id) init:(NSData *)digest forIndex:(NSInteger) index;

@end
