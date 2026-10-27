#!/bin/bash
#
# SPDX-FileCopyrightText: 2016 The CyanogenMod Project
# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=mt6765-common
VENDOR=samsung

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

# If XML files don't have comments before the XML header, use this flag
# Can still be used with broken XML files by using blob_fixup
export TARGET_DISABLE_XML_FIXING=true

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_FIRMWARE=
KANG=
SECTION=
CARRIER_SKIP_FILES=()

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-firmware)
            ONLY_FIRMWARE=true
            ;;
        -n | --no-cleanup)
            CLEAN_VENDOR=false
            ;;
        -k | --kang)
            KANG="--kang"
            ;;
        -s | --section)
            SECTION="${2}"
            shift
            CLEAN_VENDOR=false
            ;;
        *)
            SRC="${1}"
            ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        # replace_needed libcrypto.so -> libcrypto-v33.so
        vendor/lib64/libkeymaster_helper.so | vendor/lib64/libskeymaster4device.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libcrypto.so" "libcrypto-v33.so" "${2}"
            ;;

        # replace_needed libutils.so -> libutils-v32.so (MediaTek PQ)
        vendor/lib/hw/vendor.mediatek.hardware.pq@2.11-impl.so | \
        vendor/lib64/hw/vendor.mediatek.hardware.pq@2.11-impl.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v32.so" "${2}"
            ;;

        # camerahalserver: replace and add multiple
        vendor/bin/hw/camerahalserver)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libbinder.so" "libbinder-v32.so" "${2}"
            "${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${2}"
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v32.so" "${2}"
            "${PATCHELF}" --add-needed "libhidlbase_shim.so" "${2}"
            ;;

        # camera provider mediatek: replace and add
        vendor/lib64/hw/android.hardware.camera.provider@2.6-impl-mediatek.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${2}"
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v32.so" "${2}"
            "${PATCHELF}" --add-needed "libhidlbase_shim.so" "${2}"
            ;;

        # media.c2 mediatek: add and replace
        vendor/bin/hw/android.hardware.media.c2@1.2-mediatek | \
        vendor/bin/hw/android.hardware.media.c2@1.2-mediatek-64b)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libstagefright_foundation-v33.so" "${2}"
            "${PATCHELF}" --replace-needed "libavservices_minijail_vendor.so" "libavservices_minijail.so" "${2}"
            ;;

        # mnld and sensorprovider: replace needed
        vendor/bin/mnld | vendor/lib64/libcam.utils.sensorprovider.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libsensorndkbridge.so" "android.hardware.sensors@1.0-convert-shared.so" "${2}"
            ;;

        # SoundAlive: add libc++
        vendor/lib/lib_SoundAlive_3DPosition_ver202.so | \
        vendor/lib64/lib_SoundAlive_3DPosition_ver202.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libc++.so" "${2}"
            ;;

        # wvkprov, lib3a, libSQLite: add liblog
        vendor/bin/wvkprov | vendor/lib64/lib3a.flash.so | vendor/lib64/libSQLiteModule_VER_ALL.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "liblog.so" "${2}"
            ;;

        # libmnl: add libcutils
        vendor/lib64/libmnl.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libcutils.so" "${2}"
            ;;

        # nvram/sysenv: add libbase_shim
        vendor/lib/libnvram.so | vendor/lib/libsysenv.so | \
        vendor/lib64/libnvram.so | vendor/lib64/libsysenv.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libbase_shim.so" "${2}"
            ;;

        # ARM32 clear symbol versions (legacy libs)
        vendor/lib/libthha.so | vendor/lib/libvcodec_oal.so | \
        vendor/lib/libmp4enc_sa.ca7.so | vendor/lib/libvp8dec_sa.ca7.so | \
        vendor/lib/libvp9dec_sa.ca7.so | vendor/lib/libh264enc_sa.ca7.so | \
        vendor/lib/libvc1dec_sa.ca7.so | vendor/lib/libmp4enc_xa.ca7.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --clear-symbol-version "__aeabi_memclr" "${2}"
            "${PATCHELF}" --clear-symbol-version "__aeabi_memclr4" "${2}"
            "${PATCHELF}" --clear-symbol-version "__aeabi_memcpy" "${2}"
            "${PATCHELF}" --clear-symbol-version "__aeabi_memcpy4" "${2}"
            "${PATCHELF}" --clear-symbol-version "__aeabi_memmove" "${2}"
            "${PATCHELF}" --clear-symbol-version "__aeabi_memset" "${2}"
            "${PATCHELF}" --clear-symbol-version "__gnu_Unwind_Find_exidx" "${2}"
            ;;

        # Vulkan MT6765: clear AHardwareBuffer symbols
        vendor/lib/hw/vulkan.mt6765.so | vendor/lib64/hw/vulkan.mt6765.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --clear-symbol-version "AHardwareBuffer_acquire" "${2}"
            "${PATCHELF}" --clear-symbol-version "AHardwareBuffer_allocate" "${2}"
            "${PATCHELF}" --clear-symbol-version "AHardwareBuffer_createFromHandle" "${2}"
            "${PATCHELF}" --clear-symbol-version "AHardwareBuffer_describe" "${2}"
            "${PATCHELF}" --clear-symbol-version "AHardwareBuffer_getNativeHandle" "${2}"
            "${PATCHELF}" --clear-symbol-version "AHardwareBuffer_release" "${2}"
            ;;

        *)
            return 1
            ;;
    esac

    return 0
}

# Handle libuuid vendor suffix
LIB_FIXUPS="libuuid"

function blob_fixup_dry() {
    blob_fixup "$1" ""
}

function prepare_firmware() {
    if [ "${SRC}" != "adb" ]; then
        local STAR="${ANDROID_ROOT}"/lineage/scripts/motorola/star.sh
        for IMAGE in bootloader radio; do
            if [ -f "${SRC}/${IMAGE}.img" ]; then
                echo "Extracting Motorola star image ${SRC}/${IMAGE}.img"
                sh "${STAR}" "${SRC}/${IMAGE}.img" "${SRC}"
            fi
        done
    fi
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

if [ -z "${ONLY_FIRMWARE}" ]; then
    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

    generate_prop_list_from_image "product.img" "${MY_DIR}/proprietary-files-carriersettings.txt" CARRIER_SKIP_FILES carriersettings
    extract "${MY_DIR}/proprietary-files-carriersettings.txt" "${SRC}" "${KANG}" --section "${SECTION}"

    extract_carriersettings
fi

if [ -z "${SECTION}" ]; then
    extract_firmware "${MY_DIR}/proprietary-firmware.txt" "${SRC}"
fi

"${MY_DIR}/setup-makefiles.sh"
