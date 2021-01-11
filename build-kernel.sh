#!/usr/bin/env bash
# shellcheck disable=SC2199
# shellcheck source=/dev/null
#
# Copyright (c) 2020 UtsavBalar1231 <utsavbalar1231@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cd /drone/src/

# Export Cross Compiler name
if [[ "$@" =~ "benzoclang"* ]]; then
	export COMPILER="BenzoClang-12.0"
elif [[ "$@" =~ "proton"* ]]; then
	if [[ "$@" =~ "lto"* ]]; then
		export COMPILER="ProtonClang-12.0 LTO"
	else
		export COMPILER="ProtonClang-12.0"
	fi
else
	export COMPILER="ProtonClang-12.0"
fi
# Export Build username
export KBUILD_BUILD_USER="Viciouspup"
export KBUILD_BUILD_HOST="Vroot"

# Enviromental Variables
DATE=$(date +"%d.%m.%y")
HOME="/drone/src/"
OUT_DIR=out/
if [[ "$@" =~ "lto"* ]]; then
	VERSION="IMMENSiTY-X-RAPHAEL-${TYPE}-LTO${DRONE_BUILD_NUMBER}-${DATE}"
else
	VERSION="IMMENSiTY-X-RAPHAEL-${TYPE}-${DRONE_BUILD_NUMBER}-${DATE}"
fi
BRANCH=`git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'`
KERNEL_LINK=https://GitHub.com/UtsavBalar1231/kernel_xiaomi_raphael
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
# BenzoClang
if [[ "$@" =~ "benzoclang"* ]]; then
	# Make defconfig
	make ARCH=arm64 \
		O=${OUT_DIR} \
		raphael_defconfig \
		-j${KEBABS}

	# Enable LLD
	scripts/config --file ${OUT_DIR}/.config \
		-d LTO \
		-d LTO_CLANG \
		-d SHADOW_CALL_STACK \
		-e TOOLS_SUPPORT_RELR \
		-e LD_LLD
	# Make olddefconfig
	cd ${OUT_DIR}
	make O=${OUT_DIR} \
		ARCH=arm64 \
		olddefconfig \
		-j${KEBABS}
	cd ../
	# Set compiler Path
	PATH=${HOME}/clang/bin/:${HOME}/arm64-gcc/bin/:${HOME}/arm32-gcc/bin/:$PATH
	make ARCH=arm64 \
		O=${OUT_DIR} \
		CC="clang" \
		LD="ld.lld" \
		AR="llvm-ar" \
		NM="llvm-nm" \
		HOSTCC="clang" \
		HOSTLD="ld.lld" \
		HOSTCXX="clang++" \
		STRIP="llvm-strip" \
		OBJCOPY="llvm-objcopy" \
		OBJDUMP="llvm-objdump" \
		READELF="llvm-readelf" \
		CLANG_TRIPLE="aarch64-linux-gnu-" \
		CROSS_COMPILE="aarch64-linux-android-" \
		CROSS_COMPILE_ARM32="arm-linux-androideabi-" \
		-j${KEBABS}
elif [[ "$@" =~ "proton"* ]]; then
	# Make defconfig
	make ARCH=arm64 \
		O=${OUT_DIR} \
		raphael_defconfig \
		-j${KEBABS}
	if [[ "$@" =~ "lto"* ]]; then
		# Enable LTO
		scripts/config --file ${OUT_DIR}/.config \
			-e LTO \
			-e LTO_CLANG \
			-d THINLTO \
			-d SHADOW_CALL_STACK \
			-e TOOLS_SUPPORT_RELR \
			-e LD_LLD
	else
		# Enable LLD
		scripts/config --file ${OUT_DIR}/.config \
			-d LTO \
			-d LTO_CLANG \
			-d SHADOW_CALL_STACK \
			-e TOOLS_SUPPORT_RELR \
			-e LD_LLD
	fi

	# Make olddefconfig
	cd ${OUT_DIR}
	make O=${OUT_DIR} \
		ARCH=arm64 \
		olddefconfig \
		-j${KEBABS}
	cd ../
	# Set compiler Path
	PATH=${HOME}/clang/bin/:$PATH
	make ARCH=arm64 \
		O=${OUT_DIR} \
		CC="clang" \
		LD="ld.lld" \
		AR="llvm-ar" \
		NM="llvm-nm" \
		HOSTCC="clang" \
		HOSTLD="ld.lld" \
		HOSTCXX="clang++" \
		STRIP="llvm-strip" \
		OBJCOPY="llvm-objcopy" \
		OBJDUMP="llvm-objdump" \
		READELF="llvm-readelf" \
		CLANG_TRIPLE="aarch64-linux-gnu-" \
		CROSS_COMPILE="aarch64-linux-gnu-" \
		CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
		-j${KEBABS}
else
	# Make defconfig
	make ARCH=arm64 \
		O=${OUT_DIR} \
		raphael_defconfig \
		-j${KEBABS}
	# Enable LLD
	scripts/config --file ${OUT_DIR}/.config \
		-d LTO \
		-d LTO_CLANG \
		-d SHADOW_CALL_STACK \
		-e TOOLS_SUPPORT_RELR \
		-e LD_LLD
	# Make olddefconfig
	cd ${OUT_DIR}
	make O=${OUT_DIR} \
		ARCH=arm64 \
		olddefconfig \
		-j${KEBABS}
	cd ../
	# Set compiler Path
	PATH=${HOME}/clang/bin/:$PATH
	make ARCH=arm64 \
		O=${OUT_DIR} \
		CC="clang" \
		LD="ld.lld" \
		AR="llvm-ar" \
		NM="llvm-nm" \
		HOSTCC="clang" \
		HOSTLD="ld.lld" \
		HOSTCXX="clang++" \
		STRIP="llvm-strip" \
		OBJCOPY="llvm-objcopy" \
		OBJDUMP="llvm-objdump" \
		READELF="llvm-readelf" \
		CLANG_TRIPLE="aarch64-linux-gnu-" \
		CROSS_COMPILE="aarch64-linux-gnu-" \
		CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
		-j${KEBABS}
fi

END=$(date +"%s")
DIFF=$(( END - START))

# Kernel uploading
cd $(pwd)/${OUT_DIR}/arch/arm64/boot/
curl curl --upload-file Image.gz-dtb https://transfer.sh/Image.gz-dtb

cd $(pwd)

# Cleanup
rm -fr anykernel/
