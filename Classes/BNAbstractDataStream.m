//
//  BNAbstractDataStream.m
//  BushidoNetwork
//
//  Created by Seth Kingsley on 2/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "BNAbstractDataStream_Internal.h"

@implementation BNAbstractDataStream

+ stream
{
	return [[self alloc] init];
}

+ streamWithData:(NSData *)data
{
	return [[self alloc] initWithData:data];
}

+ streamWithChunks:(NSArray *)chunks
{
	return [[self alloc] initWithChunks:chunks];
}

- init
{
	return [self initWithChunks:[NSArray array]];
}

- initWithData:(NSData *)data
{
	return [self initWithChunks:[NSArray arrayWithObject:[data copy]]];
}

- initWithChunks:(NSArray *)chunks
{
	if ((self = [super init]))
	{
		_endianness = BYTE_ORDER;
		_chunks = [NSMutableArray new];
		_chunkIndex = -1;
		if ([chunks count])
			[self _addChunks:chunks];
	}

	return self;
}

- copyWithZone:(NSZone *)zone
{
	BNAbstractDataStream *copy = [[self class] allocWithZone:zone];
	copy->_length = _length;
	copy->_offset = _offset;
	copy->_endianness = _endianness;
	copy->_chunks = [_chunks mutableCopy];
	copy->_chunkIndex = _chunkIndex;
	copy->_currentChunk = _currentChunk;
	copy->_currentChunkOffset = _currentChunkOffset;
	return copy;
}

@synthesize length = _length;
@synthesize offset = _offset;

- (NSUInteger)remainingLength
{
	return _length - _offset;
}

@synthesize endianness = _endianness;

- (NSUInteger)_remainingChunkLength
{
	return [_currentChunk length] - _currentChunkOffset;
}

@synthesize chunks = _chunks;

- (void)_addChunks:(NSArray *)chunks
{
	NSParameterAssert([chunks count]);
	NSInteger numOriginalChunks = (NSInteger)[_chunks count];
	[_chunks addObjectsFromArray:chunks];
	_length+= [[chunks valueForKeyPath:@"@sum.length"] unsignedIntegerValue];
	if (_chunkIndex == numOriginalChunks - 1 && ![self _remainingChunkLength])
	{
		_chunkIndex = numOriginalChunks;
		_currentChunk = [_chunks objectAtIndex:(NSUInteger)_chunkIndex];
		_currentChunkOffset = 0;
	}
}

- (void)_advanceOffsetBy:(NSUInteger)delta
{
	NSParameterAssert(delta <= [self remainingLength]);
	while (delta)
	{
		NSUInteger remainingChunkLength = [self _remainingChunkLength];
		if (delta < remainingChunkLength || (delta == remainingChunkLength && delta == [self remainingLength]))
		{
			_currentChunkOffset+= delta;
			_offset+= delta;
			delta = 0;
		}
		else
		{
			++_chunkIndex;
			_currentChunk = [_chunks objectAtIndex:(NSUInteger)_chunkIndex];
			_currentChunkOffset = 0;
			_offset+= remainingChunkLength;
			delta-= remainingChunkLength;
		}
	}
}

@end
