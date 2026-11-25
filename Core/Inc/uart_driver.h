#ifndef UART_DRIVER_H
#define UART_DRIVER_H

#include "stm32f7xx_hal.h"

void uart_init(void);

HAL_StatusTypeDef uart_read_byte(uint8_t *byte);

HAL_StatusTypeDef uart_write_byte(uint8_t byte);

typedef enum { UART_MODE_POLLING, UART_MODE_INTERRUPT } uart_mode_t;

HAL_StatusTypeDef uart_set_mode(uart_mode_t mode);
uart_mode_t uart_get_mode(void);

#endif
