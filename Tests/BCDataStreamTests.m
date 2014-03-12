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
	switch (random() % 6)
	{
		case 0:
		{
			u_int8_t u8 = (u_int8_t)random();
			[writeStream encodeUInt8:u8 description:@"Unsigned char"];
			return [NSNumber numberWithUnsignedChar:u8];
		}

		case 1:
		{
			u_int16_t u16 = (u_int16_t)random();
			[writeStream encodeUInt16:u16 description:@"Unsigned short"];
			return [NSNumber numberWithUnsignedShort:u16];
		}

		case 2:
		{
			u_int32_t u32 = (u_int32_t)random();
			[writeStream encodeUInt32:u32 description:@"Unsigned int"];
			return [NSNumber numberWithUnsignedInt:u32];
		}

		case 3:
		{
			NSData *data = [self _randomDataWithMaxLength:256];
			[writeStream encodeData:data description:@"Data block"];
			return data;
		}

		case 4:
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

		case 5:
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
	if ([item isKindOfClass:[NSNumber class]])
	{
		const char *type = [(NSNumber *)item objCType];
		if (!strcmp(type, @encode(short))) // NSNumber encodes unsigned values in double the space
		{
			u_int8_t u8 = [readStream decodeUInt8WithDescription:@"Unsigned char"];
			XCTAssertEqual(u8, [(NSNumber *)item unsignedCharValue]);
		}
		else if (!strcmp(type, @encode(int)))
		{
			u_int16_t u16 = [readStream decodeUInt16WithDescription:@"Unsigned short"];
			XCTAssertEqual(u16, [(NSNumber *)item unsignedShortValue]);
		}
		else if (!strcmp(type, @encode(quad_t)))
		{
			u_int32_t u32 = [readStream decodeUInt32WithDescription:@"Unsigned int"];
			XCTAssertEqual(u32, [(NSNumber *)item unsignedIntValue]);
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
	return YES;
}

- (void)_decodeBogusDelimeterOfData:(NSData *)encodedData fromStream:(BNInputDataStream *)readStream
{
	NSData *bogusDelimeter;
	do
		bogusDelimeter = [self _randomDataWithMaxLength:32];
	while ([encodedData rangeOfData:bogusDelimeter
							  options:0
								range:NSMakeRange(0, [encodedData length])].location != NSNotFound);
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
