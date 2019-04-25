//
//  EtagCalculator.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "EtagCalculator.h"
#import "MMappedChunk.h"

@implementation EtagCalculator
- (id)initForFilepath:(NSString *)filePath forChunkSize:(NSInteger)chunkSize withThreads:(NSInteger)threads
{
    self = [super init];
    __inputArrayMutex = [[NSLock alloc] init];
    __outputArrayMutex = [[NSLock alloc] init];
    
    __inputStack = [NSMutableArray array];
    _chunkDigests = [NSMutableArray array];
    
    [self setChunkSize:[NSNumber numberWithInteger:chunkSize]];
    [self setupThreadPool:threads];
    __mappedFile = [[MMappedFile alloc] initWithFile:filePath];
    return self;
}

- (void) dealloc {
    NSLog(@"ETagCalculator dealloc");
    if(__mappedFile) [__mappedFile close];  //this removes the mapping and closes the file descriptor
}

- (NSString *)executeWithError:(NSError *__autoreleasing *)err
{
    bool result;
    result = [__mappedFile open:O_RDONLY withError:err];
    if(!result) return NULL;    //err should contain error info
    
    if([__mappedFile _size]<[[self chunkSize] longLongValue]){
        return [self singleExecuteWithError:err];
    } else {
        return [self MTexecuteWithError:err];
    }
}

- (NSString *)singleExecuteWithError:(NSError **)err
{
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    MMappedChunk *chunk = [[MMappedChunk alloc] init:__mappedFile forRange:NSMakeRange(0, [__mappedFile _size]) withIndex:0];
    [chunk loadInData];
    
    CC_MD5([chunk buffer], (CC_LONG)[chunk fileRange].length, result);
    
    [self setFinalDigest:[self hexStringFromBinary:result]];
    return [self finalDigest];
}

- (NSString *)MTexecuteWithError:(NSError **)err
{
    bool result;
    
    NSInteger idx=0;
    
    //adding chunks of file to queue and let it roll....
    for(off_t offset; offset<[__mappedFile _size];offset+=[[self chunkSize] longLongValue]){
        NSUInteger chunkSize;
        
        chunkSize = [[self chunkSize] integerValue];
        //last chunk is smaller
        if(offset+chunkSize>[__mappedFile _size]){
            chunkSize = [__mappedFile _size]-offset;
        }
        
        NSLog(@"enqueueing chunk %lu of size %lu from offset %llu", idx, chunkSize, offset);
        
        MMappedChunk *inputChunk = [[MMappedChunk alloc] init:__mappedFile forRange:NSMakeRange(offset, chunkSize) withIndex:idx];
        [__inputArrayMutex lock];
        [__inputStack addObject:inputChunk];
        [__inputArrayMutex unlock];
        idx+=1;
    }
    [self setChunkCount:[NSNumber numberWithInteger:idx]];
    
    //wait until we have the expected number of outputs
    NSUInteger currentCount;
    while(1){
        sleep(5);
        [__outputArrayMutex lock];
        currentCount = [_chunkDigests count];
        [__outputArrayMutex unlock];
        NSLog(@"waiting for %@ chunks, got %lu", [self chunkCount], currentCount);
        if([[self chunkCount] longValue]==currentCount) break;
    }
    
    for(int c=0;c<[[self _threadPool] count];++c){
        MMappedChunk *termChunk = [[MMappedChunk alloc] initForTerminationMarker:__mappedFile];
        [__inputArrayMutex lock];
        [__inputStack addObject:termChunk];
        [__inputArrayMutex unlock];
    }
    
    //now the threads should be terminating. calculate the final digest.
    [self calculateFinalDigest];
    return [[NSString alloc] initWithFormat:@"%@-%@", [self finalDigest], [self chunkCount]];
}

- (void) setupThreadPool:(NSInteger) count
{
    NSMutableArray *temp=[NSMutableArray arrayWithCapacity:count];
    
    for(int n=0;n<count;++n){
        NSThread *t=[[NSThread alloc] initWithTarget:self selector:@selector(threadedDigestChunk:) object:nil];
        [t start];
        [temp addObject:t];
    }
    [self set_threadPool:temp];
}

/**
 this function is actually the guts of a thread that does the digesting
 */
- (void) threadedDigestChunk:(id)userData
{
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    
    while(1){
        [__inputArrayMutex lock];
        MMappedChunk *chunk = [__inputStack lastObject];
        if(chunk!=nil) [__inputStack removeLastObject];
        [__inputArrayMutex unlock];
        
        if(chunk==nil){ //nothing on the queue
            NSLog(@"thread waiting for data");
            usleep(500000); //sleep 1/2 second and try again
            continue;
        }
        memset(&result, 0, CC_MD5_DIGEST_LENGTH);
        
        NSLog(@"thread got chunk");
        if([chunk terminationMarker]) NSLog(@"chunk is termination marker");
        if([chunk terminationMarker]) return;
        
        if(![chunk loadInData]){
            NSLog(@"Could not load in data");
            continue;
        }
        
        CC_MD5([chunk buffer], (CC_LONG)[chunk fileRange].length, result);
        ChunkDigest *ch = [[ChunkDigest alloc] init:[NSData dataWithBytes:&result length:CC_MD5_DIGEST_LENGTH] forIndex:[chunk index]];
        
        [__outputArrayMutex lock];
        [_chunkDigests addObject:ch];
        [__outputArrayMutex unlock];
    }
}

- (NSString *)hexStringFromBinary:(unsigned char *)buffer
{
    NSMutableString *stringBuild = [NSMutableString stringWithCapacity:2*CC_MD5_DIGEST_LENGTH];
    for(int i=0;i<CC_MD5_DIGEST_LENGTH;++i){
        [stringBuild appendFormat:@"%02x", buffer[i]];
    }
    return stringBuild;
}

/**
 once all of the digests have been calculated, then we munge them all into a byte string and md5 that
 */
- (void) calculateFinalDigest
{
    [__outputArrayMutex lock];
    NSUInteger concatLength = CC_MD5_DIGEST_LENGTH*[_chunkDigests count];
    unsigned char bigString[concatLength];
    
    for(ChunkDigest *ch in _chunkDigests){
        off_t offset = [ch index]*CC_MD5_DIGEST_LENGTH;
        [[ch digest] getBytes:&bigString[offset] range:NSMakeRange(0, CC_MD5_DIGEST_LENGTH)];
    }
    [_chunkDigests removeAllObjects];
    [__outputArrayMutex unlock];
    
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(bigString, (CC_LONG)concatLength, result);
    

    [self setFinalDigest:[self hexStringFromBinary:result]];
}
@end
