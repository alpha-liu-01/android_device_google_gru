/*
 * Copyright (C) 2020 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#define LOG_TAG "GoogleIIOSensorSubHal"

#include "Sensor.h"
#include <hardware/sensors.h>
#include <log/log.h>
#include <utils/SystemClock.h>
#include <cmath>

namespace android {
namespace hardware {
namespace sensors {
namespace V2_1 {
namespace subhal {
namespace implementation {

using ::android::hardware::sensors::V1_0::AdditionalInfoType;
using ::android::hardware::sensors::V1_0::MetaDataEventType;
using ::android::hardware::sensors::V1_0::SensorFlagBits;
using ::android::hardware::sensors::V1_0::SensorStatus;
using ::sensor::hal::configuration::V1_0::Location;
using ::sensor::hal::configuration::V1_0::Orientation;

SensorBase::SensorBase(int32_t sensorHandle, ISensorsEventCallback* callback, SensorType type)
    : mIsEnabled(false),
      mSamplingPeriodNs(0),
      mCallback(callback),
      mMode(OperationMode::NORMAL),
      mSensorThread(this) {
    mSensorInfo.type = type;
    mSensorInfo.sensorHandle = sensorHandle;
    mSensorInfo.vendor = "Google";
    mSensorInfo.version = 1;
    mSensorInfo.fifoReservedEventCount = 0;
    mSensorInfo.fifoMaxEventCount = 0;
    mSensorInfo.requiredPermission = "";
    mSensorInfo.flags = 0;

    switch (type) {
        case SensorType::ACCELEROMETER:
            mSensorInfo.typeAsString = SENSOR_STRING_TYPE_ACCELEROMETER;
            break;
        case SensorType::GYROSCOPE:
            mSensorInfo.typeAsString = SENSOR_STRING_TYPE_GYROSCOPE;
            break;
        default:
            ALOGE("unsupported sensor type %d", type);
            break;
    }

    mSensorThread.start();
}

SensorBase::~SensorBase() {
    mIsEnabled = false;
}

bool SensorBase::isEnabled() const {
    return mIsEnabled;
}

OperationMode SensorBase::getOperationMode() const {
    return mMode;
}

HWSensorBase::~HWSensorBase() {
    close(mPollFdIio.fd);
}

const SensorInfo& SensorBase::getSensorInfo() const {
    return mSensorInfo;
}

void HWSensorBase::batch(int32_t samplingPeriodNs) {
    if (mSensorInfo.minDelay > 0 && mSensorInfo.maxDelay > 0 && mSensorInfo.maxDelay >= mSensorInfo.minDelay) {
        samplingPeriodNs =
                std::clamp(samplingPeriodNs, static_cast<int32_t>(mSensorInfo.minDelay * 1000),
                           static_cast<int32_t>(mSensorInfo.maxDelay * 1000));
    }
    if (mSamplingPeriodNs != samplingPeriodNs) {
        mSamplingPeriodNs = samplingPeriodNs;
        double sampling_frequency = static_cast<double>(ns_to_frequency(samplingPeriodNs));
        if (sampling_frequency < 20.0) {
            sampling_frequency = 20.0;
        }
        if (sampling_frequency > 200.0) {
            sampling_frequency = 200.0;
        }
        set_sampling_frequency(mIioData.sysfspath, sampling_frequency);
        // Wake up the 'run' thread to check if a new event should be generated now
        mSensorThread.notifyAll();
    }
}

void HWSensorBase::sendAdditionalInfoReport() {
    std::vector<Event> events;

    for (const auto& frame : mAdditionalInfoFrames) {
        events.emplace_back(Event{
                .sensorHandle = mSensorInfo.sensorHandle,
                .sensorType = SensorType::ADDITIONAL_INFO,
                .timestamp = android::elapsedRealtimeNano(),
                .u.additional = frame,
        });
    }

    if (!events.empty()) {
        mCallback->postEvents(events, mCallback->createScopedWakelock(isWakeUpSensor()));
    }
}

void HWSensorBase::activate(bool enable) {
    std::unique_lock<std::mutex> lock(mSensorThread.lock());
    if (mIsEnabled != enable) {
        mIsEnabled = enable;
        enable_sensor(mIioData.sysfspath, enable);
        if (enable) sendAdditionalInfoReport();
        mSensorThread.notifyAll();
    }
}

Result SensorBase::flush() {
    // Only generate a flush complete event if the sensor is enabled and if the sensor is not a
    // one-shot sensor.
    if (!mIsEnabled || (mSensorInfo.flags & static_cast<uint32_t>(SensorFlagBits::ONE_SHOT_MODE))) {
        return Result::BAD_VALUE;
    }

    // Note: If a sensor supports batching, write all of the currently batched events for the sensor
    // to the Event FMQ prior to writing the flush complete event.
    Event ev;
    ev.sensorHandle = mSensorInfo.sensorHandle;
    ev.sensorType = SensorType::META_DATA;
    ev.u.meta.what = MetaDataEventType::META_DATA_FLUSH_COMPLETE;
    std::vector<Event> evs{ev};
    mCallback->postEvents(evs, mCallback->createScopedWakelock(isWakeUpSensor()));
    return Result::OK;
}

Result HWSensorBase::flush() {
    Result result = Result::OK;
    result = SensorBase::flush();
    if (result == Result::OK) sendAdditionalInfoReport();
    return result;
}

template <size_t N>
static float getChannelData(const std::array<float, N>& channelData, int64_t map, bool negate) {
    return negate ? -channelData[map] : channelData[map];
}

void HWSensorBase::processScanData(uint8_t* data, Event* evt) {
    std::array<float, NUM_OF_DATA_CHANNELS> channelData = {0.0f, 0.0f, 0.0f};
    evt->sensorHandle = mSensorInfo.sensorHandle;
    evt->sensorType = mSensorInfo.type;

    size_t offset = 0;
    for (auto i = 0u; i < mIioData.channelInfo.size(); i++) {
        size_t storageBytes = mIioData.channelInfo[i].storage_bytes;
        if (storageBytes > 1) {
            offset = (offset + storageBytes - 1) & ~(storageBytes - 1);
        }
        unsigned int chanIdx = mIioData.channelInfo[i].index;

        if (chanIdx == mIioData.channelInfo.size() - 1) {
            int64_t ts = 0;
            memcpy(&ts, data + offset, sizeof(ts));
            evt->timestamp = ts;
        } else if (chanIdx < NUM_OF_DATA_CHANNELS) {
            float val = 0.0f;
            if (storageBytes == 2) {
                int16_t s16 = 0;
                memcpy(&s16, data + offset, sizeof(s16));
                val = static_cast<float>(s16);
            } else if (storageBytes == 4) {
                int32_t s32 = 0;
                memcpy(&s32, data + offset, sizeof(s32));
                val = static_cast<float>(s32);
            } else if (storageBytes == 8) {
                int64_t s64 = 0;
                memcpy(&s64, data + offset, sizeof(s64));
                val = static_cast<float>(s64);
            } else {
                int8_t s8 = 0;
                memcpy(&s8, data + offset, sizeof(s8));
                val = static_cast<float>(s8);
            }
            channelData[chanIdx] = val * mIioData.scale;
        }
        offset += storageBytes;
    }

    evt->u.vec3.x = getChannelData(channelData, mXMap, mXNegate);
    evt->u.vec3.y = getChannelData(channelData, mYMap, mYNegate);
    evt->u.vec3.z = getChannelData(channelData, mZMap, mZNegate);
    evt->u.vec3.status = SensorStatus::ACCURACY_HIGH;
}

void HWSensorBase::pollForEvents() {
    int timeoutMs = mSamplingPeriodNs > 0 ? static_cast<int>(mSamplingPeriodNs / 1000000) : 40;
    if (timeoutMs < 20) timeoutMs = 20;
    if (timeoutMs > 100) timeoutMs = 100;
    int err = poll(&mPollFdIio, 1, timeoutMs);
    if (err <= 0) {
        return;
    }

    if (mPollFdIio.revents & POLLIN) {
        std::vector<Event> events;
        while (true) {
            int read_size = read(mPollFdIio.fd, &mSensorRawData[0], mScanSize);
            if (read_size <= 0) {
                break;
            }
            Event evt;
            processScanData(&mSensorRawData[0], &evt);
            events.push_back(evt);
            if (events.size() >= 32) {
                break;
            }
        }
        if (!events.empty()) {
            mCallback->postEvents(events, mCallback->createScopedWakelock(isWakeUpSensor()));
        }
    }
}

void HWSensorBase::idleLoop() {
    mSensorThread.wait([this] {
        return ((mIsEnabled && mMode == OperationMode::NORMAL) || mSensorThread.isStopped());
    });
}

void HWSensorBase::pollSensor() {
    if (!mIsEnabled || mMode == OperationMode::DATA_INJECTION) {
        idleLoop();
    } else {
        pollForEvents();
    }
}

bool SensorBase::isWakeUpSensor() {
    return mSensorInfo.flags & static_cast<uint32_t>(SensorFlagBits::WAKE_UP);
}

void SensorBase::setOperationMode(OperationMode mode) {
    std::unique_lock<std::mutex> lock(mSensorThread.lock());
    if (mMode != mode) {
        mMode = mode;
        mSensorThread.notifyAll();
    }
}

bool SensorBase::supportsDataInjection() const {
    return mSensorInfo.flags & static_cast<uint32_t>(SensorFlagBits::DATA_INJECTION);
}

Result SensorBase::injectEvent(const Event& event) {
    Result result = Result::OK;
    if (event.sensorType == SensorType::ADDITIONAL_INFO) {
        // When in OperationMode::NORMAL, SensorType::ADDITIONAL_INFO is used to push operation
        // environment data into the device.
    } else if (!supportsDataInjection()) {
        result = Result::INVALID_OPERATION;
    } else if (mMode == OperationMode::DATA_INJECTION) {
        mCallback->postEvents({event}, mCallback->createScopedWakelock(isWakeUpSensor()));
    } else {
        result = Result::BAD_VALUE;
    }
    return result;
}

ssize_t HWSensorBase::calculateScanSize() {
    ssize_t numBytes = 0;
    size_t maxAlign = 1;
    for (auto i = 0u; i < mIioData.channelInfo.size(); i++) {
        size_t storageBytes = mIioData.channelInfo[i].storage_bytes;
        if (storageBytes > maxAlign) {
            maxAlign = storageBytes;
        }
        if (storageBytes > 1) {
            numBytes = (numBytes + storageBytes - 1) & ~(storageBytes - 1);
        }
        numBytes += storageBytes;
    }
    if (maxAlign > 1) {
        numBytes = (numBytes + maxAlign - 1) & ~(maxAlign - 1);
    }
    return numBytes;
}

static status_t checkAxis(int64_t map) {
    if (map < 0 || map >= NUM_OF_DATA_CHANNELS)
        return BAD_VALUE;
    else
        return OK;
}

static std::optional<std::vector<Orientation>> getOrientation(
        std::optional<std::vector<Configuration>> config) {
    if (!config) return std::nullopt;
    if (config->empty()) return std::nullopt;
    Configuration& sensorCfg = (*config)[0];
    return sensorCfg.getOrientation();
}

static std::optional<std::vector<Location>> getLocation(
        std::optional<std::vector<Configuration>> config) {
    if (!config) return std::nullopt;
    if (config->empty()) return std::nullopt;
    Configuration& sensorCfg = (*config)[0];
    return sensorCfg.getLocation();
}

static status_t checkOrientation(std::optional<std::vector<Configuration>> config) {
    status_t ret = OK;
    std::optional<std::vector<Orientation>> sensorOrientationList = getOrientation(config);
    if (!sensorOrientationList) return OK;
    if (sensorOrientationList->empty()) return OK;
    Orientation& sensorOrientation = (*sensorOrientationList)[0];
    if (!sensorOrientation.getFirstX() || !sensorOrientation.getFirstY() ||
        !sensorOrientation.getFirstZ())
        return BAD_VALUE;

    int64_t xMap = sensorOrientation.getFirstX()->getMap();
    ret = checkAxis(xMap);
    if (ret != OK) return ret;
    int64_t yMap = sensorOrientation.getFirstY()->getMap();
    ret = checkAxis(yMap);
    if (ret != OK) return ret;
    int64_t zMap = sensorOrientation.getFirstZ()->getMap();
    ret = checkAxis(zMap);
    if (ret != OK) return ret;
    if (xMap == yMap || yMap == zMap || zMap == xMap) return BAD_VALUE;
    return ret;
}

void HWSensorBase::setAxisDefaultValues() {
    mXMap = 0;
    mYMap = 1;
    mZMap = 2;
    mXNegate = mYNegate = mZNegate = false;
}
void HWSensorBase::setOrientation(std::optional<std::vector<Configuration>> config) {
    std::optional<std::vector<Orientation>> sensorOrientationList = getOrientation(config);

    if (sensorOrientationList && !sensorOrientationList->empty()) {
        Orientation& sensorOrientation = (*sensorOrientationList)[0];

        if (sensorOrientation.getRotate()) {
            mXMap = sensorOrientation.getFirstX()->getMap();
            mXNegate = sensorOrientation.getFirstX()->getNegate();
            mYMap = sensorOrientation.getFirstY()->getMap();
            mYNegate = sensorOrientation.getFirstY()->getNegate();
            mZMap = sensorOrientation.getFirstZ()->getMap();
            mZNegate = sensorOrientation.getFirstZ()->getNegate();
        } else {
            setAxisDefaultValues();
        }
    } else {
        setAxisDefaultValues();
    }
}

static status_t checkIIOData(const struct iio_device_data& iio_data) {
    status_t ret = OK;
    for (auto i = 0u; i < iio_data.channelInfo.size(); i++) {
        if (iio_data.channelInfo[i].index > NUM_OF_DATA_CHANNELS) return BAD_VALUE;
    }
    return ret;
}

static status_t setSensorPlacementData(AdditionalInfo* sensorPlacement, int index, float value) {
    if (!sensorPlacement) return BAD_VALUE;

    int arraySize =
            sizeof(sensorPlacement->u.data_float) / sizeof(sensorPlacement->u.data_float[0]);
    if (index < 0 || index >= arraySize) return BAD_VALUE;

    sensorPlacement->u.data_float[index] = value;
    return OK;
}

status_t HWSensorBase::getSensorPlacement(AdditionalInfo* sensorPlacement,
                                          const std::optional<std::vector<Configuration>>& config) {
    if (!sensorPlacement) return BAD_VALUE;

    auto sensorLocationList = getLocation(config);
    if (!sensorLocationList) return BAD_VALUE;
    if (sensorLocationList->empty()) return BAD_VALUE;

    auto sensorOrientationList = getOrientation(config);
    if (!sensorOrientationList) return BAD_VALUE;
    if (sensorOrientationList->empty()) return BAD_VALUE;

    sensorPlacement->type = AdditionalInfoType::AINFO_SENSOR_PLACEMENT;
    sensorPlacement->serial = 0;
    memset(&sensorPlacement->u.data_float, 0, sizeof(sensorPlacement->u.data_float));

    Location& sensorLocation = (*sensorLocationList)[0];
    // SensorPlacementData is given as a 3x4 matrix consisting of a 3x3 rotation matrix (R)
    // concatenated with a 3x1 location vector (t) in row major order. Example: This raw buffer:
    // {x1,y1,z1,l1,x2,y2,z2,l2,x3,y3,z3,l3} corresponds to the following 3x4 matrix:
    //  x1 y1 z1 l1
    //  x2 y2 z2 l2
    //  x3 y3 z3 l3
    // LOCATION_X_IDX,LOCATION_Y_IDX,LOCATION_Z_IDX corresponds to the indexes of the location
    // vector (l1,l2,l3) in the raw buffer.
    status_t ret = setSensorPlacementData(sensorPlacement, HWSensorBase::LOCATION_X_IDX,
                                          sensorLocation.getX());
    if (ret != OK) return ret;
    ret = setSensorPlacementData(sensorPlacement, HWSensorBase::LOCATION_Y_IDX,
                                 sensorLocation.getY());
    if (ret != OK) return ret;
    ret = setSensorPlacementData(sensorPlacement, HWSensorBase::LOCATION_Z_IDX,
                                 sensorLocation.getZ());
    if (ret != OK) return ret;

    Orientation& sensorOrientation = (*sensorOrientationList)[0];
    if (sensorOrientation.getRotate()) {
        // If the HAL is already rotating the sensor orientation to align with the Android
        // Coordinate system, then the sensor rotation matrix will be an identity matrix
        // ROTATION_X_IDX, ROTATION_Y_IDX, ROTATION_Z_IDX corresponds to indexes of the
        // (x1,y1,z1) in the raw buffer.
        ret = setSensorPlacementData(sensorPlacement, HWSensorBase::ROTATION_X_IDX + 0, 1);
        if (ret != OK) return ret;
        ret = setSensorPlacementData(sensorPlacement, HWSensorBase::ROTATION_Y_IDX + 4, 1);
        if (ret != OK) return ret;
        ret = setSensorPlacementData(sensorPlacement, HWSensorBase::ROTATION_Z_IDX + 8, 1);
        if (ret != OK) return ret;
    } else {
        ret = setSensorPlacementData(
                sensorPlacement,
                HWSensorBase::ROTATION_X_IDX + 4 * sensorOrientation.getFirstX()->getMap(),
                sensorOrientation.getFirstX()->getNegate() ? -1 : 1);
        if (ret != OK) return ret;
        ret = setSensorPlacementData(
                sensorPlacement,
                HWSensorBase::ROTATION_Y_IDX + 4 * sensorOrientation.getFirstY()->getMap(),
                sensorOrientation.getFirstY()->getNegate() ? -1 : 1);
        if (ret != OK) return ret;
        ret = setSensorPlacementData(
                sensorPlacement,
                HWSensorBase::ROTATION_Z_IDX + 4 * sensorOrientation.getFirstZ()->getMap(),
                sensorOrientation.getFirstZ()->getNegate() ? -1 : 1);
        if (ret != OK) return ret;
    }
    return OK;
}

status_t HWSensorBase::setAdditionalInfoFrames(
        const std::optional<std::vector<Configuration>>& config) {
    AdditionalInfo additionalInfoSensorPlacement;
    status_t ret = getSensorPlacement(&additionalInfoSensorPlacement, config);
    if (ret != OK) return ret;

    const AdditionalInfo additionalInfoBegin = {
            .type = AdditionalInfoType::AINFO_BEGIN,
            .serial = 0,
    };
    const AdditionalInfo additionalInfoEnd = {
            .type = AdditionalInfoType::AINFO_END,
            .serial = 0,
    };

    mAdditionalInfoFrames.insert(
            mAdditionalInfoFrames.end(),
            {additionalInfoBegin, additionalInfoSensorPlacement, additionalInfoEnd});
    return OK;
}

HWSensorBase* HWSensorBase::buildSensor(int32_t sensorHandle, ISensorsEventCallback* callback,
                                        const struct iio_device_data& iio_data,
                                        const std::optional<std::vector<Configuration>>& config) {
    if (checkOrientation(config) != OK) {
        ALOGE("Orientation of the sensor %s in the configuration file is invalid",
              iio_data.name.c_str());
        return nullptr;
    }
    if (checkIIOData(iio_data) != OK) {
        ALOGE("IIO channel index of the sensor %s  is invalid", iio_data.name.c_str());
        return nullptr;
    }
    return new HWSensorBase(sensorHandle, callback, iio_data, config);
}

HWSensorBase::HWSensorBase(int32_t sensorHandle, ISensorsEventCallback* callback,
                           const struct iio_device_data& data,
                           const std::optional<std::vector<Configuration>>& config)
    : SensorBase(sensorHandle, callback, data.type) {
    std::string buffer_path;
    mSensorInfo.flags |= SensorFlagBits::CONTINUOUS_MODE;
    mSensorInfo.name = data.name;
    mSensorInfo.resolution = data.resolution * data.scale;
    mSensorInfo.maxRange = data.max_range * data.scale;
    mSensorInfo.power = 0;
    mIioData = data;
    setOrientation(config);
    status_t ret = setAdditionalInfoFrames(config);
    if (ret == OK) mSensorInfo.flags |= SensorFlagBits::ADDITIONAL_INFO;
    unsigned int max_sampling_frequency = 0;
    unsigned int min_sampling_frequency = UINT_MAX;
    for (auto i = 0u; i < data.sampling_freq_avl.size(); i++) {
        if (data.sampling_freq_avl[i] > 0.0) {
            if (max_sampling_frequency < data.sampling_freq_avl[i])
                max_sampling_frequency = data.sampling_freq_avl[i];
            if (min_sampling_frequency > data.sampling_freq_avl[i])
                min_sampling_frequency = data.sampling_freq_avl[i];
        }
    }
    if (min_sampling_frequency == UINT_MAX || min_sampling_frequency == 0) {
        min_sampling_frequency = 1;
    }
    if (max_sampling_frequency == 0) {
        max_sampling_frequency = 200;
    }
    mSensorInfo.minDelay = frequency_to_us(max_sampling_frequency);
    mSensorInfo.maxDelay = frequency_to_us(min_sampling_frequency);
    mScanSize = calculateScanSize();
    buffer_path = "/dev/iio:device";
    buffer_path.append(std::to_string(mIioData.iio_dev_num));
    mPollFdIio.fd = open(buffer_path.c_str(), O_RDONLY | O_NONBLOCK);
    if (mPollFdIio.fd < 0) {
        ALOGE("%s: Failed to open iio char device (%s).", data.name.c_str(), buffer_path.c_str());
        return;
    }
    mPollFdIio.events = POLLIN;
    mSensorRawData.resize(mScanSize);
}

}  // namespace implementation
}  // namespace subhal
}  // namespace V2_1
}  // namespace sensors
}  // namespace hardware
}  // namespace android
