#include "tpc116s4.h"

#define TPC_SYNC_PORT      GPIOB
#define TPC_SYNC_PIN       GPIO_Pin_12
#define TPC_SPI            SPI2
#define TPC_SPI_PRESCALER  SPI_BaudRatePrescaler_8

static const uint8_t TPC_Control[4] = {0x08, 0x0A, 0x0C, 0x0E};

static void TPC116S4_SendByte(uint8_t data)
{
    while (SPI_I2S_GetFlagStatus(TPC_SPI, SPI_I2S_FLAG_TXE) == RESET);
    SPI_I2S_SendData(TPC_SPI, data);
}

void TPC116S4_Init(void)
{
    GPIO_InitTypeDef gpio;
    SPI_InitTypeDef spi;

    RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOB, ENABLE);
    RCC_APB1PeriphClockCmd(RCC_APB1Periph_SPI2, ENABLE);

    gpio.GPIO_Mode = GPIO_Mode_OUT;
    gpio.GPIO_OType = GPIO_OType_PP;
    gpio.GPIO_PuPd = GPIO_PuPd_UP;
    gpio.GPIO_Speed = GPIO_Speed_50MHz;
    gpio.GPIO_Pin = TPC_SYNC_PIN;
    GPIO_Init(TPC_SYNC_PORT, &gpio);

    gpio.GPIO_Mode = GPIO_Mode_AF;
    gpio.GPIO_OType = GPIO_OType_PP;
    gpio.GPIO_PuPd = GPIO_PuPd_UP;
    gpio.GPIO_Speed = GPIO_Speed_50MHz;
    gpio.GPIO_Pin = GPIO_Pin_13 | GPIO_Pin_15;
    GPIO_Init(GPIOB, &gpio);
    GPIO_PinAFConfig(GPIOB, GPIO_PinSource13, GPIO_AF_SPI2);
    GPIO_PinAFConfig(GPIOB, GPIO_PinSource15, GPIO_AF_SPI2);

    spi.SPI_Mode = SPI_Mode_Master;
    spi.SPI_Direction = SPI_Direction_1Line_Tx;
    spi.SPI_DataSize = SPI_DataSize_8b;
    spi.SPI_FirstBit = SPI_FirstBit_MSB;
    spi.SPI_BaudRatePrescaler = TPC_SPI_PRESCALER;
    spi.SPI_CPOL = SPI_CPOL_Low;
    spi.SPI_CPHA = SPI_CPHA_2Edge;
    spi.SPI_NSS = SPI_NSS_Soft;
    spi.SPI_CRCPolynomial = 7;
    SPI_Init(TPC_SPI, &spi);
    SPI_Cmd(TPC_SPI, ENABLE);

    GPIO_SetBits(TPC_SYNC_PORT, TPC_SYNC_PIN);
}

void TPC116S4_WriteChannel(uint8_t channel, uint16_t code)
{
    if (channel > 3) return;

    GPIO_ResetBits(TPC_SYNC_PORT, TPC_SYNC_PIN);
    TPC116S4_SendByte(TPC_Control[channel]);
    TPC116S4_SendByte((uint8_t)(code >> 8));
    TPC116S4_SendByte((uint8_t)code);
    while (SPI_I2S_GetFlagStatus(TPC_SPI, SPI_I2S_FLAG_BSY) == SET);
    GPIO_SetBits(TPC_SYNC_PORT, TPC_SYNC_PIN);
}

void TPC116S4_WriteAll(uint16_t code)
{
    uint8_t ch;
    for (ch = 0; ch < 4; ch++) TPC116S4_WriteChannel(ch, code);
}

void TPC116S4_WriteFrame(uint16_t codeA, uint16_t codeB, uint16_t codeC, uint16_t codeD)
{
    TPC116S4_WriteChannel(0, codeA);
    TPC116S4_WriteChannel(1, codeB);
    TPC116S4_WriteChannel(2, codeC);
    TPC116S4_WriteChannel(3, codeD);
}
