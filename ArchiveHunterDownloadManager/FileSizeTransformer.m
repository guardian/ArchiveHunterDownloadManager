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

- (NSArray<NSString*>*) sizeTokens {
    return [NSArray arrayWithObjects:@"B",@"KB",@"MB",@"GB",@"TB",nil];
}

- (id)transformedValue:(id)value;
{
    if (![value isKindOfClass:[NSNumber class]])
        return nil;
    
    double convertedValue = [value doubleValue];
    int multiplyFactor = 0;
    
    NSArray *tokens = [self sizeTokens];
    
    while (convertedValue > 1024) {
        convertedValue /= 1024;
        multiplyFactor++;
    }
    
    return [NSString stringWithFormat:@"%4.2f %@",convertedValue, [tokens objectAtIndex:multiplyFactor]];
}

@end