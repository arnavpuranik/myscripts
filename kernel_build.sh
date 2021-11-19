#!/usr/bin/env bash

#
# Script For Building Android arm64 Kernel
#

# Device Name and Codename of the device
MODEL="Redmi Note 5 Pro"

DEVICE="whyred"

# The defconfig which needs to be used
DEFCONFIG=whyred_defconfig

# Kernel Directory
KERNEL_DIR=$(pwd)

# The version code of the Kernel
VERSION=X2

# Path of final Image 
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb

# Compiler which needs to be used (Clang or gcc)
COMPILER=gcc

# Verbose build
# 0 is Quiet | 1 is verbose | 2 gives reason for rebuilding targets
VERBOSE=0

# For Drone CI
                export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUMBER
		export KBUILD_BUILD_HOST=$DRONE_SYSTEM_HOST
		export CI_BRANCH=$DRONE_BRANCH
		export BASEDIR=$DRONE_REPO_NAME # overriding
		export SERVER_URL="${DRONE_SYSTEM_PROTO}://${DRONE_SYSTEM_HOSTNAME}/arnavpuranik/${BASEDIR}/${KBUILD_BUILD_VERSION}"
                export PROCS=$(nproc --all)

# Set Date 
DATE=$(TZ=Asia/Kolkata date +"%Y%m%d-%T")
START=$(date +"%s")
DATE_POSTFIX=$(date +"%Y%m%d%H%M%S")

# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

#Check Kernel Version
KERVER=$(make kernelversion)

clone() {
	echo " Cloning Dependencies "
	if [ $COMPILER = "gcc" ]
	then
		echo "|| Cloning GCC ||"
		git clone --depth=1 https://github.com/arter97/arm64-gcc.git gcc64
     git clone --depth=1 https://github.com/arter97/arm32-gcc.git gcc32
	elif [ $COMPILER = "clang" ]
	then
	        echo  "|| Cloning Clang-14 ||"
		git clone --depth=1  https://github.com/kdrag0n/proton-clang clang
	fi

         echo "|| Cloning Anykernel ||"
	git clone https://github.com/arnavpuranik/AnyKernel3 -b backup
}

# Export
export ARCH=arm64
export SUBARCH=arm64
export LOCALVERSION="-${VERSION}"
export KBUILD_BUILD_HOST=SerumLab
export KBUILD_BUILD_USER="Arnav"

function XD() {
if [ $COMPILER = "clang" ]
	then
        export KBUILD_COMPILER_STRING=$(${KERNEL_DIR}/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		PATH="${PWD}/clang/bin:$PATH"
	elif [ $COMPILER = "gcc" ]
	then
		export KBUILD_COMPILER_STRING=$(${KERNEL_DIR}/gcc64/bin/aarch64-elf-gcc --version | head -n 1)
		PATH=${KERNEL_DIR}/gcc64/bin/:$KERNEL_DIR/gcc32/bin/:/usr/bin:$PATH
	fi
}
# Send info plox channel
function sendinfo() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="<b>$KBUILD_BUILD_VERSION CI Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Kolkata date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Pipeline Host : </b><code>$KBUILD_BUILD_HOST</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>Top Commit : </b><a href='$DRONE_COMMIT_LINK'>$COMMIT_HEAD</a>"
}
# Push kernel to channel
function push() {
    cd AnyKernel3
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$token/sendDocument" \
        -F chat_id="$chat_id" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For <b>$MODEL ($DEVICE)</b> | <b>${KBUILD_COMPILER_STRING}</b>"
}
# Fin Error
function finerr() {
    LOG=error.log
   curl -F document=@$LOG "https://api.telegram.org/bot$token/sendDocument" \
        -F chat_id="$chat_id" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build throw an error(s)"
    exit 1
}
# Compile plox
function compile() {
           
    if [ $COMPILER = "clang" ]
	then
		make O=out ARCH=arm64 ${DEFCONFIG}
		make -j$(nproc --all) O=out \
				ARCH=arm64 \
				CC=clang \
				AR=llvm-ar \
				NM=llvm-nm \
				OBJCOPY=llvm-objcopy \
				OBJDUMP=llvm-objdump \
				STRIP=llvm-strip \
                                V=$VERBOSE \
				CROSS_COMPILE=aarch64-linux-gnu- \
          CROSS_COMPILE_ARM32=arm-linux-gnueabi- 2>&1 | tee error.log

	elif [ $COMPILER = "gcc" ]
	then
	        make O=out ARCH=arm64 ${DEFCONFIG}
	        make -j$(nproc --all) O=out \
	    	                ARCH=arm64 \
                                CROSS_COMPILE_ARM32=arm-eabi- \
                                CROSS_COMPILE=aarch64-elf- \
			        AR=aarch64-elf-ar \
			        OBJDUMP=aarch64-elf-objdump \
			        STRIP=aarch64-elf-strip \
                                V=$VERBOSE 2>&1 | tee error.log
	fi

    if ! [ -a "$IMAGE" ]; then
        finerr
        exit 1
    fi
    cp $IMAGE AnyKernel3
}
# Zipping
function zipping() {
    cd AnyKernel3 || exit 1
    zip -r9 Serum-${VERSION}_${DEVICE}-BETA-KERNEL-${DATE_POSTFIX}.zip *
    cd ..
}
clone
XD
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
