//
//  NegateTransformer.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 09/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "NegateTransformer.h"

@implementation NegateTransformer

+ (Class) transformedValueClass {
    return [NSNumber class];
}

+ (BOOL) allowsReverseTransformation {
    return YES;
}

- (id) transformedValue:(id)value {
    if([(NSNumber *)value boolValue]){
        return [NSNumber numberWithBool:NO];
    } else {
        return [NSNumber numberWithBool:YES];
    }
}
@end
