
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

cd /drone/src/libufdt-master-utils/src


python mkdtboimg.py create /drone/src/out/arch/arm64/boot/dtbo.img /drone/src/out/arch/arm64/boot/dts/qcom/*.dtbo

cd ..
cd ..
pwd
cd $(pwd)/${OUT_DIR}/arch/arm64/boot/

curl --upload-file dtbo.img https://transfer.sh/dtbo.img



