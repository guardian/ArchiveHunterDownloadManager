//
//  FileSizeTransformer.h
//  ArchiveHunterDownloadManager
//
//  Created by Local Home on 08/03/2019.
//  Copyright © 2019 Guardian News and Media. All rights reserved.
//

#import <Foundation/Foundation.h>

//from https://stackoverflow.com/questions/4195419/bytes-to-kilobytes
@interface FileSizeTransformer : NSValueTransformer {
    
}

+ (Class)transformedValueClass;
+ (BOOL)allowsReverseTransformation;
- (id)transformedValue:(id)value;

- (NSArray<NSString*>*) sizeTokens;

@end
