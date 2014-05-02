//
//  BNInputDataStream.m
//  BushidoNetwork
//
//  Created by Seth Kingsley on 1/27/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "BNInputDataStream.h"
#import "BNAbstractDataStream_Internal.h"

@implementation BNInputDataStream

NSString * const BNInputDataStreamException = @"Data Stream Exception";

- copyWithZone:(NSZone *)zone
{
	BNInputDataStream *copy = [super copyWithZone:zone];
	copy->_consumedChunksLength = _consumedChunksLength;
	return copy;
}

- (void)_raiseLengthExceptionWithDescription:(NSString *)description
{
	[NSException raise:BNInputDataStreamException format:@"Truncated data while reading %@", description];
}

- (void)_advanceOffsetBy:(NSUInteger)delta
{
	[super _advanceOffsetBy:delta];
	while (_chunkIndex > 0)
	{
		_consumedChunksLength+= [[_chunks objectAtIndex:0] length];
		[_chunks removeObjectAtIndex:0];
		--_chunkIndex;
	}
}

- (void)addChunk:(NSData *)chunk
{
	[self _addChunks:[NSArray arrayWithObject:chunk]];
}

- (void)seekTo:(NSUInteger)offset description:(NSString *)description
{
	NSParameterAssert(offset >= _consumedChunksLength);
	if (offset <= _length)
	{
		if (_offset < offset)
			[self _advanceOffsetBy:offset - _offset];
		else if (offset >= _consumedChunksLength)
		{
			_offset = _consumedChunksLength;
			_currentChunkOffset = 0;
			_chunkIndex = 0;
			[self _advanceOffsetBy:offset - _consumedChunksLength];
		}
		else
			[self _raiseLengthExceptionWithDescription:description];
	}
	else
		[self _raiseLengthExceptionWithDescription:description];
}

- (u_int8_t)decodeUInt8WithDescription:(NSString *)description
{
	u_int8_t byte;
	[self decodeBytes:&byte length:sizeof(byte) description:description];
	return byte;
}

- (u_int16_t)decodeUInt16WithDescription:(NSString *)description
{
	u_int16_t word;
	[self decodeBytes:(u_int8_t *)&word length:sizeof(word) description:description];
	if (_endianness == LITTLE_ENDIAN)
		return OSSwapLittleToHostInt16(word);
	else
		return OSSwapBigToHostInt16(word);
}

- (int32_t)decodeInt32WithDescription:(NSString *)description
{
	int32_t i32;
	[self decodeBytes:(u_int8_t *)&i32 length:sizeof(i32) description:description];
	if (_endianness == LITTLE_ENDIAN)
		return OSSwapLittleToHostInt32(i32);
	else
		return OSSwapBigToHostInt32(i32);
}

- (u_int32_t)decodeUInt32WithDescription:(NSString *)description
{
	u_int32_t u32;
	[self decodeBytes:(u_int8_t *)&u32 length:sizeof(u32) description:description];
	if (_endianness == LITTLE_ENDIAN)
		return OSSwapLittleToHostInt32(u32);
	else
		return OSSwapBigToHostInt32(u32);
}

- (const u_int8_t *)_chunkBytes
{
	return [_currentChunk bytes] + _currentChunkOffset;
}

- (void)decodeBytes:(u_int8_t *)bytes length:(NSUInteger)length description:(NSString *)description
{
	if (length <= [self remainingLength])
	{
		while (length)
		{
			NSUInteger lengthToCopy = MIN(length, [self _remainingChunkLength]);
			bcopy([self _chunkBytes], bytes, lengthToCopy);
			bytes+= lengthToCopy;
			length-= lengthToCopy;
			[self _advanceOffsetBy:lengthToCopy];
		}
	}
	else
		[self _raiseLengthExceptionWithDescription:description];
}

- (NSData *)decodeDataWithLength:(NSUInteger)dataLength description:(NSString *)description
{
	if (dataLength <= [self remainingLength])
	{
		if (dataLength <= [self _remainingChunkLength])
		{
			NSData *data = [_currentChunk subdataWithRange:NSMakeRange(_currentChunkOffset, dataLength)];
			[self _advanceOffsetBy:dataLength];
			return data;
		}
		else
		{
			NSMutableData *data = [NSMutableData dataWithLength:dataLength];
			[self decodeBytes:[data mutableBytes] length:dataLength description:description];
			return data;
		}
	}
	else
	{
		[self _raiseLengthExceptionWithDescription:description];
		return nil;
	}
}

- (BOOL)decodeStringWithEncoding:(NSStringEncoding)encoding
					  intoString:(out NSString **)pString
					 description:(NSString *)description
{
	NSData *data;
	BOOL foundNUL = [self decodeUntilMarker:[NSData dataWithBytesNoCopy:"" length:1 freeWhenDone:NO]
								   intoData:&data
								description:description];
	if (pString)
		*pString = [[NSString alloc] initWithData:data encoding:encoding];
	return foundNUL;
}

- (BOOL)_isMatchingData:(NSData *)matchData isFullMatch:(BOOL *)pIsFullMatch
{
	NSUInteger matchDataLength = [matchData length];
	const u_int8_t *matchDataBytes = [matchData bytes];
	NSUInteger remainingLength = [self remainingLength];
	NSUInteger matchLength;
	BOOL isFullMatch;
	if (matchDataLength <= remainingLength)
	{
		isFullMatch = YES;
		matchLength = matchDataLength;
	}
	else
	{
		isFullMatch = NO;
		matchLength = remainingLength;
	}
	NSInteger searchChunkIndex = _chunkIndex;
	NSUInteger searchChunkOffset = _currentChunkOffset;
	NSUInteger searchMarkerOffset = 0;
	do
	{
		NSData *searchChunk = [_chunks objectAtIndex:(NSUInteger)searchChunkIndex];
		NSUInteger chunkMatchLength = MIN([searchChunk length] - searchChunkOffset, matchLength);
		if (bcmp([searchChunk bytes] + searchChunkOffset, matchDataBytes + searchMarkerOffset, chunkMatchLength))
			return NO;
		searchChunkOffset+= chunkMatchLength;
		searchMarkerOffset+= chunkMatchLength;
		matchLength-= chunkMatchLength;
		if (searchChunkOffset == [searchChunk length])
		{
			++searchChunkIndex;
			searchChunkOffset = 0;
		}
	} while (matchLength);

	if (pIsFullMatch)
		*pIsFullMatch = isFullMatch;
	return YES;
}

- (BOOL)decodeUntilMarker:(NSData *)marker intoData:(NSData **)pData description:(NSString *)description;
{
	if ([self remainingLength])
	{
		BOOL isFullMatch = NO;
		const u_int8_t *markerBytes = marker.bytes;
		BNInputDataStream *readAheadStream = [self copy];
		do
		{
			BOOL firstByteMatched = NO;
			const u_int8_t *readChunkBytes = [readAheadStream _chunkBytes];
			NSUInteger readRemainingChunkLength = [readAheadStream _remainingChunkLength];
			NSUInteger readByteIndex = 0;
			for (readByteIndex = 0; readByteIndex < readRemainingChunkLength; ++readByteIndex)
				if (readChunkBytes[readByteIndex] == *markerBytes)
				{
					firstByteMatched = YES;
					break;
				}

			if (firstByteMatched)
			{
				[readAheadStream _advanceOffsetBy:readByteIndex];
				if ([readAheadStream _isMatchingData:marker isFullMatch:&isFullMatch])
					break;
				[readAheadStream _advanceOffsetBy:1];
			}
			else
				[readAheadStream _advanceOffsetBy:readRemainingChunkLength];
		} while ([readAheadStream remainingLength]);

		NSUInteger dataLength = [readAheadStream offset] - _offset;
		if (dataLength || isFullMatch)
		{
			if (pData)
				*pData = [self decodeDataWithLength:dataLength description:description];
			if (isFullMatch)
			{
				[self _advanceOffsetBy:[marker length]];
				return YES;
			}
			else
				return NO;
		}
	}

	// No data left or partial match after 0 bytes of data:
	[self _raiseLengthExceptionWithDescription:description];
	//NOTREACHED
	return NO;
}

@end
