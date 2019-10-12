# wine-lol

I literally stole all of this from https://github.com/M-Reimer/wine-lol-glibc/
and https://github.com/M-Reimer/wine-lol/

Random scripts to build wine-lol and wine-lol-glibc directly on Ubuntu. It
doesn't make debian packages but considering that everything is confined
to within /opt/wine-lol proper packaging probably isn't needed anyways.

Slight changes:

* FORTIFY_SOURCE stuff in wine-lol-glibc build script caused build to fail horribly
  and I have no clue what it's supposed to accomplish anyways so it's gone
* Compiled wine without gstreamer support as it can use pulseaudio directly

## Build instructions

wine-lol-glibc should be built and installed before attempting to build wine-lol,
as wine-lol expects wine-lol-glibc to already exist in /opt/wine-lol. Dependencies
are listed in the scripts themselves as comments. The resulting tarballs should
only contain files under /opt/wine-lol.

