#ifndef __TPC116S4_H
#define __TPC116S4_H

#include "stm32f4xx.h"
#include <stdint.h>

void TPC116S4_Init(void);
void TPC116S4_WriteChannel(uint8_t channel, uint16_t code);
void TPC116S4_WriteAll(uint16_t code);
void TPC116S4_WriteFrame(uint16_t codeA, uint16_t codeB, uint16_t codeC, uint16_t codeD);

#endif
