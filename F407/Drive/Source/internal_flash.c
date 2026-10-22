#include "internal_flash.h"

static uint8_t image_erased = 0;

static void Flash_ClearAllFlags(void)
{
    FLASH_ClearFlag(FLASH_FLAG_EOP | FLASH_FLAG_OPERR | FLASH_FLAG_WRPERR |
                    FLASH_FLAG_PGAERR | FLASH_FLAG_PGPERR | FLASH_FLAG_PGSERR);
}

void InternalFlash_Init(void)
{
    image_erased = 0;
    FLASH_Unlock();
    FLASH_Lock();
}

void InternalFlash_ResetEraseSession(void)
{
    image_erased = 0;
}

uint8_t InternalFlash_EraseImage(void)
{
    FLASH_Status status;
    if (image_erased) return 1;

    FLASH_Unlock();
    Flash_ClearAllFlags();
    status = FLASH_EraseSector(FLASH_Sector_8, VoltageRange_3);
    FLASH_Lock();

    if (status == FLASH_COMPLETE) {
        image_erased = 1;
        return 1;
    }
    return 0;
}

uint8_t InternalFlash_WriteMapped(uint32_t offset, const uint8_t *data, uint32_t length)
{
    uint32_t address;
    uint32_t i = 0;
    FLASH_Status status = FLASH_COMPLETE;

    if (data == 0 || length == 0) return 0;
    if (offset >= IF_IMAGE_SIZE || length > (IF_IMAGE_SIZE - offset)) return 0;
    if (!InternalFlash_EraseImage()) return 0;

    address = IF_IMAGE_BASE + offset;
    FLASH_Unlock();
    Flash_ClearAllFlags();

    while ((i + 4U) <= length) {
        uint32_t word = (uint32_t)data[i] |
                        ((uint32_t)data[i + 1] << 8) |
                        ((uint32_t)data[i + 2] << 16) |
                        ((uint32_t)data[i + 3] << 24);
        status = FLASH_ProgramWord(address + i, word);
        if (status != FLASH_COMPLETE) break;
        i += 4U;
    }

    while (i < length && status == FLASH_COMPLETE) {
        status = FLASH_ProgramByte(address + i, data[i]);
        i++;
    }

    FLASH_Lock();
    return (status == FLASH_COMPLETE) ? 1 : 0;
}

uint8_t InternalFlash_ReadMapped(uint32_t offset, uint8_t *data, uint32_t length)
{
    const uint8_t *src;
    uint32_t i;
    if (data == 0 || length == 0) return 0;
    if (offset >= IF_IMAGE_SIZE || length > (IF_IMAGE_SIZE - offset)) return 0;

    src = (const uint8_t *)(IF_IMAGE_BASE + offset);
    for (i = 0; i < length; i++) data[i] = src[i];
    return 1;
}

const uint8_t *InternalFlash_Pointer(uint32_t offset)
{
    if (offset >= IF_IMAGE_SIZE) return 0;
    return (const uint8_t *)(IF_IMAGE_BASE + offset);
}
