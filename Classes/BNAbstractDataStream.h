//
//  BNAbstractDataStream.h
//  BushidoNetwork
//
//  Created by Seth Kingsley on 2/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BNAbstractDataStream : NSObject <NSCopying>
{
@protected
	NSUInteger _length, _offset;
	int _endianness;
	NSMutableArray *_chunks;
	NSInteger _chunkIndex;
	__unsafe_unretained NSMutableData *_currentChunk;
	NSUInteger _currentChunkOffset;
}

+ stream;
+ streamWithData:(NSData *)data;
+ streamWithChunks:(NSArray *)chunks;
- initWithData:(NSData *)data;
- initWithChunks:(NSArray *)chunks;
@property (assign, readonly, nonatomic) NSUInteger length;
@property (assign, readonly, nonatomic) NSUInteger offset;
- (NSUInteger)remainingLength;
@property (assign, readwrite, nonatomic) int endianness;
@property (retain, readonly, nonatomic) NSArray *chunks;

@end

@class BNOutputDataStream, BNInputDataStream;

@protocol BNDataStreamCoder

- initWithDataStream:(BNInputDataStream *)dataStream;
- (void)encodeWithDataStream:(BNOutputDataStream *)dataStream;

@end
