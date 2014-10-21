Pod::Spec.new do |s|
  s.name    = "Sonic"
  s.version = "0.0.1"
  s.summary = "Simple library to speed up or slow down speech."
  s.description = <<-DESC
        Sonic is a simple algorithm for speeding up or slowing down speech.
        However, it's optimized for speed ups of over 2, unlike previous
        algorithms for changing speech rate. The Sonic library is a very simple
        ANSI C library that is designed to easily be integrated into streaming
        voice applications, like TTS back ends.
      DESC
  s.homepage = "http://dev.vinux-project.org/sonic/"
  s.authors = { "Bill Cox" => "waywardgeek@gmail.com",
                "Frédéric Wang" => "fred.wang@free.fr" }
  s.license  = { :type => "LGPL and public domain", :text => <<-LICENSE
              The sonic.c and sonic.h files are written by Bill Cox and licensed
	      under GNU Lesser General Public License version 2.1 (see the
	      COPYING file). The ObjectiveSonic.m and ObjectiveSonic.h files
	      have been rewritten by Frédéric Wang from sonic-ndk files and are
	      are placed into the public domain (see the UNLICENCE file).
            LICENSE
  }

  s.source = { :git => 'https://github.com/fred-wang/ObjectiveSonic.git',
               :tag => s.version.to_s }
  s.source_files = "Sonic/*.{c,h,m}"
  s.public_header_files = "Sonic/ObjectiveSonic.h"
  s.requires_arc = false
end
