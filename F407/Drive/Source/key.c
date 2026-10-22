/***
	*************************************************************************************************
	*	@version V1.0
	*	@author  鹿小班科技
   *************************************************************************************************
   *  @description
	*
	*	实验平台：鹿小班STM32F407VGT6核心板（型号：LXB407VG-P1）
	*	客服微信：19949278543
	*
>>>>> 文件说明：
	*
	*	初始化按键引脚，支持高电平或低电平有效配置。
	*
	************************************************************************************************
***/

#include "key.h"

/*************************************************************************************************
*	函 数 名:	KEY_Init
*
*	函数功能:	按键 IO 口初始化
*
*************************************************************************************************/

void KEY_Init(void)
{
	GPIO_InitTypeDef GPIO_InitStructure; // 定义 GPIO 初始化结构体
	RCC_AHB1PeriphClockCmd(KEY_CLK, ENABLE); // 使能 KEY 时钟

	GPIO_InitStructure.GPIO_Mode  = GPIO_Mode_IN; // 输入模式
	GPIO_InitStructure.GPIO_PuPd  = (KEY_ACTIVE_LEVEL != 0U) ? GPIO_PuPd_DOWN : GPIO_PuPd_UP;
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_2MHz; // 速度选择
	GPIO_InitStructure.GPIO_Pin   = KEY_PIN;

	GPIO_Init(KEY_PORT, &GPIO_InitStructure);
}

/*************************************************************************************************
*	函 数 名:	KEY_Scan
*
*	返 回 值:	KEY_ON - 按键按下，KEY_OFF - 按键放开
*
*	函数功能:	按键扫描与软件消抖
*
*************************************************************************************************/

uint8_t KEY_Scan(void)
{
	static uint8_t key_last = 0U;
	uint8_t key_now;

	key_now = (GPIO_ReadInputDataBit(KEY_PORT, KEY_PIN) == KEY_ACTIVE_LEVEL) ? 1U : 0U;

	if (key_now != 0U && key_last == 0U)
	{
		Delay_ms(10); // 延时消抖
		if (GPIO_ReadInputDataBit(KEY_PORT, KEY_PIN) == KEY_ACTIVE_LEVEL)
		{
			key_last = 1U;
			return KEY_ON;
		}
	}

	key_last = key_now;
	return KEY_OFF;
}