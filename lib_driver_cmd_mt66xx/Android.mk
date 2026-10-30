LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := lib_driver_cmd_mt66xx
LOCAL_MODULE_TAGS := optional
LOCAL_PROPRIETARY_MODULE := true
LOCAL_MODULE_OWNER := mtk

# Explicitly list the source files
LOCAL_SRC_FILES := \
    mediatek_driver_cmd_nl80211.c \

# Standard libraries
LOCAL_SHARED_LIBRARIES := \
    libc \
    libcutils \
    liblog

# Include paths for wpa_supplicant and libnl
LOCAL_C_INCLUDES := \
    external/wpa_supplicant_8/src \
    external/wpa_supplicant_8/src/common \
    external/wpa_supplicant_8/src/drivers \
    external/wpa_supplicant_8/src/l2_packet \
    external/wpa_supplicant_8/src/utils \
    external/wpa_supplicant_8/src/wps \
    external/wpa_supplicant_8/wpa_supplicant \
    external/libnl/include

# Flags required for MediaTek Wi-Fi
LOCAL_CFLAGS := \
    -DCONFIG_ANDROID_LOG \
    -DCONFIG_MTK_P2P_SIGMA \
    -Wno-unused-parameter \
    -Wno-unused-function

include $(BUILD_STATIC_LIBRARY)