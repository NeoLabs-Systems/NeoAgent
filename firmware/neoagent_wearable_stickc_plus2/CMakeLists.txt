cmake_minimum_required(VERSION 3.16)
set(EXTRA_COMPONENT_DIRS
    "../neoagent_wearable_esp32s3_amoled/components/common"
    "../neoagent_wearable_esp32s3_amoled/components/network"
    "../neoagent_wearable_esp32s3_amoled/components/pairing"
    "../neoagent_wearable_esp32s3_amoled/components/storage"
    "../neoagent_wearable_esp32s3_amoled/components/voice")
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(neoagent_wearable_stickc_plus2)
