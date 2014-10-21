// This is a rewritting in Objective C of the AndroidAudioDevice.java
// file from https://github.com/waywardgeek/sonic-ndk
// It is widely inspired from Matt Gallagher's AudioStream.m whose license
// is copied below. See https://github.com/mattgallagher/AudioStreamer/
//
///////////////////
//  AudioStreamer.m
//  StreamingAudioPlayer
//
//  Created by Matt Gallagher on 27/09/08.
//  Copyright 2008 Matt Gallagher. All rights reserved.
//
//  This software is provided 'as-is', without any express or implied
//  warranty. In no event will the authors be held liable for any damages
//  arising from the use of this software. Permission is granted to anyone to
//  use this software for any purpose, including commercial applications, and to
//  alter it and redistribute it freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source
//     distribution.
///////////////////

#import "iOSAudioDevice.h"

#import <AudioToolbox/AudioToolbox.h>
#import <pthread.h>

// We use the three buffers as recommended by Apple documentation
// The buffer sizes are large enough to store the pieces sent at
// each writeSample call (at most kModifiedSamplesLength bytes).
const unsigned int kAudioQueueBufferCount = 3;
static const unsigned int kAudioQueueBufferSize = 2048 * 16;

@interface iOSAudioDevice ()
-(void)audioQueueCallback:(AudioQueueRef)audioQueue buffer:(AudioQueueBufferRef)buffer;
@end

@implementation iOSAudioDevice
{
    AudioStreamBasicDescription mAudioFormat;
    AudioQueueRef mAudioQueue;
    AudioQueueBufferRef mAudioQueueBuffer[kAudioQueueBufferCount];
    BOOL mAudioQueueBufferInUse[kAudioQueueBufferCount];
    unsigned int mCurrentAudioBufferIndex;
    unsigned int mCurrentAudioBufferBytesFilled;
    pthread_mutex_t mAudioQueueBufferMutex;
    pthread_cond_t mAudioQueueBufferReady;
}

-(id)initWith:(int)sampleRate numChannels:(int)numChannels
{
    self = [super init];
    if (self) {
        @synchronized(self) {
            // Initialize the audio format to read linear PCM.
            mAudioFormat.mFormatID = kAudioFormatLinearPCM;
            mAudioFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
            mAudioFormat.mBitsPerChannel = 8 * sizeof(short);
            mAudioFormat.mChannelsPerFrame = numChannels;
            mAudioFormat.mBytesPerFrame = mAudioFormat.mChannelsPerFrame * mAudioFormat.mBitsPerChannel / 8;
            mAudioFormat.mFramesPerPacket = 1;
            mAudioFormat.mBytesPerPacket = mAudioFormat.mBytesPerFrame * mAudioFormat.mFramesPerPacket;
            mAudioFormat.mSampleRate = sampleRate;
            mAudioFormat.mReserved = 0;

            // Create a new audio queue for playback.
            OSStatus error = AudioQueueNewOutput(&mAudioFormat,
                                                 audioQueueCallback,
                                                 (__bridge void *)(self),
                                                 nil,
                                                 nil,
                                                 0,
                                                 &mAudioQueue);
            if (error) {
                NSLog(@"Failed to create new audio queue output!");
                return nil;
            }

            // Allocate new audio queue buffers.
            for (unsigned int i = 0; i < kAudioQueueBufferCount; i++) {
                error = AudioQueueAllocateBuffer(mAudioQueue,
                                                  kAudioQueueBufferSize,
                                                  &mAudioQueueBuffer[i]);
                if (error) {
                    NSLog(@"Failed to allocate new audio queue buffer!");
                    return nil;
                }
                mAudioQueueBufferInUse[i] = NO;
            }

            // Initialize status for current buffer to fill.
            mCurrentAudioBufferIndex = 0;
            mCurrentAudioBufferBytesFilled = 0;

            // Initialize mutex and conditions.
            pthread_mutex_init(&mAudioQueueBufferMutex, nil);
            pthread_cond_init(&mAudioQueueBufferReady, nil);
        }
    }
    return self;
}

-(BOOL)flush
{
    @synchronized(self) {
        // Queue the current audio buffer corresponding to the end of the audio.
        [self enqueueBuffer];

        // Flush and stop the queue.
        OSStatus error = AudioQueueFlush(mAudioQueue);
        if (error) {
            NSLog(@"Failed to flush audio queue!");
            return NO;
        }
        error = AudioQueueStop(mAudioQueue, NO);
        if (error) {
            NSLog(@"Failed to stop audio queue!");
            return NO;
        }

        // Cleanup
        error = AudioQueueDispose(mAudioQueue, NO);
        if (error) {
            NSLog(@"Failed to dispose audio queue!");
            return NO;
        }
        return YES;
    }
}

-(void)writeSamples:(const Byte*)samples length:(int)length
{
    unsigned int offset = 0;
    while (length > 0) {
        // Enqueue the buffer if there is not enough space.
        size_t remainingSpaceInBuffer = kAudioQueueBufferSize - mCurrentAudioBufferBytesFilled;
        if (remainingSpaceInBuffer < length) {
            [self enqueueBuffer];
        }

        @synchronized(self) {
            // Copy the data into the current buffer.
            AudioQueueBufferRef buffer = mAudioQueueBuffer[mCurrentAudioBufferIndex];
            remainingSpaceInBuffer = kAudioQueueBufferSize - mCurrentAudioBufferBytesFilled;
            unsigned int size = remainingSpaceInBuffer < length ? remainingSpaceInBuffer : length;
            memcpy((Byte*)buffer->mAudioData + mCurrentAudioBufferBytesFilled,
                   (const Byte*)(samples + offset), size);
            mCurrentAudioBufferBytesFilled += size;
            length -= size;
            offset += size;
        }
    }
}

- (BOOL)enqueueBuffer
{
    @synchronized(self)
    {
        // Marked this buffer as used.
        mAudioQueueBufferInUse[mCurrentAudioBufferIndex] = YES;

        // Enqueue the buffer.
        AudioQueueBufferRef buffer = mAudioQueueBuffer[mCurrentAudioBufferIndex];
        buffer->mAudioDataByteSize = mCurrentAudioBufferBytesFilled;
        OSStatus error = AudioQueueEnqueueBuffer(mAudioQueue, buffer, 0, nil);
        if (error) {
            NSLog(@"Failed to enqueue buffer!");
            return NO;
        }

        // Start the queue if it is not already running.
        error = AudioQueueStart(mAudioQueue, nil);
        if (error) {
            NSLog(@"Failed to start queue!");
            return NO;
        }

        // Move to the next buffer.
        mCurrentAudioBufferIndex = (mCurrentAudioBufferIndex + 1) % kAudioQueueBufferCount;
        mCurrentAudioBufferBytesFilled = 0;
    }

    // Wait that the buffer becomes free.
    pthread_mutex_lock(&mAudioQueueBufferMutex);
    while (mAudioQueueBufferInUse[mCurrentAudioBufferBytesFilled]) {
        pthread_cond_wait(&mAudioQueueBufferReady, &mAudioQueueBufferMutex);
    }
    pthread_mutex_unlock(&mAudioQueueBufferMutex);
    return YES;
}

static void audioQueueCallback(void* clientData, AudioQueueRef audioQueue, AudioQueueBufferRef buffer)
{
    // Just forward the callback to the Objective-C version...
    iOSAudioDevice* device = (__bridge iOSAudioDevice *)(clientData);
    [device audioQueueCallback:audioQueue buffer:buffer];
}

-(void)audioQueueCallback:(AudioQueueRef)audioQueue buffer:(AudioQueueBufferRef)buffer;
{
    // Try and find the index of the buffer.
    unsigned int i;
    for (i = 0; i < kAudioQueueBufferCount; i++) {
        if (buffer == mAudioQueueBuffer[i]) {
            break;
        }
    }
    if (i == kAudioQueueBufferCount) {
        NSLog(@"Buffer not found!");
        pthread_mutex_lock(&mAudioQueueBufferMutex);
        pthread_cond_signal(&mAudioQueueBufferReady);
        pthread_mutex_unlock(&mAudioQueueBufferMutex);
        return;
    }

    // Inform that the buffer is now free.
    pthread_mutex_lock(&mAudioQueueBufferMutex);
    mAudioQueueBufferInUse[i] = NO;
    pthread_cond_signal(&mAudioQueueBufferReady);
    pthread_mutex_unlock(&mAudioQueueBufferMutex);
}

@end
