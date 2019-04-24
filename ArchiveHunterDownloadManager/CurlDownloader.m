//
//  CurlDownloader.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "CurlDownloader.h"

//libcurl callbacks

/**
 called when we encounter a header.  Extracts key and value then pushes them back to the main class.
 */
size_t header_callback(char *buffer,   size_t size,   size_t nitems,   void *userdata)
{
    CurlDownloader* downloaderPtr=(__bridge CurlDownloader *)userdata;
    
    NSData *data = [NSData dataWithBytes:buffer length:size*nitems];
    NSString *completeLine = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    //NSLog(@"debug: got header line %@", completeLine);
    
    if([completeLine hasPrefix:@"HTTP"]){   //handle protocol line seperately
        NSArray* list = [completeLine componentsSeparatedByString:@" "];
        if([list count]>2){
            [downloaderPtr gotNewHeader:@"Version" withValue:[list objectAtIndex:0]];
            [downloaderPtr gotNewHeader:@"StatusCode" withValue:[list objectAtIndex:1]];
            [downloaderPtr gotNewHeader:@"StatusString" withValue:[list objectAtIndex:2]];
         } else {
             NSLog(@"Invalid protocol header: %@", completeLine);
         }
         return [data length];
    } else {
        @try {
            NSRange colonLoc = [completeLine rangeOfString:@":"];
            if(colonLoc.location<[completeLine length]){
                NSString *key = [completeLine substringToIndex:colonLoc.location];
                NSString *value = [[completeLine substringFromIndex:colonLoc.location+1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                [downloaderPtr gotNewHeader:key withValue:value];
            }
        } @catch (NSException *exception) {
            NSLog(@"Couldn't handle header line: %@, got a %@", completeLine, exception);
        } @finally {
            return [data length];
        }
    }
}

@implementation CurlDownloader
//public methods
- (id) initWithChunkSize:(NSInteger)chunkSize
{
    self = [super init];
    _chunkSize = [NSNumber numberWithInteger:chunkSize];
    _skipVerification = [NSNumber numberWithBool:NO];
    __curlPtr = NULL;
    _headInfo = [[HttpHeadInfo alloc] init];
    return self;
}


//internal methods
- (NSError*) curlErrorToNSError:(CURLcode)result
{
    return [[NSError alloc] initWithDomain:@"libcurl" code:result userInfo:NULL];
}

- (bool)getUrlInfo:(NSURL *)url withError:(NSError **)err
{
    __curlPtr = curl_easy_init();
    curl_easy_setopt(__curlPtr, CURLOPT_URL, [[url absoluteString] cStringUsingEncoding:NSUTF8StringEncoding]);
    curl_easy_setopt(__curlPtr, CURLOPT_NOBODY, 1L);
    curl_easy_setopt(__curlPtr, CURLOPT_HEADERFUNCTION, &header_callback);
    curl_easy_setopt(__curlPtr, CURLOPT_HEADERDATA, self);
    
    CURLcode result = curl_easy_perform(__curlPtr);
    
    //[_headInfo dumpForDebug];
    
    if(result!=CURLE_OK){
        if(err) *err = [self curlErrorToNSError:result];
        return false;
    }
    
    curl_easy_cleanup(__curlPtr);
    __curlPtr = NULL;
    if([[_headInfo statusCode] intValue]<200 || [[_headInfo statusCode] intValue]>299){
        NSDictionary *userInfoDict = [NSDictionary dictionaryWithObjectsAndKeys:url, @"URL", [_headInfo statusString], @"statusString", nil];
        if(err) *err = [[NSError alloc] initWithDomain:@"HTTP" code:[[_headInfo statusCode] intValue] userInfo:userInfoDict];
        return false;
    }
    return true;
}

- (void)gotNewHeader:(NSString *)headerName withValue:(NSString *)headerValue
{
    //NSLog(@"Got header: %@ with value %@", headerName, headerValue);
    
    if([headerName compare:@"ETag"]==NSOrderedSame){
        [_headInfo setETag:headerValue];
    } else if([headerName compare:@"Content-Type"]==NSOrderedSame){
        [_headInfo setContentType:headerValue];
    } else if([headerName compare:@"Accept-Ranges"]==NSOrderedSame){
        [_headInfo setAcceptRanges:headerValue];
    } else if([headerName compare:@"Server"]==NSOrderedSame){
        [_headInfo setServer:headerValue];
    } else if([headerName compare:@"Version"]==NSOrderedSame){
        [_headInfo setProto:headerValue];
    } else if([headerName compare:@"StatusCode"]==NSOrderedSame){
        [_headInfo setStatusCode:[NSNumber numberWithInteger:[headerValue integerValue]]];
    } else if([headerName compare:@"StatusString"]==NSOrderedSame){
        [_headInfo setStatusString:[headerValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    } else if([headerName compare:@"Last-Modified"]==NSOrderedSame){
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"];
        [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]];
        
        [_headInfo setModTime:[dateFormatter dateFromString:headerValue]];
        
    } else if([headerName compare:@"Content-Length"]==NSOrderedSame){
        NSNumber* actualSize = [NSNumber numberWithLongLong:[headerValue longLongValue]];
        [_headInfo setSize:actualSize];
    }
   
}

- (NSMutableData *) mapFileForWrite:(NSString *)filePath
{
    __writeFd = [NSNumber numberWithInt:open([filePath cStringUsingEncoding:NSUTF8StringEncoding],O_WRONLY)];
    
    void *rawPtr = mmap(NULL, [[_headInfo size] longLongValue], PROT_WRITE, MAP_FILE|MAP_PRIVATE, [__writeFd intValue], 0);
    
    return [NSMutableData dataWithBytes:rawPtr length:[[_headInfo size] longLongValue]];
                                       
}
@end


