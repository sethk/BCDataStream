//
//  BCDataStreamTests.m
//  Pods
//
//  Created by Seth Kingsley on 3/12/14.
//
//

#import <XCTest/XCTest.h>
#import <BCDataStream/BNInputDataStream.h>
#import <BCDataStream/BNOutputDataStream.h>

@interface BCDataStreamTests : XCTestCase

@end

@implementation BCDataStreamTests

- (NSData *)_randomDataWithMaxLength:(NSUInteger)maxLength
{
	NSUInteger length = 1 + ((NSUInteger)random() % (maxLength - 1));
	NSMutableData *data = [NSMutableData dataWithLength:length];
	u_int8_t *bytes = [data mutableBytes];
	for (NSUInteger offset = 0; offset < length; ++offset)
		bytes[offset] = (u_int8_t)random();
	return data;
}

- (NSObject *)_encodeItemToStream:(BNOutputDataStream *)writeStream
{
	switch (random() % 7)
	{
		case 0:
		{
			u_int8_t u8 = (u_int8_t)random();
			[writeStream encodeUInt8:u8 description:@"Unsigned char"];
			return [NSValue valueWithBytes:&u8 objCType:@encode(typeof(u8))];
		}

		case 1:
		{
			u_int16_t u16 = (u_int16_t)random();
			[writeStream encodeUInt16:u16 description:@"Unsigned short"];
			return [NSValue valueWithBytes:&u16 objCType:@encode(typeof(u16))];
		}

		case 2:
		{
			int32_t s32 = (int32_t)random();
			[writeStream encodeInt32:s32 description:@"Signed int"];
			return [NSValue valueWithBytes:&s32 objCType:@encode(typeof(s32))];
		}

		case 3:
		{
			u_int32_t u32 = (u_int32_t)random();
			[writeStream encodeUInt32:u32 description:@"Unsigned int"];
			return [NSValue valueWithBytes:&u32 objCType:@encode(typeof(u32))];
		}

		case 4:
		{
			NSData *data = [self _randomDataWithMaxLength:256];
			[writeStream encodeData:data description:@"Data block"];
			return data;
		}

		case 5:
		{
			char cString[64];
			NSUInteger length = (NSUInteger)random() % sizeof(cString);
			for (NSUInteger charIndex = 0; charIndex < length; ++charIndex)
				cString[charIndex] = 32 + (char)((unsigned char)random() % 95);
			cString[length] = 0;
			NSString *string = [NSString stringWithCString:cString encoding:NSASCIIStringEncoding];
			[writeStream encodeString:string encoding:NSASCIIStringEncoding description:@"String"];
			return string;
		}

		case 6:
		{
			NSData *data = [self _randomDataWithMaxLength:128];
			NSData *delimeter;
			do
				delimeter = [self _randomDataWithMaxLength:32];
			while ([data rangeOfData:delimeter
							   options:0
								 range:NSMakeRange(0, [data length])].location != NSNotFound);
			[writeStream encodeData:data description:@"Delimeted data"];
			[writeStream encodeData:delimeter description:@"Delimeter"];
			return [NSDictionary dictionaryWithObjectsAndKeys:data, @"data", delimeter, @"delimeter", nil];
		}

		default:
			NSAssert(NO, @"Invalid item type");
			return nil;
	}
}

- (BOOL)_decodeItem:(NSObject *)item fromStream:(BNInputDataStream *)readStream partialData:(NSMutableData *)partialData
{
	if ([item isKindOfClass:[NSValue class]])
	{
		const char *type = [(NSNumber *)item objCType];
		if (!strcmp(type, @encode(u_int8_t))) // NSNumber encodes unsigned values in double the space
		{
			u_int8_t u8 = [readStream decodeUInt8WithDescription:@"Unsigned char"];
			u_int8_t savedU8;
			[(NSValue *)item getValue:&savedU8];
			XCTAssertEqual(u8, savedU8);
		}
		else if (!strcmp(type, @encode(u_int16_t)))
		{
			u_int16_t u16 = [readStream decodeUInt16WithDescription:@"Unsigned short"];
			u_int16_t savedU16;
			[(NSValue *)item getValue:&savedU16];
			XCTAssertEqual(u16, savedU16);
		}
		else if (!strcmp(type, @encode(int32_t)))
		{
			int32_t s32 = [readStream decodeInt32WithDescription:@"Signed int"];
			int32_t savedS32;
			[(NSValue *)item getValue:&savedS32];
			XCTAssertEqual(s32, savedS32);
		}
		else if (!strcmp(type, @encode(u_int32_t)))
		{
			u_int32_t u32 = [readStream decodeUInt32WithDescription:@"Unsigned int"];
			u_int32_t savedU32;
			[(NSValue *)item getValue:&savedU32];
			XCTAssertEqual(u32, savedU32);
		}
		else
			NSAssert(NO, @"Number encoded incorrectly");
	}
	else if ([item isKindOfClass:[NSData class]])
	{
		NSData *data = [readStream decodeDataWithLength:[(NSData *)item length] description:@"Data block"];
		XCTAssertEqualObjects(data, item);
	}
	else if ([item isKindOfClass:[NSString class]])
	{
		NSString *string;
		BOOL isWholeString = [readStream decodeStringWithEncoding:NSASCIIStringEncoding
													   intoString:&string
													  description:@"String"];
		[partialData appendData:[string dataUsingEncoding:NSASCIIStringEncoding]];
		if (isWholeString)
		{
			XCTAssertEqualObjects(partialData, [(NSString *)item dataUsingEncoding:NSASCIIStringEncoding]);
			[partialData setLength:0];
		}
		else
			return NO;
	}
	else if ([item isKindOfClass:[NSDictionary class]])
	{
		NSData *delimeter = [(NSDictionary *)item objectForKey:@"delimeter"];
		NSData *data;
		BOOL foundMarker = [readStream decodeUntilMarker:delimeter intoData:&data description:@"Delimeted data"];
		[partialData appendData:data];
		if (foundMarker)
		{
			XCTAssertEqualObjects(partialData, [(NSDictionary *)item objectForKey:@"data"]);
			[partialData setLength:0];
		}
		else
			return NO;
	}
	else
		NSAssert(NO, @"Invalid item type?");
	return YES;
}

- (void)_decodeBogusDelimeterOfData:(NSData *)encodedData fromStream:(BNInputDataStream *)readStream
{
	NSData *bogusDelimeter;
	BOOL delimiterInData, dataInDelimiter;
	do
	{
		bogusDelimeter = [self _randomDataWithMaxLength:32];
		delimiterInData = ([encodedData rangeOfData:bogusDelimeter
											options:0
											  range:NSMakeRange(0, [encodedData length])].location != NSNotFound);
		dataInDelimiter = ([bogusDelimeter rangeOfData:encodedData
											   options:0
												 range:NSMakeRange(0, [bogusDelimeter length])].location != NSNotFound);
	}
	while (delimiterInData || dataInDelimiter);
	NSUInteger remainingLength = [readStream remainingLength];
	NSData *remainingData;
	BOOL foundMarker = [readStream decodeUntilMarker:bogusDelimeter intoData:&remainingData description:@"Bogus data"];
	XCTAssertFalse(foundMarker);
	NSUInteger trailingLength = [readStream remainingLength];
	if (trailingLength)
	{
		NSData *partialDelimeter = [readStream decodeDataWithLength:trailingLength
														description:@"Trailing data"];
		NSUInteger partialDelimeterLength = [partialDelimeter length];
		NSRange partialMatch = [bogusDelimeter rangeOfData:partialDelimeter
												   options:NSDataSearchAnchored
													 range:NSMakeRange(0, partialDelimeterLength)];
		XCTAssertEqual(partialMatch.location, 0UL);
		remainingLength-= partialDelimeterLength;
	}
	XCTAssertEqual([remainingData length], remainingLength);
}

- (void)_decodeItems:(NSArray *)items fromStream:(BNInputDataStream *)readStream allData:(NSData *)encodedData
{
	NSMutableData *partialData = [NSMutableData data];
	for (NSObject *item in items)
	{
		if ((random() % 10) == 0)
		{
			[self _decodeBogusDelimeterOfData:encodedData fromStream:readStream];
			break;
		}
		else
			[self _decodeItem:item fromStream:readStream partialData:partialData];
	}
	XCTAssertEqual([readStream remainingLength], 0UL);

	#if 1
		XCTAssertThrows([readStream decodeUInt8WithDescription:@"..."]);
		XCTAssertThrows([readStream decodeInt32WithDescription:@"..."]);
		XCTAssertThrows([readStream decodeUInt16WithDescription:@"..."]);
		XCTAssertThrows([readStream decodeUInt32WithDescription:@"..."]);
		XCTAssertThrows([readStream decodeDataWithLength:10 description:@"..."]);
		XCTAssertThrows([readStream decodeUntilMarker:[@"..." dataUsingEncoding:NSUTF8StringEncoding]
											intoData:NULL
										 description:@"..."]);
	#endif // 1
}

- (void)testEncodeDecode
{
	NSUInteger iterationsLeft = 10000;
	while (iterationsLeft--)
	{
		@autoreleasepool {
			NSUInteger chunkCapacity = (NSUInteger)random() % 64;
			BNOutputDataStream *writeStream = [BNOutputDataStream streamWithChunkCapacity:chunkCapacity];
			[writeStream setEndianness:(random() % 1) ? LITTLE_ENDIAN : BIG_ENDIAN];
			NSMutableArray *items = [NSMutableArray array];
			NSUInteger numItems = (NSUInteger)random() % 8;
			for (NSUInteger itemIndex = 0; itemIndex < numItems; ++itemIndex)
				[items addObject:[self _encodeItemToStream:writeStream]];

			NSMutableArray *chunks = [[writeStream chunks] mutableCopy];
			NSMutableData *encodedData;
			if (chunkCapacity)
			{
				encodedData = [NSMutableData data];
				for (NSData *chunk in chunks)
				{
					if (chunk != [chunks lastObject])
						XCTAssertEqual([chunk length], chunkCapacity);
					else
						XCTAssertTrue([chunk length] > 0 && [chunk length] <= chunkCapacity);
					[encodedData appendData:chunk];
				}
			}
			else if (numItems)
			{
				XCTAssertEqual([chunks count], 1UL);
				encodedData = [chunks objectAtIndex:0];
			}
			else
				encodedData = [NSData data];

			#if 1
				BNInputDataStream *readStream = [BNInputDataStream streamWithData:encodedData];
				[readStream setEndianness:[writeStream endianness]];
				[self _decodeItems:items fromStream:readStream allData:encodedData];

				BNInputDataStream *splitReadStream = [BNInputDataStream streamWithChunks:chunks];
				[splitReadStream setEndianness:[writeStream endianness]];
				[self _decodeItems:items fromStream:splitReadStream allData:encodedData];
			#endif // 1

			BNInputDataStream *chunkedReadStream = [BNInputDataStream streamWithChunks:[NSArray array]];
			[chunkedReadStream setEndianness:[writeStream endianness]];
			NSUInteger itemIndex = 0;
			NSMutableData *partialData = [NSMutableData data];
			while ([chunks count])
			{
				[chunkedReadStream addChunk:[chunks objectAtIndex:0]];
				[chunks removeObjectAtIndex:0];
				@try
				{
					while (itemIndex < numItems)
						if ([self _decodeItem:[items objectAtIndex:itemIndex]
								   fromStream:chunkedReadStream
								  partialData:partialData])
							++itemIndex;
				}
				@catch (NSException *exception)
				{
					if (![[exception name] isEqualToString:BNInputDataStreamException])
						@throw;
				}
			}
			XCTAssertEqual([chunkedReadStream remainingLength], 0UL);
		}
	}
}

@end
