//
//  FileSizeTransformer.m
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 08/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import "FileSizeTransformer.h"

@implementation FileSizeTransformer
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
    
    double convertedValue = [value doubleValue];
    int multiplyFactor = 0;
    
    NSArray *tokens = [NSArray arrayWithObjects:@"B",@"KB",@"MB",@"GB",@"TB",nil];
    
    while (convertedValue > 1024) {
        convertedValue /= 1024;
        multiplyFactor++;
    }
    
    return [NSString stringWithFormat:@"%4.2f %@",convertedValue, [tokens objectAtIndex:multiplyFactor]];
}

@end