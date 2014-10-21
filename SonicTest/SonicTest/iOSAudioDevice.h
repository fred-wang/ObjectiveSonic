// This file is placed into the public domain (see the UNLICENSE file).

#import <Foundation/Foundation.h>

@interface iOSAudioDevice : NSObject
-(id)initWith:(int)sampleRate numChannels:(int)numChannels;
-(BOOL)flush;
-(void)writeSamples:(const Byte*)samples length:(int)length;

@end
