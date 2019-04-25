//
//  EtagCalculator.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import "MMappedFile.h"
#import "ChunkDigest.h"

@interface EtagCalculator : NSObject
- (id)initForFilepath:(NSString *)filePath forChunkSize:(NSInteger)chunkSize withThreads:(NSInteger)threads;
- (NSString *)executeWithError:(NSError **)err;

@property NSNumber* chunkSize;
@property NSNumber* chunkCount;

@property MMappedFile* _mappedFile;
@property NSArray* _threadPool;
@property NSMutableArray<ChunkDigest *> *chunkDigests;
@property NSString* finalDigest;
@property NSLock* _outputArrayMutex;
@property NSLock* _inputArrayMutex;
@property NSMutableArray* _inputStack;

//internal methods
- (void) setupThreadPool:(NSInteger) count;
//called by the threads in threadpool to perform the digest
- (void) threadedDigestChunk:(id)userData;
- (void) calculateFinalDigest;

@end
