//
//  BNOutputDataStream.h
//  BushidoNetwork
//
//  Created by Seth Kingsley on 2/6/12.
//  Copyright (c) 2012 Bushido Coding. All rights reserved.
//

#import "BNAbstractDataStream.h"

@interface BNOutputDataStream : BNAbstractDataStream <NSCopying>
{
@protected
	NSUInteger _chunkCapacity;
}

+ streamWithData:(NSMutableData *)data;
+ streamWithChunkCapacity:(NSUInteger)chunkCapacity;
- initWithData:(NSMutableData *)data;
- initWithChunkCapacity:(NSUInteger)chunkCapacity;
@property (assign, readonly, nonatomic) NSUInteger chunkCapacity;
- (void)encodeUInt8:(u_int8_t)u8 description:(NSString *)description;
- (void)encodeInt32:(int32_t)s32 description:(NSString *)description;
- (void)encodeUInt16:(u_int16_t)u16 description:(NSString *)description;
- (void)encodeUInt32:(u_int32_t)u32 description:(NSString *)description;
- (void)encodeBytes:(const u_int8_t *)bytes length:(NSUInteger)length description:(NSString *)description;
- (void)encodeString:(NSString *)string encoding:(NSStringEncoding)encoding description:(NSString *)description;
- (void)encodeData:(NSData *)data description:(NSString *)description;

@end
