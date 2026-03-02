#include <Wire.h>
#include "MAX30100.h"

#define SAMPLING_RATE       MAX30100_SAMPRATE_100HZ
#define IR_LED_CURRENT      MAX30100_LED_CURR_50MA
#define RED_LED_CURRENT     MAX30100_LED_CURR_27_1MA 
#define PULSE_WIDTH         MAX30100_SPC_PW_1600US_16BITS
#define HIGHRES_MODE        true

MAX30100 sensor;
bool sensorAvailable = false;

// 传感器配置函数
void configSensor() {
    sensor.setMode(MAX30100_MODE_SPO2_HR);
    sensor.setLedsCurrent(IR_LED_CURRENT, RED_LED_CURRENT);
    sensor.setLedsPulseWidth(PULSE_WIDTH);
    sensor.setSamplingRate(SAMPLING_RATE);
    sensor.setHighresModeEnabled(HIGHRES_MODE);
}

void setup() {
    Serial.begin(115200);
    Wire.begin();
    Wire.setClock(400000); // 提升 I2C 频率到 400kHz，读取更快

    if (!sensor.begin()) { 
        Serial.println("STATUS: MAX30100 NOT FOUND");
        sensorAvailable = false;
    } else {
        configSensor();
        Serial.println("STATUS: SYSTEM READY");
        sensorAvailable = true;
    }
}

void loop() {
    if (!sensorAvailable) {
        static uint32_t retryTime = 0;
        if (millis() - retryTime > 2000) {
            if (sensor.begin()) {
                configSensor(); // 重新配置
                sensorAvailable = true;
                Serial.println("STATUS: RECONNECTED");
            }
            retryTime = millis();
        }
        return; 
    }

    // 持续调用 update，让传感器把数据存入内部 FIFO
    sensor.update();

    static uint32_t lastTime = 0;
    // 每 40ms 发送一次 (25Hz)
    if (millis() - lastTime >= 40) {
        lastTime = millis();

        uint16_t ir, red;
        if (sensor.getRawValues(&ir, &red)) {
            // 改进 1：基础噪声过滤和手指检测
            // MAX30100 的基值通常在 20000-50000 左右，如果只有 500 说明没按好
            if (ir > 5000) { 
                Serial.println(ir); 
            } else if (ir > 0) {
                // 如果值很小，说明手指接触不充分
                // Serial.println(0); // 可选：通知 MATLAB 手指离开
            }
            
            // 改进 2：溢出检测（防止数据饱和导致波形切顶）
            if (ir > 65000) {
                // 此时波形会变成直线，提示用户按轻点
            }
        }
    }
}