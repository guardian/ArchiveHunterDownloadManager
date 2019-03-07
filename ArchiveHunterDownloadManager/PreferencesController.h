//
//  PreferencesController.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 06/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "HttpServer/HttpServer.h"

@interface PreferencesController : NSViewController

@property (readonly, strong, nonatomic) HTTPServer *httpServer;
@property (readwrite, atomic) NSNumber *isAuthenticated;

@end
