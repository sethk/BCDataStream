//
//  BNAbstractDataStream_Internal.h
//  BushidoNetwork
//
//  Created by Seth Kingsley on 2/6/12.
//  Copyright (c) 2012 Bushido Coding. All rights reserved.
//

#import "BNAbstractDataStream.h"

@interface BNAbstractDataStream (Internal)

- (NSUInteger)_remainingChunkLength;
- (void)_addChunks:(NSArray *)chunks;
- (void)_advanceOffsetBy:(NSUInteger)delta;

@end
