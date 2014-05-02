//
//  main.m
//  BCDataStreamExample
//
//  Created by Seth Kingsley on 3/4/14.
//  Copyright (c) 2014 Seth Kingsley. All rights reserved.
//

#import <BCDataStream/BNInputDataStream.h>
#import <BCDataStream/BNOutputDataStream.h>

int
main(int argc, const char * argv[])
{
	@autoreleasepool
	{
		// Set up encoder:
		NSMutableData *encodedData = [NSMutableData data];
		BNOutputDataStream *outputStream = [BNOutputDataStream streamWithData:encodedData];
		[outputStream setEndianness:BIG_ENDIAN];

		// Fundamental types:
		[outputStream encodeInt32:-31337 description:@"Magic number"];
		[outputStream encodeUInt8:42 description:@"Small magic number"];

		// Strings:
		[outputStream encodeString:@"NUL-terminated" encoding:NSUTF8StringEncoding
					   description:@"NUL-terminated string"];

		// Arbitrary data:
		NSData *arbitraryData = [NSData dataWithBytesNoCopy:"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a"
													 length:10
											   freeWhenDone:NO];
		[outputStream encodeData:arbitraryData description:@"Auxiliary data"];

		// Set up decoder:
		BNInputDataStream *inputStream = [BNInputDataStream streamWithData:encodedData];
		[inputStream setEndianness:BIG_ENDIAN];

		// Fundamental types
		int32_t magic = [inputStream decodeInt32WithDescription:@"Magic number"];
		NSCAssert(magic == -31337, @"Invalid magic number");
		u_int8_t smallMagic = [inputStream decodeUInt8WithDescription:@"Small magic number"];
		NSCAssert(smallMagic == 42, @"Invalid small magic number");

		// Strings:
		NSString *string;
		[inputStream decodeStringWithEncoding:NSUTF8StringEncoding
													  intoString:&string
													 description:@"NUL-terminated string"];
		NSCAssert([string isEqualTo:@"NUL-terminated"], @"Invalid NUL-terminated string");

		// Arbitrary data:
		NSData *decodedData = [inputStream decodeDataWithLength:10 description:@"Auxiliary data"];
		NSCAssert([decodedData isEqual:arbitraryData], @"Invalid arbitrary data");
	}
    return 0;
}

