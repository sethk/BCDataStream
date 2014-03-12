//
//  BNInputDataStream.h
//  BushidoNetwork
//
//  Created by Seth Kingsley on 1/27/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "BNAbstractDataStream.h"

@interface BNInputDataStream : BNAbstractDataStream <NSCopying>
{
@protected
	NSUInteger _consumedChunksLength;
}

extern NSString * const BNInputDataStreamException;

- (void)addChunk:(NSData *)chunk;
- (void)seekTo:(NSUInteger)offset description:(NSString *)description;
- (u_int8_t)decodeUInt8WithDescription:(NSString *)description;
- (u_int16_t)decodeUInt16WithDescription:(NSString *)description;
- (u_int32_t)decodeUInt32WithDescription:(NSString *)description;
- (void)decodeBytes:(u_int8_t *)bytes length:(NSUInteger)length description:(NSString *)description;
- (NSData *)decodeDataWithLength:(NSUInteger)length description:(NSString *)description;
- (BOOL)decodeStringWithEncoding:(NSStringEncoding)encoding
					  intoString:(out NSString **)pString
					 description:(NSString *)description;
- (BOOL)decodeUntilMarker:(NSData *)marker intoData:(NSData **)pData description:(NSString *)description;

@end
