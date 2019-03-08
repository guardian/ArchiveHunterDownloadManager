//
//  BulkObjectStatusTransformer.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 08/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BulkObjectStatusTransformer : NSValueTransformer
+ (Class)transformedValueClass;
+ (BOOL)allowsReverseTransformation;
- (id)transformedValue:(id)value;

@end
