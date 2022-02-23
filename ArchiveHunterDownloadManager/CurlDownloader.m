//
//  CurlDownloader.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "CurlDownloader.h"
#import <CommonCrypto/CommonDigest.h>

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

/**
 called when data needs to be saved. We just push it across to the mapped file and let the OS take care of flushing to disk.
 */
size_t write_callback(char *ptr, size_t size, size_t nmemb, void *userdata)
{
    CurlDownloader* downloaderPtr=(__bridge CurlDownloader *)userdata;
    
    return [downloaderPtr gotBytes:ptr withSize:size withCount:nmemb];
}

/**
 dummy write callback that causes an immediate abort, if we are not interested in content body
 */
size_t dummy_write_callback(char *ptr, size_t size, size_t nmemb, void *userdata)
{
    return 0;
}

/**
 dummy callback to make curl abort the download
 */
int early_abort_progresscb(void *clientp,   double dltotal,   double dlnow,   double ultotal,   double ulnow)
{
    return 1;
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
    _downloadDelegate = nil;
    _totalSize = nil;
    _bytesDownloaded = nil;
    
    __startTimestamp=-1;
    __finishTimestamp=-1;
    _downloadRate=nil;
    
    return self;
}


//internal methods
- (NSError*) curlErrorToNSError:(CURLcode)result
{
    return [[NSError alloc] initWithDomain:@"libcurl" code:result userInfo:NULL];
}

//this performs a GET rather than a HEAD, because S3 is annoying and won't generate a presigned URL that accepts both HEAD and GET
- (bool)getUrlInfo:(NSURL *)url withError:(NSError **)err
{
    __curlPtr = curl_easy_init();
    curl_easy_setopt(__curlPtr, CURLOPT_URL, [[url absoluteString] cStringUsingEncoding:NSUTF8StringEncoding]);
    //curl_easy_setopt(__curlPtr, CURLOPT_NOBODY, 1L);
    curl_easy_setopt(__curlPtr, CURLOPT_HEADERFUNCTION, &header_callback);
    curl_easy_setopt(__curlPtr, CURLOPT_HEADERDATA, self);
    curl_easy_setopt(__curlPtr, CURLOPT_WRITEFUNCTION, &dummy_write_callback);
    CURLcode result = curl_easy_perform(__curlPtr);
    
    //[_headInfo dumpForDebug];
    if(result==CURLE_WRITE_ERROR) result=CURLE_OK;  //we expect to be aborted by callback, it's not an error.
    
    return [self handleCurlResult:result forUrl:url withError:err];
}

- (bool) handleCurlResult:(CURLcode)result forUrl:(NSURL*)url withError:(NSError **)err
{
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
        [_headInfo setETag:[headerValue stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\" "]]];
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

- (bool) internalSetupDownload:(NSString *)url withError:(NSError **)err
{
    if(__curlPtr) return false;
    __curlPtr = curl_easy_init();
    curl_easy_setopt(__curlPtr, CURLOPT_URL, [url cStringUsingEncoding:NSUTF8StringEncoding]);
    curl_easy_setopt(__curlPtr, CURLOPT_HTTPGET, 1L);
    curl_easy_setopt(__curlPtr, CURLOPT_WRITEFUNCTION, &write_callback);
    curl_easy_setopt(__curlPtr, CURLOPT_WRITEDATA, self);
    return true;
}

- (bool) startDownloadAsync:(NSURL *)url
                 toFilePath:(NSString *)filePath
                  withError:(NSError **)err
{
    bool result = [self setupDownload:url toFilePath:filePath withError:err];
    if(!result) return false;   //err is already set

    NSDictionary *threadParams = [NSDictionary dictionaryWithObjectsAndKeys:url, @"url", filePath, @"filePath", nil];
    
    NSThread *t = [[NSThread alloc] initWithTarget:self selector:@selector(internalDownloadAsync:) object:threadParams];
    [t start];
    return true;
}

/**
 internal method that forms a thread, running to perform a download and then executing a callback on the main thread
 */
- (void) internalDownloadAsync:(id)param
{
    NSError *err=nil;
    NSDictionary *threadParams = (NSDictionary *)param;
    NSURL *url = [threadParams valueForKey:@"url"];
    NSString *filePath = [threadParams valueForKey:@"filePath"];
    
    bool result = [self performDownload:url toFilePath:filePath withError:&err];
    dispatch_async(dispatch_get_main_queue(), ^{
        if(_downloadDelegate){
            if(result){
                [_downloadDelegate downloadDidFinish:url toFilePath:filePath];
            } else {
                [_downloadDelegate download:url didFailWithError:err];
            }
        }
    });
}

- (bool) startDownloadSync:(NSURL *)url
            toFilePath:(NSString *)filePath
             withError:(NSError **)err
{
    bool result;
    result = [self setupDownload:url toFilePath:filePath withError:err];
    if(!result) return false;   //err is already set
    
    return [self performDownload:url toFilePath:filePath withError:err];
}

/**
 internal method to set up parameters for a download, including opening the local file and initialising counters
 */
- (bool)setupDownload:(NSURL *)url
           toFilePath:(NSString *)filePath
            withError:(NSError **)err
{
    bool result;
    
    //step one - get headers
    NSLog(@"Header download: URL is %@", url);
    result = [self getUrlInfo:url withError:err];
    if(!result){
        NSLog(@"Header download failed: %@", *err);
        return false;
    }
    
    //step two - open file
    _currentFile = [[MMappedFile alloc] initWithFile:filePath];
    //O_EXCL means "fail if creating and the file already exists"
    result = [_currentFile open:O_CREAT|O_EXCL|O_EXLOCK|O_RDWR withSize:[[_headInfo size] longLongValue] withError:err];
    if((!result) && ([[_headInfo size] longLongValue] != 0)) {
        NSLog(@"file open failed: %@", [*err localizedDescription]);
        return false;
    }
    
    [self setBytesDownloaded:[NSNumber numberWithLongLong:0]];
    [self setTotalSize:[_headInfo size]];

    //step three - set up download
    [self internalSetupDownload:[url absoluteString] withError:err];
    return true;
}

/**
 internal method to perform a download that has been set up.
 */
- (bool)performDownload:(NSURL*)url toFilePath:(NSString *)filePath withError:(NSError **)err
{
    bool result, rtn;
    
    if(_downloadDelegate) [_downloadDelegate downloadDidBegin:url withEtag:[_headInfo eTag]];
    [self set_startTimestamp:time(NULL)];
    NSLog(@"Download for %@ of type %@ to %@ with size %@ starting", url, [_headInfo contentType], filePath,[self totalSize]);
    
    while(1){
        //step four - run it
        CURLcode dlresult = curl_easy_perform(__curlPtr);
        NSLog(@"Download for %@ completed, return code %d", url, result);
        
        if(dlresult==CURLE_SEND_ERROR || dlresult==CURLE_RECV_ERROR){
            NSLog(@"Received curl send/recv error %d, retrying", dlresult);
            sleep(1);
            [self setBytesDownloaded:0];
        } else {
            if(_downloadDelegate) [_downloadDelegate downloadDidFinish:url toFilePath:filePath];
            
            //step five - teardown
            rtn = [self handleCurlResult:dlresult forUrl:url withError:err];
            __curlPtr=NULL;
            break;
        }
    }

    //step six - unmap and close file
    result = [_currentFile close];
    if(!result){
        NSLog(@"Warning: error closing file");
    }
    
    return rtn;
}

- (size_t) gotBytes:(char *)ptr withSize:(size_t)size withCount:(int)nmemb
{
    size_t offset = [[self bytesDownloaded] longLongValue];
    [_currentFile write:ptr withLength:size*nmemb withOffset:offset];
    [self setBytesDownloaded:[NSNumber numberWithLongLong:offset+(size*nmemb)]];
    
    //NSLog(@"Got %lu bytes", size*nmemb);
    
    time_t elapsed;
    if(__startTimestamp>0){
        elapsed = time(NULL)-__startTimestamp;
    } else {
        elapsed = -1;
    }
    
    if([self progressCb]) _progressCb([self bytesDownloaded], [self totalSize], self);
    if(_downloadDelegate) [_downloadDelegate download:nil downloadedBytes:[self bytesDownloaded] fromTotal:[self totalSize] inSeconds:elapsed withData:nil];
    return size*nmemb;
}

@end


