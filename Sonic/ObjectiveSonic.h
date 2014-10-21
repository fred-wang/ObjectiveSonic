// This file is a rewritting in Objective C of the sonicjni.h file from
// https://github.com/waywardgeek/sonic-ndk
// It is placed into the public domain as described in the UNLICENSE file.

#import <Foundation/Foundation.h>

@interface Sonic : NSObject
-(id)initWith:(int)sampleRate channels:(int)channels;
-(void)close;
-(void)flush;
-(void)setSampleRate:(int)newSampleRate;
-(int)getSampleRate;
-(void)setNumChannels:(int)newNumChannels;
-(int)getNumChannels;
-(void)setPitch:(float)newPitch;
-(float)getPitch;
-(void)setSpeed:(float)newSpeed;
-(float)getSpeed;
-(void)setRate:(float)newRate;
-(float)getRate;
-(void)setChordPitch:(BOOL)useChordPitch;
-(BOOL)getChordPitch;
-(BOOL)putBytes:(const Byte*)buffer lenBytes:(int)lenBytes;
-(int)receiveBytes:(Byte*)ret lenBytes:(int)lenBytes;
-(int)availableBytes;
-(void)setVolume:(float) newVolume;
-(float)getVolume;

@end
