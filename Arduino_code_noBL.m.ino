#include <Wire.h>
#include "MAX30100.h"

// 采样率和电流配置
#define SAMPLING_RATE       MAX30100_SAMPRATE_100HZ
#define IR_LED_CURRENT      MAX30100_LED_CURR_50MA
#define RED_LED_CURRENT     MAX30100_LED_CURR_27_1MA 
#define PULSE_WIDTH         MAX30100_SPC_PW_1600US_16BITS
#define HIGHRES_MODE        true

MAX30100 sensor;

void setup() {
    Serial.begin(115200);
    if (!sensor.begin()) { for(;;); } // 初始化失败则停止

    sensor.setMode(MAX30100_MODE_SPO2_HR); // 开启双灯模式
    sensor.setLedsCurrent(IR_LED_CURRENT, RED_LED_CURRENT);
    sensor.setLedsPulseWidth(PULSE_WIDTH);
    sensor.setSamplingRate(SAMPLING_RATE);
    sensor.setHighresModeEnabled(HIGHRES_MODE);
}

void loop() {
    uint16_t ir, red;
    sensor.update(); // 刷新传感器数据寄存器

    // 每 40ms 发送一个点，对应 MATLAB 的 fs = 25
    static uint32_t lastTime = 0;
    if (millis() - lastTime >= 40) {
        lastTime = millis();

        if (sensor.getRawValues(&ir, &red)) {
            // 【只发原始值】
            // 只要 ir 超过基础阈值（证明有手指），就只打印这一个数字
            if (ir > 100) {
                Serial.println(ir); 
            }
        }
    }
}