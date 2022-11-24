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

if [[ "$@" =~ "benzoclang"* ]]; then
	export COMPILER="BenzoClang-12.0"
elif [[ "$@" =~ "proton"* ]]; then
	if [[ "$@" =~ "lto"* ]]; then
		export COMPILER="ProtonClang-13.0 LTO"
	else
		export COMPILER="ProtonClang-13.0"
	fi
else
	export COMPILER="ProtonClang-13.0"
fi

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

# Select LTO or non LTO builds
if [[ "$@" =~ "lto"* ]]; then
    VERSION="Spiral-${DEVICE^^}-${TYPE}-LTO-${CSUM}-${DATE}"
else
    VERSION="Spiral-${DEVICE^^}-${TYPE}-${CSUM}-${DATE}"
fi

# Export Zip name
export ZIPNAME="${VERSION}.zip"

# How much kebabs we need? Kanged from @raphielscape :)
if [[ -z "${KEBABS}" ]]; then
    COUNT="$(grep -c '^processor' /proc/cpuinfo)"
    export KEBABS="$((COUNT * 2))"
fi

if [[ "$@" =~ "proton"* ]]; then
    ARGS="ARCH=arm64 \
		O=${OUT_DIR} \
		CC="clang" \
		CLANG_TRIPLE="aarch64-linux-gnu-" \
		CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
		CROSS_COMPILE="aarch64-linux-gnu-" \
		-j${KEBABS}
    "
else
    ARGS="ARCH=arm64 \
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
"


# Post to CI channel
function tg_post_msg() {
    # curl -s -X POST https://api.telegram.org/bot"${BOT_API_KEY}"/sendAnimation -d animation="https://media.giphy.com/media/PPgZCwZPKrLcw75EG1/giphy.gif" -d chat_id="${CI_CHANNEL_ID}"
    curl -s -X POST https://api.telegram.org/bot"${BOT_API_KEY}"/sendMessage -d text="<code>IMMENSITY Automated build</code>
<b>BUILD TYPE</b> : <code>${TYPE}</code>
<b>DEVICE</b> : <code>${DEVICE}</code>
<b>COMPILER</b> : <code>${COMPILER}</code>
<b>KERNEL VERSION</b> : <code>${KERNELVER}</code>

<i>Build started on Drone Cloud!</i>
<a href='https://cloud.drone.io/Rmx1921/kernel_realme_sdm710/${DRONE_BUILD_NUMBER}'>Check the build status here</a>" -d chat_id="${CI_CHANNEL_ID}" -d parse_mode=HTML
}

function tg_post_error() {
    curl -s -X POST https://api.telegram.org/bot"${BOT_API_KEY}"/sendMessage -d text="Error in ${DEVICE}: $1 build!!" -d chat_id="${CI_CHANNEL_ID}"
    curl -F chat_id="${CI_CHANNEL_ID}" -F document=@"$(pwd)/build.log" https://api.telegram.org/bot"${BOT_API_KEY}"/sendDocument
    exit 1
}

function enable_lto() {
    if [ "$1" == "gcc" ]; then
        scripts/config --file ${OUT_DIR}/.config \
            -e LTO_GCC \
            -e LD_DEAD_CODE_DATA_ELIMINATION \
            -d MODVERSIONS
    else
        scripts/config --file ${OUT_DIR}/.config \
            -e LTO_CLANG
    fi

    # Make olddefconfig
    cd ${OUT_DIR} || exit
    make -j${KEBABS} ${ARGS} olddefconfig
    cd ../ || exit
}

function disable_lto() {
    if [ "$1" == "gcc" ]; then
        scripts/config --file ${OUT_DIR}/.config \
            -d LTO_GCC \
            -d LD_DEAD_CODE_DATA_ELIMINATION \
            -e MODVERSIONS
    else
        scripts/config --file ${OUT_DIR}/.config \
            -d LTO_CLANG
    fi
}

function pack_image_build() {
    mkdir -p anykernel/kernels/$1

    # Check if the kernel is built
    if [[ -f ${OUT_DIR}/System.map ]]; then
        if [[ -f ${OUT_DIR}/arch/arm64/boot/Image.gz ]]; then
            cp ${OUT_DIR}/arch/arm64/boot/Image.gz anykernel/kernels/$1
        elif [[ -f ${OUT_DIR}/arch/arm64/boot/Image ]]; then
            cp ${OUT_DIR}/arch/arm64/boot/Image anykernel/kernels/$1
        else
            tg_post_error $1
        fi
    else
        tg_post_error $1
    fi

    cp ${OUT_DIR}/arch/arm64/boot/dtb anykernel/kernels/$1
    cp ${OUT_DIR}/arch/arm64/boot/dtbo.img anykernel/kernels/$1
}

START=$(date +"%s")

tg_post_msg

# Set compiler Path
if [[ "$@" =~ "gcc"* ]]; then
    PATH=${HOME}/gcc64/bin:${HOME}/gcc32/bin:${PATH}
elif [[ "$@" =~ "aosp-clang"* ]]; then
    PATH=${HOME}/gas:${HOME}/clang/bin/:$PATH
    export LD_LIBRARY_PATH=${HOME}/clang/lib64:${LD_LIBRARY_PATH}
else
    PATH=${HOME}/clang/bin/:${PATH}
fi

# Make defconfig
make -j${KEBABS} ${ARGS} "${DEVICE}"_defconfig

# AOSP Build
echo "##### Stating AOSP Build #####"
OS=aosp

if [[ "$@" =~ "lto"* ]]; then
    # Enable LTO
    if [[ "$@" =~ "gcc"* ]]; then
        enable_lto gcc
    else
        enable_lto clang
    fi

    # Make olddefconfig
    cd ${OUT_DIR} || exit
    make -j${KEBABS} ${ARGS} olddefconfig
    cd ../ || exit

fi

make -j${KEBABS} ${ARGS} 2>&1 | tee build.log
find ${OUT_DIR}/$dts_source -name '*.dtb' -exec cat {} + >${OUT_DIR}/arch/arm64/boot/dtb

pack_image_build ${OS}
echo "##### Finishing AOSP Build #####"

# MIUI Build
echo "##### Starting MIUI Build #####"
OS=miui

# Make defconfig
make -j${KEBABS} ${ARGS} "${DEVICE}"_defconfig

scripts/config --file ${OUT_DIR}/.config \
    -d LOCALVERSION_AUTO \
    -d TOUCHSCREEN_COMMON \
    --set-str STATIC_USERMODEHELPER_PATH /system/bin/micd \
    -e IPC_LOGGING \
    -e MI_DRM_OPT \
    -d OSSFOD

if [[ "$@" =~ "lto"* ]]; then
    if [[ "$@" =~ "gcc"* ]]; then
        # Enable GCC LTO
        enable_lto gcc
    fi
fi
# Make olddefconfig
cd ${OUT_DIR} || exit
make -j${KEBABS} ${ARGS} olddefconfig
cd ../ || exit

miui_fix_dimens
miui_fix_fps
miui_fix_dfps
miui_fix_fod

make -j${KEBABS} ${ARGS} 2>&1 | tee build.log

find ${OUT_DIR}/$dts_source -name '*.dtb' -exec cat {} + >${OUT_DIR}/arch/arm64/boot/dtb

pack_image_build ${OS}

git checkout arch/arm64/boot/dts/vendor &>/dev/null
echo "##### Finishing MIUI Build #####"

# AOSPA Build
echo "##### Starting AOSPA Build #####"
OS=aospa

# Make defconfig
make -j${KEBABS} ${ARGS} "${DEVICE}"_defconfig

scripts/config --file ${OUT_DIR}/.config \
    -d SDCARD_FS \
    -e UNICODE

if [[ "$@" =~ "lto"* ]]; then
    # Enable LTO
    if [[ "$@" =~ "gcc"* ]]; then
        enable_lto gcc
    else
        enable_lto clang
    fi
fi

# Make olddefconfig
cd ${OUT_DIR} || exit
make -j${KEBABS} ${ARGS} olddefconfig
cd ../ || exit

make -j${KEBABS} ${ARGS} 2>&1 | tee build.log

find ${OUT_DIR}/$dts_source -name '*.dtb' -exec cat {} + >${OUT_DIR}/arch/arm64/boot/dtb

pack_image_build ${OS}
echo "##### Finishing AOSPA Build #####"

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