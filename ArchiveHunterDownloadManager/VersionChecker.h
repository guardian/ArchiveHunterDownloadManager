//
//  VersionChecker.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 04/11/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VersionChecker : NSObject
@property NSString *serverPath;

- (id)initWithServerPath:(NSString*)serverPath;
- (void)performVersionCheck:(void (^)(NSNumber* currentBuildNumber, NSDictionary* remoteBuildInfo))needsUpdateHandler;
@end
