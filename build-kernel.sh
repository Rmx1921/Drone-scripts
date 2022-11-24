#!/usr/bin/env bash
# shellcheck disable=SC2199
# shellcheck disable=SC2086
# shellcheck source=/dev/null
#
# Copyright (C) 2020-22 UtsavBalar1231 <utsavbalar1231@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cd /drone/src/ || exit

HOME="/drone/src"

if [[ "$@" =~ "proton"* ]]; then
	if [[ "$@" =~ "lto"* ]]; then
		export COMPILER="ProtonClang-13.0 LTO"
	else
		export COMPILER="ProtonClang-13.0
fi
else
	export COMPILER="ProtonClang-12.0"

#
# Enviromental Variables
#

# Set the current branch name
BRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)

# Set the last commit sha
COMMIT=$(git rev-parse --short HEAD)

# Set current date
DATE=$(date +"%d.%m.%y")

# Set Kernel Version
KERNELVER=$(make kernelversion)

# Set our directory
OUT_DIR=out/

CSUM=$(cksum <<<${COMMIT} | cut -f 1 -d ' ')

# Select LTO or non LTO builds
if [[ "$@" =~ "lto"* ]]; then
	VERSION="SPIRA-${TYPE}-LTO${DRONE_BUILD_NUMBER}-${DATE}"
else
	VERSION="SPIRAL-${TYPE}-${DRONE_BUILD_NUMBER}-${DATE}"
fi

# Export Zip name
export ZIPNAME="${VERSION}.zip"

# How much kebabs we need? Kanged from @raphielscape :)
if [[ -z "${KEBABS}" ]]; then
    COUNT="$(grep -c '^processor' /proc/cpuinfo)"
    export KEBABS="$((COUNT * 2))"
fi

START=$(date +"%s")
if [[ "$@" =~ "proton"* ]]; then
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
		-e LTO \
		-e LTO_CLANG \
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
		AR="llvm-ar" \
		NM="llvm-nm" \
		LD="ld.lld" \
		STRIP="llvm-strip" \
		OBJCOPY="llvm-objcopy" \
		OBJDUMP="llvm-objdump" \
		OBJSIZE="llvm-size" \
		READELF="llvm-readelf" \
		HOSTCC="clang" \
		HOSTCXX="clang++" \
		HOSTAR="llvm-ar" \
		HOSTLD="ld.lld" \
		CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
		CROSS_COMPILE="aarch64-linux-gnu-" \
		-j${KEBABS}
fi

# Post to CI channel
function tg_post_msg() {
    # curl -s -X POST https://api.telegram.org/bot"${BOT_API_KEY}"/sendAnimation -d animation="https://media.giphy.com/media/PPgZCwZPKrLcw75EG1/giphy.gif" -d chat_id="${CI_CHANNEL_ID}"
    curl -s -X POST https://api.telegram.org/bot"${BOT_API_KEY}"/sendMessage -d text=SPIRAL
<b>BUILD TYPE</b> : <code>${TYPE}</code>
<b>DEVICE</b> : <code>${DEVICE}</code>
<b>COMPILER</b> : <code>${COMPILER}</code>
<b>KERNEL VERSION</b> : <code>${KERNELVER}</code>

<i>Build started on Drone Cloud!</i>
<a href='https://cloud.drone.io/UtsavBalar1231/kernel_xiaomi_sm8250/${DRONE_BUILD_NUMBER}'>Check the build status here</a>" -d chat_id="${CI_CHANNEL_ID}" -d parse_mode=HTML
}

function tg_post_error() {
    curl -s -X POST https://api.telegram.org/bot"${BOT_API_KEY}"/sendMessage -d text="Error in ${DEVICE}: $1 build!!" -d chat_id="${CI_CHANNEL_ID}"
    curl -F chat_id="${CI_CHANNEL_ID}" -F document=@"$(pwd)/build.log" https://api.telegram.org/bot"${BOT_API_KEY}"/sendDocument
    exit 1
}

END=$(date +"%s")
DIFF=$((END - START))

cd anykernel || exit
zip -r9 "${ZIPNAME}" ./* -x .git .gitignore ./*.zip

RESPONSE=$(curl -# -F "name=${ZIPNAME}" -F "file=@${ZIPNAME}" -u :"${PD_API_KEY}" https://pixeldrain.com/api/file)
FILEID=$(echo "${RESPONSE}" | grep -Po '(?<="id":")[^"]*')

CHECKER=$(find ./ -maxdepth 1 -type f -name "${ZIPNAME}" -printf "%s\n")
if (($((CHECKER / 1048576)) > 5)); then
    curl -s -X POST https://api.telegram.org/bot"${BOT_API_KEY}"/sendMessage -d text="✅ Kernel compiled successfully in $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds for ${DEVICE}" -d chat_id="${CI_CHANNEL_ID}" -d parse_mode=HTML
    curl -s -X POST https://api.telegram.org/bot"${BOT_API_KEY}"/sendMessage -d text="Kernel build link: https://pixeldrain.com/u/$FILEID" -d chat_id="${CI_CHANNEL_ID}" -d parse_mode=HTML
    #    curl -F chat_id="${CI_CHANNEL_ID}" -F document=@"$(pwd)/${ZIPNAME}" https://api.telegram.org/bot"${BOT_API_KEY}"/sendDocument
else
    tg_post_error
fi
cd "$(pwd)" || exit

# Cleanup
rm -fr anykernel/
