//
//  StatusIconTransformer.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 25/04/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface StatusIconTransformer : NSValueTransformer

+ (Class)transformedValueClass;
+ (BOOL)allowsReverseTransformation;
- (id)transformedValue:(id)value;

@end
