//
//  HttpHeadInfo.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 24/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HttpHeadInfo : NSObject
@property NSString* eTag;
@property NSNumber* size;
@property NSDate* modTime;
@property NSString* acceptRanges;
@property NSString* contentType;
@property NSString* server;

@property NSString* proto;
@property NSNumber* statusCode;
@property NSString* statusString;

- (void) dumpForDebug;
@end
