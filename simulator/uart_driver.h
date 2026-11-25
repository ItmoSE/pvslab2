#ifndef UART_DRIVER_H
#define UART_DRIVER_H

#include <stdint.h>

typedef enum { HAL_OK, HAL_ERROR, HAL_BUSY, HAL_TIMEOUT } HAL_StatusTypeDef;

typedef enum { UART_MODE_POLLING, UART_MODE_INTERRUPT } uart_mode_t;

int uart_init(const char *path);

HAL_StatusTypeDef uart_read_byte(uint8_t *byte);
HAL_StatusTypeDef uart_write_byte(uint8_t byte);

HAL_StatusTypeDef uart_set_mode(uart_mode_t mode);
uart_mode_t uart_get_mode(void);

#endif
