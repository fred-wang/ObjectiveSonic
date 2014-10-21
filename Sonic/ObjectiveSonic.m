// This file is a rewritting in Objective C of the Sonic.java and
// sonicjni.c files from https://github.com/waywardgeek/sonic-ndk
// It is placed into the public domain as described in the UNLICENSE file.

#import "ObjectiveSonic.h"
#import "sonic.h"

// For debug messages:
#ifdef SONIC_DEBUG
#define APPNAME "Sonic"
#define LOGV(...) NSLog(@"%s - %@", APPNAME,
                        [NSString stringWithFormat:__VA_ARGS__]);
#else
#define LOGV(...)
#endif

struct sonicInstStruct {
    sonicStream stream;
    short *byteBuf;
    int byteBufSize;
};

typedef struct sonicInstStruct *sonicInst;

#define getInst(sonicID) ((sonicInst)((char *)nil + (sonicID)))

@implementation Sonic
{
    // Sonic is thread-safe, but to have multiple instances of it, we have to
    // store a pointer to its data.
    long sonicID;
}

// Create a sonic stream.  Return false only if we are out of memory and cannot
// allocate the stream. Set numChannels to 1 for mono, and 2 for stereo.
-(id)initWith:(int)sampleRate channels:(int)channels
{
    self = [super init];
    if (self) {
        [self close];
        // Initialize the C data structure
        sonicInst inst = (sonicInst)calloc(1, sizeof(struct sonicInstStruct));
        if (!inst) {
            return nil;
        }
        LOGV(@"Creating sonic stream");
        inst->stream = sonicCreateStream(sampleRate, channels);
        if (!inst->stream) {
            free(inst);
            return nil;
        }
        sonicID = (long)((char *)inst - (char *)nil);
    }
    return self;
}

// Call this to clean up memory after you're done processing sound.
-(void)close
{
    if (sonicID) {
        // Teardown the C data structure.
        sonicInst inst = getInst(sonicID);
        LOGV(@"Destroying stream");
        sonicDestroyStream(inst->stream);
        free(inst->byteBuf);
        free(inst);
        sonicID = 0;
    }
}

// Just insure that close gets called, in case the user forgot.
-(void)dealloc
{
    // It is safe to call this twice, in case the user already did.
    [self close];
    [super dealloc];
}

// Force the sonic stream to generate output using whatever data it currently
// has.  No extra delay will be added to the output, but flushing in the middle
// of words could introduce distortion.
-(void)flush
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Flushing stream");
    sonicFlushStream(stream);
}

// Set the sample rate of the stream.  This will drop any samples that have
// not been read.
-(void)setSampleRate:(int)newSampleRate
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Set sample rate to %d", newSampleRate);
    sonicSetSampleRate(stream, newSampleRate);
}

// Get the sample rate of the stream.
-(int)getSampleRate
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Reading Sample rate");
    return sonicGetSampleRate(stream);
}

// Set the number of channels.  This will drop any samples that have not been
// read.
-(void)setNumChannels:(int)newNumChannels
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Set sample rate to %d", newNumChannels);
    sonicSetNumChannels(stream, newNumChannels);
}

// Get the number of channels.
-(int)getNumChannels
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Reading num channels");
    return sonicGetNumChannels(stream);
}

// Set the pitch of the stream.
-(void)setPitch:(float)newPitch
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Set sample rate to %f", newPitch);
    sonicSetPitch(stream, newPitch);
}

// Get the pitch of the stream.
-(float)getPitch
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Reading pitch");
    return sonicGetPitch(stream);
}

//Set the speed of the stream.
-(void)setSpeed:(float)newSpeed
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Set speed to %f", newSpeed);
    sonicSetSpeed(stream, newSpeed);
}

// Get the speed of the stream.
-(float)getSpeed
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Reading speed");
    return sonicGetSpeed(stream);
}

// Set the rate of the stream.  Rate means how fast we play, without pitch
// correction. You probably just want to use setSpeed and setPitch instead.
-(void)setRate:(float)newRate
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Set rate to %f", newRate);
    sonicSetRate(stream, newRate);
}

// Get the rate of the stream.
-(float)getRate
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Reading rate");
    return sonicGetRate(stream);
}

// Set chord pitch mode on or off.  Default is off.  See the documentation
// page for a description of this feature.
-(void)setChordPitch:(BOOL)useChordPitch
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Set chord pitch to %d", useChordPitch);
    sonicSetChordPitch(stream, useChordPitch);
}

// Get the chord pitch setting.
-(BOOL)getChordPitch
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Reading chord pitch");
    return sonicGetChordPitch(stream);
}

// Use this to write 16-bit data to be speed up or down into the stream.
// Return false if memory realloc failed, otherwise true.
-(BOOL)putBytes:(const Byte*)buffer lenBytes:(int)lenBytes
{
    sonicInst inst = getInst(sonicID);
    sonicStream stream = inst->stream;
    int samples = lenBytes/(sizeof(short) * sonicGetNumChannels(stream));
    int remainingBytes = lenBytes -
      samples * sizeof(short) * sonicGetNumChannels(stream);

    // TODO: deal with case where remainingBytes is not 0.
    if (remainingBytes != 0) {
        LOGV(@"Remaining bytes == %d!!!", remainingBytes);
    }
    if (lenBytes > inst->byteBufSize*sizeof(short)) {
        inst->byteBufSize = lenBytes*(2/sizeof(short));
        inst->byteBuf = (short *)realloc(inst->byteBuf,
					 inst->byteBufSize * sizeof(short));
        if (!inst->byteBuf) {
            return NO;
        }
    }
    LOGV(@"Writing %d bytes to stream", lenBytes);
    memcpy(inst->byteBuf, buffer, lenBytes);
    return sonicWriteShortToStream(stream, inst->byteBuf, samples);
}

// Use this to read 16-bit data out of the stream.  Sometimes no data will
// be available, and zero is returned, which is not an error condition.
-(int)receiveBytes:(Byte*)ret lenBytes:(int)lenBytes
{
    // Get bytes representing sped up/slowed down sound and put up to lenBytes
    // into ret.
    // Returns number of bytes read, or -1 if we run out of memory.
    sonicInst inst = getInst(sonicID);
    sonicStream stream = inst->stream;
    int available = sonicSamplesAvailable(stream) * sizeof(short) * sonicGetNumChannels(stream);
    int samplesRead, bytesRead;

    LOGV(@"Reading %d bytes from stream", lenBytes);
    if (lenBytes > available) {
        lenBytes = available;
    }
    if (lenBytes > inst->byteBufSize * sizeof(short)) {
        inst->byteBufSize = lenBytes * (2 / sizeof(short));
        inst->byteBuf = (short*)realloc(inst->byteBuf, inst->byteBufSize * sizeof(short));
        if (!inst->byteBuf) {
            return -1;
        }
    }
    //LOGV(@"Doing read %d", lenBytes);
    samplesRead = sonicReadShortFromStream(stream, inst->byteBuf,
                                           lenBytes / (sizeof(short) * sonicGetNumChannels(stream)));
    bytesRead = samplesRead * sizeof(short) * sonicGetNumChannels(stream);
    //LOGV(@"Returning %d", samplesRead);
    memcpy(ret, inst->byteBuf, bytesRead);
    return bytesRead;
}

// Return the number of samples in the output buffer
-(int)availableBytes
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Reading samples available = %lu", sonicSamplesAvailable(stream) * sizeof(short) * sonicGetNumChannels(stream));
    return sonicSamplesAvailable(stream) * sizeof(short) * sonicGetNumChannels(stream);
}

// Set the scaling factor of the stream.
-(void)setVolume:(float) newVolume
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Set volume to %f", newVolume);
    sonicSetVolume(stream, newVolume);
}

// Get the scaling factor of the stream.
-(float)getVolume
{
    sonicStream stream = getInst(sonicID)->stream;
    LOGV(@"Reading volume");
    return sonicGetVolume(stream);
}

@end
