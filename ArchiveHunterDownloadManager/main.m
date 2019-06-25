//
//  main.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 05/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <curl/curl.h>

int main(int argc, const char * argv[]) {
    curl_global_init(CURL_GLOBAL_DEFAULT);
    return NSApplicationMain(argc, argv);
}
