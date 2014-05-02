//
//  BNOutputDataStream.m
//  BushidoNetwork
//
//  Created by Seth Kingsley on 2/6/12.
//  Copyright (c) 2012 Bushido Coding. All rights reserved.
//

#import "BNOutputDataStream.h"
#import "BNAbstractDataStream_Internal.h"

@implementation BNOutputDataStream

+ streamWithData:(NSMutableData *)data
{
	return [(BNOutputDataStream *)[self alloc] initWithData:data];
}

+ streamWithChunkCapacity:(NSUInteger)chunkCapacity
{
	return [[self alloc] initWithChunkCapacity:chunkCapacity];
}

- (NSMutableData *)_addNewChunkWithDesiredLength:(NSUInteger)desiredLength
{
	if (_chunkCapacity)
		desiredLength = MIN(_chunkCapacity, desiredLength);
	NSMutableData *newChunk = [NSMutableData dataWithCapacity:MAX(_chunkCapacity, desiredLength)];
	[newChunk setLength:desiredLength];
	[self _addChunks:[NSArray arrayWithObject:newChunk]];
	return newChunk;
}

- initWithData:(NSMutableData *)data
{
	return [super initWithChunks:[NSArray arrayWithObject:data]];
}

- initWithChunkCapacity:(NSUInteger)chunkCapacity
{
	if ((self = [self initWithChunks:[NSArray array]]))
	{
		_chunkCapacity = chunkCapacity;
	}

	return self;
}

- copyWithZone:(NSZone *)zone
{
	BNOutputDataStream *copy = [super copyWithZone:zone];
	copy->_chunkCapacity = _chunkCapacity;
	return copy;
}

@synthesize chunkCapacity = _chunkCapacity;

- (NSUInteger)_remainingCapacityOfChunk:(NSMutableData *)chunk
{
	NSParameterAssert(chunk);
	return (_chunkCapacity) ? _chunkCapacity - [chunk length] : NSIntegerMax;
}

- (NSUInteger)_remainingChunkCapacity
{
	return [self _remainingCapacityOfChunk:_currentChunk];
}

- (void)_ensureLength:(NSUInteger)length description:(NSString *)description
{
	//UNUSED(description); // Reserved for future use.
	while (_length < length)
	{
		NSUInteger lengthToAdd = length - _length;
		NSMutableData *lastChunk = [_chunks lastObject];
		if (lastChunk)
		{
			NSUInteger remainingCapacityOfLastChunk = [self _remainingCapacityOfChunk:lastChunk];
			if (remainingCapacityOfLastChunk)
			{
				NSUInteger chunkLengthToAdd = MIN(remainingCapacityOfLastChunk, lengthToAdd);
				[lastChunk setLength:[lastChunk length] + chunkLengthToAdd];
				_length+= chunkLengthToAdd;
			}
			else
				[self _addNewChunkWithDesiredLength:lengthToAdd];
		}
		else
			[self _addNewChunkWithDesiredLength:lengthToAdd];
	}
	NSAssert([[_chunks valueForKeyPath:@"@sum.length"] unsignedIntegerValue] == _length, nil);
}

- (void)seekTo:(NSUInteger)offset description:(NSString *)description
{
	[self _ensureLength:offset description:description];
	if (_offset < offset)
		[self _advanceOffsetBy:_offset - offset];
	else if (_offset > offset)
	{
		_offset = 0;
		_currentChunkOffset = 0;
		_chunkIndex = 0;
		[self _advanceOffsetBy:offset];
	}
}

- (void)encodeUInt8:(u_int8_t)u8 description:(NSString *)description
{
	[self encodeBytes:&u8 length:sizeof(u8) description:description];
}

- (void)encodeUInt16:(u_int16_t)u16 description:(NSString *)description
{
	if (_endianness == LITTLE_ENDIAN)
		u16 = OSSwapHostToLittleInt16(u16);
	else
		u16 = OSSwapHostToBigInt16(u16);
	[self encodeBytes:(const u_int8_t *)&u16 length:sizeof(u16) description:description];
}

- (void)encodeInt32:(int32_t)s32 description:(NSString *)description
{
	if (_endianness == LITTLE_ENDIAN)
		s32 = OSSwapHostToLittleInt32(s32);
	else
		s32 = OSSwapHostToBigInt32(s32);
	[self encodeBytes:(const u_int8_t *)&s32 length:sizeof(s32) description:description];
}

- (void)encodeUInt32:(u_int32_t)u32 description:(NSString *)description
{
	if (_endianness == LITTLE_ENDIAN)
		u32 = OSSwapHostToLittleInt32(u32);
	else
		u32 = OSSwapHostToBigInt32(u32);
	[self encodeBytes:(const u_int8_t *)&u32 length:sizeof(u32) description:description];
}

- (void)encodeBytes:(const u_int8_t *)bytes length:(NSUInteger)length description:(NSString *)description
{
	[self _ensureLength:_offset + length description:description];
	while (length)
	{
		NSAssert([self _remainingChunkLength], nil);
		NSUInteger lengthToCopy = MIN(length, [self _remainingChunkLength]);
		bcopy(bytes, (u_int8_t *)[_currentChunk mutableBytes] + _currentChunkOffset, lengthToCopy);
		bytes+= lengthToCopy;
		length-= lengthToCopy;
		[self _advanceOffsetBy:lengthToCopy];
	}
}

- (void)encodeString:(NSString *)string encoding:(NSStringEncoding)encoding description:(NSString *)description;
{
	const char *cString = [string cStringUsingEncoding:encoding];
	[self encodeBytes:(const u_int8_t *)cString length:strlen(cString) + 1 description:description];
}

- (void)encodeData:(NSData *)data description:(NSString *)description
{
	NSUInteger dataLength = data.length;

	if (_offset == _length && _currentChunk && dataLength <= [self _remainingChunkCapacity])
	{
		[_currentChunk appendData:data];
		_length+= dataLength;
		[self _advanceOffsetBy:dataLength];
	}
	else
		[self encodeBytes:data.bytes length:dataLength description:description];
}

@end
