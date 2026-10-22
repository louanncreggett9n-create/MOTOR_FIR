#ifndef __KEY_H
#define __KEY_H

#include "stm32f4xx.h"
#include "delay.h"

#define KEY_ON   1   // 按键按下
#define KEY_OFF  0   // 按键放开

/*---------------------- 按键配置宏 ------------------------*/

#define KEY_PIN           GPIO_Pin_1                // KEY 引脚
#define KEY_PORT          GPIOC                     // KEY GPIO 端口
#define KEY_CLK           RCC_AHB1Periph_GPIOC      // KEY GPIO 端口时钟

/* 1 = PC1 接 3.3 V 时有效；0 = PC1 接 GND 时有效。 */
#define KEY_ACTIVE_LEVEL  1U

/*---------------------- 函数声明 ----------------------------*/

void KEY_Init(void);       // 按键 IO 口初始化函数
uint8_t KEY_Scan(void);    // 按键扫描

#endif // __KEY_H