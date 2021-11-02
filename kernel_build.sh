#!/usr/bin/env bash

 #
 # Script For Building Android arm64 Kernel
 #
 
 # Specify Kernel Directory
KERNEL_DIR="$(pwd)"

# Zip Name
ZIPNAME="Serum"

# Specify compiler.
if [ "$@" = "--gcc" ]; then
COMPILER=gcc
elif [ "$@" = "--clang" ]; then
COMPILER=clang
fi

# Device Name and Model
MODEL=Xiaomi
DEVICE=Whyred
# Kernel Version Code
VERSION=X2
# Linker
LINKER=ld
# Path
IMAGE=$(pwd)/out/arch/arm64/boot/Image
DTB=$(pwd)/out/arch/arm64/boot/dts/qcom/whyred.dtb

# Verbose Build
VERBOSE=0

# Kernel Version
KERVER=$(make kernelversion)

COMMIT_HEAD=$(git log --oneline -1)

# Date and Time
DATE=$(TZ=Asia/Kolkata date +"%Y%m%d-%T")
START=$(date +"%s")
DATE_POSTFIX=$(date +"%Y%m%d%H%M%S")

FINAL_ZIP=${ZIPNAME}-${VERSION}-${DEVICE}-${COMPILER}-$DATE_POSTFIX.zip
##----------------------------------------------------------##

# Cloning Dependencies
function clone() {
    XD " Cloning Dependencies "
    if [ $COMPILER = "clang" ]; then
       # Set Clang Toolchain
		git clone --depth=1  https://gitlab.com/Panchajanya1999/azure-clang.git clang
		PATH="${KERNEL_DIR}/clang/bin:$PATH"
    elif [ $COMPILER = "gcc" ]; then
	    # Set GCC Toolchain
		git clone --depth=1 https://github.com/mvaisakh/gcc-arm64.git gcc64
		git clone --depth=1 https://github.com/mvaisakh/gcc-arm.git gcc32
		PATH=$KERNEL_DIR/gcc64/bin/:$KERNEL_DIR/gcc32/bin/:/usr/bin:$PATH
    fi
        # Set AnyKernel3 Link
		git clone --depth=1 https://github.com/arnavpuranik/AnyKernel3 AnyKernel3
}
##------------------------------------------------------##

function exports() {
    if [ $COMPILER = "clang" ]; then
    export KBUILD_COMPILER_STRING=$(${KERNEL_DIR}/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
    elif [ $COMPILER = "gcc" ]; then
    export KBUILD_COMPILER_STRING=$("$KERNEL_DIR/gcc64"/bin/aarch64-elf-gcc --version | head -n 1)
    fi
    export ARCH=arm64
    export SUBARCH=arm64
    export LOCALVERSION="-${VERSION}"
    export KBUILD_BUILD_HOST=SerumLab
    export KBUILD_BUILD_USER="Arnav"
    export OUT_DIR=${KERNEL_DIR}/out
    export BSDIFF=${KERNEL_DIR}/bin/bsdiff
    export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUMBER
    export CI_BRANCH=$DRONE_BRANCH
    export PROCS=$(nproc --all)

}

##---------------------------------------------------------##

function disable_defconfig() {
${KERNEL_DIR}/scripts/config --file ${OUT_DIR}/.config -d $1
}

##---------------------------------------------------------##
function sendinfo() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="<b>$KBUILD_BUILD_VERSION CI Build Triggered</b>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Kolkata date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Pipeline Host : </b><code>$KBUILD_BUILD_HOST</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>Top Commit : </b><a href='$DRONE_COMMIT_LINK'>$COMMIT_HEAD</a>"
}

##----------------------------------------------------------------##

function XD() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="$1"
}

##----------------------------------------------------------##

function push() {
    curl -F document=@$1 "https://api.telegram.org/bot$token/sendDocument" \
         -F chat_id="$chat_id" \
         -F "disable_web_page_preview=true" \
         -F "parse_mode=html" \
         -F caption="$2"
}

##----------------------------------------------------------##

function compile() {
	if [ $COMPILER = "clang" ]; then
          make $1 \
	      -j"${JOBS}" \
	      O=$OUT_DIR \
	      ARCH=arm64 \
	      CC=clang \
	      CROSS_COMPILE=aarch64-linux-gnu- \
	      CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
	      AR=llvm-ar \
	      NM=llvm-nm \
	      OBJCOPY=llvm-objcopy \
	      OBJDUMP=llvm-objdump \
	      STRIP=llvm-strip \
	      READELF=llvm-readelf \
	      OBJSIZE=llvm-size \
	      V=$VERBOSE 2>&1 | tee error.log
	      elif [ $COMPILER = "gcc" ]; then
				make $1 \
	            -j"${JOBS}" \
	            O=$OUT_DIR \
				ARCH=arm64 \
				CROSS_COMPILE_ARM32=arm-eabi- \
				CROSS_COMPILE=aarch64-elf- \
				LD=aarch64-elf-${LINKER} \
				AR=llvm-ar \
				NM=llvm-nm \
				OBJCOPY=llvm-objcopy \
				OBJDUMP=llvm-objdump \
				STRIP=llvm-strip \
				OBJSIZE=llvm-size \
				V=$VERBOSE 2>&1 | tee $2.log
		    fi
}    
function move_files() {
    # Copy Files To AnyKernel3 Zip
   xz -c ${IMAGE} > AnyKernel3/Image.xz
   xz -c ${DTB} > AnyKernel3/kernel_dtb.xz
}
##----------------------------------------------------------##

function zipping() {
    XD " Kernel Compilation Finished. Started Zipping "
    cd AnyKernel3 || exit 1
    zip -r9 ${FINAL_ZIP} *
    MD5CHECK=$(md5sum "$FINAL_ZIP" | cut -d' ' -f1)
    push "$FINAL_ZIP" "Build took : $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s) | For <b>$MODEL ($DEVICE)</b> | <b>${KBUILD_COMPILER_STRING}</b> | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"
    cd ..
}
##----------------------------------------------------------##

clone
exports
sendinfo
compile whyred_defconfig gen
compile dtbs dtb
compile Image img1
if ! [ -a "$IMAGE" ]; then
        push "img1.log" "Build Throws Errors"
        exit 1
        else
        mv $IMAGE out/Image_N
fi        
disable_defconfig CONFIG_XIAOMI_NEW_CAMERA_BLOBS
compile Image img2
if ! [ -a "$IMAGE" ]; then
        push "img2.log" "Build Throws Errors"
        exit 1
fi        
bin/bsdiff out/arch/arm64/boot/Image out/Image_N AnyKernel3/bspatch/newcam.patch
move_files
END=$(date +"%s")
DIFF=$(($END - $START))
zipping

##----------------*****-----------------------------##
