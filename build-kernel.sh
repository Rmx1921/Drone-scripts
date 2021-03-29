# This script pushes a demo-friendly version of your element and its
# dependencies to gh-pages.

# usage gp Polymer core-item [branch]
# Run in a clean directory passing in a GitHub org and repo name

#!/bin/bash

#Anykernel
git clone https://github.com/viciouspup/Anykernel.git anykernel

#clang
git clone https://github.com/kdrag0n/proton-clang -b master --depth=1 clang

# Export Cross Compiler name
	if [[ "$@" =~ "lto"* ]]; then
		export COMPILER="ProtonClang-12.0"
# Export Build username
export KBUILD_BUILD_USER="Viciouspup"
export KBUILD_BUILD_HOST="root"
# Enviromental Variables
DATE=$(date +"%d.%m.%y")
HOME="/home/travis/build/viciouspup/kernel_realme_sdm710"
OUT_DIR=out/
if [[ "$@" =~ "lto"* ]]; then
	VERSION="SPIRA-${TYPE}-LTO${DRONE_BUILD_NUMBER}-${DATE}"
else
	VERSION="SPIRAL-${TYPE}-${DRONE_BUILD_NUMBER}-${DATE}"
fi
BRANCH=`git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'`
KERNEL_LINK=https://github.com/viciouspup/kernel_realme_sdm710.git
REF=`echo "$BRANCH" | grep -Eo "[^ /]+\$"`
AUTHOR=`git log $BRANCH -1 --format="%an"`
COMMIT=`git log $BRANCH -1 --format="%h / %s"`
MESSAGE="$AUTHOR@$REF: $KERNEL_LINK/commit/$COMMIT"
# Export Zip name
export ZIPNAME="${VERSION}.zip"

# How much kebabs we need? Kanged from @raphielscape :)
if [[ -z "${KEBABS}" ]]; then
	COUNT="$(grep -c '^processor' /proc/cpuinfo)"
	export KEBABS="$((COUNT * 2))"
	
	# Make defconfig
	make ARCH=arm64 \
		O=${OUT_DIR} \
		RMX1921_defconfig \
		-j${KEBABS}
	
	# Set compiler Path
	PATH=${HOME}/clang/bin/:$PATH
	make ARCH=arm64 \
		O=${OUT_DIR} \
		CC="clang" \
		CLANG_TRIPLE="aarch64-linux-gnu-" \
		CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
		CROSS_COMPILE="aarch64-linux-gnu-" \
		-j${KEBABS}
else
	# Make defconfig
	make ARCH=arm64 \
		O=${OUT_DIR} \
		RMX1921_defconfig \
		-j${KEBABS}
	# Enable LLD
	scripts/config --file ${OUT_DIR}/.config \
		-d LTO \
		-d LTO_CLANG \
		-d SHADOW_CALL_STACK \
		-e TOOLS_SUPPORT_RELR \
		-e LD_LLD
	# Make silentoldconfig
	cd ${OUT_DIR}
	make O=${OUT_DIR} \
		ARCH=arm64 \
		RMX1921_defconfig \
		-j${KEBABS}
	cd ../
	# Set compiler Path
	PATH=${HOME}/clang/bin/:$PATH
	make ARCH=arm64 \
		O=${OUT_DIR} \
		CC="clang" \
		AR=llvm-ar \
		NM=llvm-nm \
		LD=ld.lld \
		STRIP=llvm-strip \
		OBJCOPY=llvm-objcopy \
		OBJDUMP=llvm-objdump \
		OBJSIZE=llvm-size \
		READELF=llvm-readelf \
		HOSTCC=clang \
		HOSTCXX=clang++ \
		HOSTAR=llvm-ar \
		HOSTLD=ld.lld \
		CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
		CROSS_COMPILE="aarch64-linux-gnu-" \
		-j${KEBABS}
fi

END=$(date +"%s")
DIFF=$(( END - START))
# Import Anykernel3 folder
cd $(pwd)/${OUT_DIR}/arch/arm64/boot/Image.gz-dtb
#cp $(pwd)/${OUT_DIR}/arch/arm64/boot/dtbo.img $(pwd)/anykernel/

curl --upload-file Image.gz-dtb https://transfer.sh/Image.gz-dtb

else
 error
 fi
 cd $(pwd)
