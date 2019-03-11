//
//  BulkObjectStatusTransformer.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 08/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "BulkObjectStatusTransformer.h"
#import "BulkOperations.h"

@implementation BulkObjectStatusTransformer
+ (Class)transformedValueClass;
{
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation;
{
    return NO;
}

- (id)transformedValue:(id)value;
{
    if (![value isKindOfClass:[NSNumber class]])
        return nil;
    
    switch((BulkOperationStatus)[value integerValue]){
        case BO_READY:
            return @"Ready";
        case BO_ERRORED:
            return @"Error";
        case BO_RUNNING:
            return @"Running";
        case BO_COMPLETED:
            return @"Complete";
        case BO_WAITING_USER_INPUT:
            return @"Needs attention";
        case BO_INVALID:
            return @"Invalid file";
        case BO_PARTIAL:
            return @"Some errors";
        default:
            return @"unknown";
    }
}
@end
