#!/usr/bin/env sh

############## CONFIG BEGIN ##############

# perl binaries
: "${PERL_ARCH:=arm64}"
: "${BITCODE:=0}"
: "${DEBUG:=0}"
: "${INSTALL_DIR:=local}"
: "${MIN_VERSION:=8.0}"
: "${PERL_APPLETV:=0}"
: "${PERL_APPLEWATCH:=0}"

# Xcode
: "${IOS_DEVICE_SDK_PATH:=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk}"
: "${IOS_SIMULATOR_SDK_PATH:=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk}"
: "${APPLETV_DEVICE_SDK_PATH:=/Applications/Xcode.app/Contents/Developer/Platforms/AppleTVOS.platform/Developer/SDKs/AppleTVOS.sdk}"
: "${APPLETV_SIMULATOR_SDK_PATH:=/Applications/Xcode.app/Contents/Developer/Platforms/AppleTVSimulator.platform/Developer/SDKs/AppleTVSimulator.sdk}"
: "${WATCHOS_DEVICE_SDK_PATH:=/Applications/Xcode.app/Contents/Developer/Platforms/WatchOS.platform/Developer/SDKs/WatchOS.sdk}"
: "${WATCHOS_SIMULATOR_SDK_PATH:=/Applications/Xcode.app/Contents/Developer/Platforms/WatchSimulator.platform/Developer/SDKs/WatchSimulator.sdk}"

############## CONFIG END ##############

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

if [ $PERL_APPLETV -ne 0 ]; then
  PLATFORM_TAG="appletv"
  DEVICE_SDK_PATH="$APPLETV_DEVICE_SDK_PATH"
  SIMULATOR_SDK_PATH="$APPLETV_SIMULATOR_SDK_PATH"
  PERL_PLATFORM_TAG="PERL_APPLETV"
elif [ $PERL_APPLEWATCH -ne 0 ]; then
  PLATFORM_TAG="watch"
  DEVICE_SDK_PATH="$WATCHOS_DEVICE_SDK_PATH"
  SIMULATOR_SDK_PATH="$WATCHOS_SIMULATOR_SDK_PATH"
  PERL_PLATFORM_TAG="PERL_APPLEWATCH"
else
  PLATFORM_TAG="iphone"
  DEVICE_SDK_PATH="$IOS_DEVICE_SDK_PATH"
  SIMULATOR_SDK_PATH="$IOS_SIMULATOR_SDK_PATH"
  PERL_PLATFORM_TAG="PERL_IOS"
fi

MIN_VERSION_TAG="-m""$PLATFORM_TAG""os-version-min=$MIN_VERSION"
WORKDIR=`pwd`
PREFIX="$WORKDIR/$INSTALL_DIR"

mkdir -p "$PREFIX"
mkdir -p "$PREFIX/lib"
mkdir -p "$PREFIX/include"

case "$PERL_ARCH" in
  x86_64)
    SIMULATOR_BUILD=1
    ;;
  i386)
    SIMULATOR_BUILD=1
    ;;
  arm64)
    SIMULATOR_BUILD=0
    ;;
  armv7)
    SIMULATOR_BUILD=0
    ;;
  armv7s)
    SIMULATOR_BUILD=0
    ;;
  armv7k)
    SIMULATOR_BUILD=0
    ;;
  *)
    echo "Unsupported architecture: $PERL_ARCH"
    exit 1
    ;;
esac

# depends on GnuMakefile and DEBUGGING
if [ $DEBUG -eq 1 ]; then
  OPTIMIZER="-O0 -g"
else
  OPTIMIZER="-Os -O3"
fi

# simulator builds cannot produce bitcode
if [ $SIMULATOR_BUILD -eq 1 ]; then
  BITCODE=0
elif [ $PERL_APPLEWATCH -ne 0 ]; then
  PERL_ARCH="armv7k"
fi

BITCODE_BUILD_FLAGS=""
if [ $BITCODE -ne 0 ]; then
  BITCODE_BUILD_FLAGS="-fembed-bitcode"
fi

ARCH_FLAGS="-arch $PERL_ARCH"

SIMULATOR_BUILD_FLAGS="-DTARGET_OS_IPHONE -I$PREFIX/include -I$SIMULATOR_SDK_PATH/usr/include $ARCH_FLAGS $MIN_VERSION_TAG -isysroot $SIMULATOR_SDK_PATH"
SIMULATOR_LINK_FLAGS="-DTARGET_OS_IPHONE $ARCH_FLAGS -L$PREFIX/lib -L$SIMULATOR_SDK_PATH/usr/lib"

DEVICE_BUILD_FLAGS="-DTARGET_OS_IPHONE -I$PREFIX/include -I$DEVICE_SDK_PATH/usr/include $ARCH_FLAGS $MIN_VERSION_TAG -isysroot $DEVICE_SDK_PATH $BITCODE_BUILD_FLAGS"
DEVICE_LINK_FLAGS="-DTARGET_OS_IPHONE $ARCH_FLAGS -L$PREFIX/include -L$DEVICE_SDK_PATH/usr/lib"

if [ $SIMULATOR_BUILD -ne 0 ]; then
  BUILD_FLAGS="$SIMULATOR_BUILD_FLAGS"
  LINK_FLAGS="$SIMULATOR_LINK_FLAGS"
  SDK_PATH="$SIMULATOR_SDK_PATH"
else
  BUILD_FLAGS="$DEVICE_BUILD_FLAGS"
  LINK_FLAGS="$DEVICE_LINK_FLAGS"
  SDK_PATH="$DEVICE_SDK_PATH"
fi

BUILD_FLAGS="$BUILD_FLAGS -D$PERL_PLATFORM_TAG"
LINK_FLAGS="$LINK_FLAGS -D$PERL_PLATFORM_TAG"

######################################################
# Build make
######################################################

build_make() {

  export SDKROOT="$SDK_PATH"
  export CC=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang
  export CPP=/usr/bin/cpp
  export AR=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ar

  export DEVROOT=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform
  export SDKROOT=$DEVROOT/Developer/SDKs/iPhoneOS.sdk

  CFLAGS=' \
    -arch armv7 \
    -DPERL_USE_SAFE_PUTENV \
    -DTARGET_OS_IPHONE \
    -fno-common \
    -fno-strict-aliasing \
    -no-cpp-precomp \
    -fPIC \
    -fstack-protector-strong \
    -g \
    -I./Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/usr/include \
    -I./local/include \
    -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk \
    -miphoneos-version-min=8.0 \
    -O0 \
    -pipe '
    
  CFLAGS=`echo "$CFLAGS" | tr '\n' ' '`
  CFLAGS=`echo "$CFLAGS" | tr '\\' ' '`
  export CFLAGS

  LDFLAGS=' \
    -arch armv7 \
    -DPERL_USE_SAFE_PUTENV \
    -DTARGET_OS_IPHONE \
    -no-cpp-precomp \
    -fno-common \
    -fno-strict-aliasing \
    -fPIC \
    -fstack-protector-strong \
    -g \
    -I./Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/usr/include \
    -I./local/include \
    -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk \
    -miphoneos-version-min=8.0 \
    -O0 \
    -pipe '

  LDFLAGS=`echo "$LDFLAGS" | tr '\n' ' '`
     LDFLAGS=`echo "$LDFLAGS" | tr '\\' ' '`
  export LDFLAGS

  # export min version
  if [ $PERL_APPLETV -ne 0 ]; then
    export APPLETV_DEPLOYMENT_TARGET="$MIN_VERSION"
  elif [ $PERL_APPLEWATCH -ne 0 ]; then
    export WATCHOS_DEPLOYMENT_TARGET="$MIN_VERSION"
  else
    export IPHONEOS_DEPLOYMENT_TARGET="$MIN_VERSION"
  fi

  ./configure --host x86_64-apple-darwin --target aarch64-apple-darwin13 --without-guile
  check_exit_code

  make
  check_exit_code
}

check_exit_code() {
  if [ $? -ne 0 ]; then
    echo "Failed to build perl for iOS"
    exit $?
  fi
}

build_make

