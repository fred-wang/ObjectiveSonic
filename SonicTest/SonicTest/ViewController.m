// This file is placed into the public domain (see the UNLICENSE file).
// This is a rewritting in Objective C of the SonicTest.java file from
// https://github.com/waywardgeek/sonic-ndk

#import "ViewController.h"

#import <ObjectiveSonic.h>
#import "iOSAudioDevice.h"

// These are constants used in the run() function of SonicTest.java
static const unsigned int kSamplesRate = 22050;
static const unsigned int kSamplesLength = 4096;
static const unsigned int kModifiedSamplesLength = 2048;
static const unsigned int kChannelCount = 1;

// Convenient function to convert the content of the text field into float.
// This also handles the fact that comma are used as decimal separators in
// some countries.
float valueOfTextField(UITextField* textField)
{
    return [[[textField text] stringByReplacingOccurrencesOfString:@"," withString:@"."] floatValue];
}

// Object to encapsulate the Sonic parameters.
@interface SonicParameters : NSObject
@property float mSpeed;
@property float mPitch;
@property float mRate;
@end

@implementation SonicParameters
@end

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *Speed;
@property (weak, nonatomic) IBOutlet UITextField *Pitch;
@property (weak, nonatomic) IBOutlet UITextField *Rate;
@end

@implementation ViewController
{
    // Path to the talking.bin file with the raw PCM data.
    NSString* mTalkingPath;
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    mTalkingPath = [[NSBundle mainBundle] pathForResource:@"talking" ofType:@"bin"];
}

-(IBAction)play:(id)sender {
    // Retrieve the field values and launch a new thread to play the audio.
    SonicParameters* params = [SonicParameters new];
    if (params) {
        params.mSpeed = valueOfTextField(self.Speed);
        params.mPitch = valueOfTextField(self.Pitch);
        params.mRate = valueOfTextField(self.Rate);
        NSThread* thread = [[NSThread alloc] initWithTarget:self
                                                   selector:@selector(playThread:)
                                             object:params];
        [thread start];
    }
}

-(void)playThread:(SonicParameters*)params {
    // This is essentially the run() function of SonicTest.java
    iOSAudioDevice* device = [[iOSAudioDevice alloc] initWith:kSamplesRate numChannels:kChannelCount];
    if (!device) {
        return;
    }
    Sonic* sonic = [[Sonic alloc] initWith:kSamplesRate channels:kChannelCount];
    if (!sonic) {
        return;
    }
    Byte* samples = malloc(kSamplesLength);
    if (!samples) {
        return;
    }
    Byte* modifiedSamples = malloc(kModifiedSamplesLength);
    if (!modifiedSamples) {
        free(samples);
        return;
    }
    NSInputStream* soundFile = [NSInputStream inputStreamWithFileAtPath:mTalkingPath];
    int bytesRead;
    if (soundFile) {
        [soundFile open];
        [sonic setSpeed:params.mSpeed];
        [sonic setPitch:params.mPitch];
        [sonic setRate:params.mRate];
        do {
            bytesRead = [soundFile read:samples maxLength:kSamplesLength];
            if (bytesRead > 0) {
                [sonic putBytes:samples lenBytes:bytesRead];
            } else {
                [sonic flush];
            }
            // We depart a bit from SonicTest.java here and call writeSamples with
            // small pieces of kModifiedSamplesLength bytes, so that can be stored
            // in each AudioQueue buffer.
            int available = [sonic availableBytes];
            while (available > 0) {
                unsigned size = available < kModifiedSamplesLength ? available : kModifiedSamplesLength;
                [sonic receiveBytes:modifiedSamples lenBytes:size];
                [device writeSamples:modifiedSamples length:size];
                available -= size;
            }
        } while (bytesRead > 0);
        [device flush];
        [soundFile close];
    }
    free(samples);
    free(modifiedSamples);
}

@end
