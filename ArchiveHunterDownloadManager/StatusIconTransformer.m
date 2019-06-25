//
//  StatusIconTransformer.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 25/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "StatusIconTransformer.h"
#import "BulkOperations.h"

@implementation StatusIconTransformer

+ (Class) transformedValueClass {
    return [NSImage class];
}

+ (BOOL) allowsReverseTransformation {
    return NO;
}

- (id) transformedValue:(id)value {
    if (![value isKindOfClass:[NSNumber class]])
        return nil;
    
    switch((BulkOperationStatus)[value integerValue]){
        case BO_READY:
            return [NSImage imageNamed:NSImageNameStatusNone];
        case BO_ERRORED:
            return [NSImage imageNamed:NSImageNameCaution];
        case BO_INVALID:
            return [NSImage imageNamed:NSImageNameStopProgressTemplate];
        case BO_PARTIAL:
            return [NSImage imageNamed:NSImageNameStatusPartiallyAvailable];
        case BO_RUNNING:
            return [NSImage imageNamed:NSImageNameStatusAvailable];
        case BO_COMPLETED:
            return [NSImage imageNamed:NSImageNameMenuOnStateTemplate];
        case BO_WAITING_USER_INPUT:
            return [NSImage imageNamed:NSImageNameUser];
        default:
            return [NSImage imageNamed:NSImageNameStatusUnavailable];
    }
}

@end
