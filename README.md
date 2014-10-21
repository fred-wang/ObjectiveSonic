Objective Sonic
===============

This is an Objective-C wrapper for
[libsonic](http://dev.vinux-project.org/sonic/) that exposes
an object-oriented API similar to the one of the
[sonic-sdk](https://github.com/waywardgeek/sonic-ndk/).

The recommended way to integrate
this library into your Objective-C project is to use
[CocoaPods](http://cocoapods.org/) by adding `'Sonic'` to your Podfile,
but you can as well just copy the `Sonic/` directory into your working
directory.

`SonicTest/` contains a sample iOS application that uses the libsonic
library and is similar to the Android application available in sonic-ndk.

The `sonic.c` and `sonic.h` files are licensed under GNU Lesser General
Public License version 2.1 (see the `COPYING` file). The
`iOSAudioDevice.m` file of SonicTest is based on Matt Gallagher's
[mAudioStream.m](https://github.com/mattgallagher/AudioStreamer/blob/master/Classes/AudioStreamer.m)
and is distributed under a permissive free software license.
All the other files are placed into the public domain
(see the `UNLICENSE` file).
