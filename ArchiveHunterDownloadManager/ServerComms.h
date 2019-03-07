//
//  ServerComms.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 07/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ServerComms : NSObject

- (id)init;

- (BOOL) initiateDownload:(NSString * _Nonnull)token
                withError:(NSError **)err
        completionHandler:(void (^ _Nonnull)(NSDictionary *_Nullable data, NSError *_Nullable err))completionBlock;

@property (atomic, strong) NSURLSession *session;
@end
