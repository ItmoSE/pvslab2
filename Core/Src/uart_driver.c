#include "uart_driver.h"
#include "main.h"
#include "ring_buffer.h"
#include "stm32f746xx.h"
#include "stm32f7xx_hal_cortex.h"
#include "stm32f7xx_hal_uart.h"
#include "usart.h"

#define UART_RX_CAPACITY 128
#define UART_TX_CAPACITY 256

static uart_mode_t current_mode = UART_MODE_POLLING;

static uint8_t rx_storage[UART_RX_CAPACITY + 1];
static uint8_t tx_storage[UART_TX_CAPACITY + 1];

static ring_buffer_t rx_buffer;
static ring_buffer_t tx_buffer;

static uint8_t rx_byte;
static uint8_t tx_byte;

static bool tx_busy = false;

static volatile uint32_t rx_overflows;
static volatile uint32_t rx_errors;
static volatile uint32_t tx_start_errors;

static uint32_t irq_lock(void) {
  uint32_t primask = __get_PRIMASK();
  __disable_irq();
  return primask;
}

static void irq_unlock(uint32_t primask) { __set_PRIMASK(primask); }

static void uart_tx_kick(void) {
  if (tx_busy) {
    return;
  }

  if (!rb_peek(&tx_buffer, &tx_byte)) {
    return;
  }

  if (HAL_UART_Transmit_IT(&huart1, &tx_byte, 1) == HAL_OK) {
    rb_pop(&tx_buffer, &tx_byte);
    tx_busy = true;
  } else {
    tx_start_errors++;
  }
}

void uart_init(void) {
  HAL_NVIC_DisableIRQ(USART1_IRQn);
  HAL_NVIC_ClearPendingIRQ(USART1_IRQn);

  rb_init(&rx_buffer, rx_storage, sizeof(rx_storage));
  rb_init(&tx_buffer, tx_storage, sizeof(tx_storage));

  tx_busy = false;

  current_mode = UART_MODE_POLLING;
}

HAL_StatusTypeDef uart_read_byte(uint8_t *byte) {
  uint32_t primask = irq_lock();

  bool success = rb_pop(&rx_buffer, byte);

  irq_unlock(primask);

  if (success)
    return HAL_OK;

  if (current_mode == UART_MODE_POLLING)
    return HAL_UART_Receive(&huart1, byte, 1, 0);

  return HAL_TIMEOUT;
}

HAL_StatusTypeDef uart_write_byte(uint8_t byte) {
  if (current_mode == UART_MODE_POLLING)
    return HAL_UART_Transmit(&huart1, &byte, 1, 10);

  uint32_t primask = irq_lock();

  bool success = rb_push(&tx_buffer, byte);

  uart_tx_kick();

  irq_unlock(primask);

  return success ? HAL_OK : HAL_BUSY;
}

void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart) {
  if (huart != &huart1)
    return;

  if (!rb_push(&rx_buffer, rx_byte))
    rx_overflows++;

  if (huart->ErrorCode == HAL_UART_ERROR_NONE) {
    if (HAL_UART_Receive_IT(&huart1, &rx_byte, 1) != HAL_OK) {
      rx_errors++;
    }
  }
}

void HAL_UART_TxCpltCallback(UART_HandleTypeDef *huart) {
  if (huart != &huart1)
    return;

  tx_busy = false;

  uart_tx_kick();
}

void HAL_UART_ErrorCallback(UART_HandleTypeDef *huart) {
  if (huart != &huart1)
    return;

  rx_errors++;

  if (huart->RxState == HAL_UART_STATE_READY) {
    if (HAL_UART_Receive_IT(&huart1, &rx_byte, 1) != HAL_OK) {
      rx_errors++;
    }
  }
}

HAL_StatusTypeDef uart_set_mode(uart_mode_t mode) {
  if (mode != UART_MODE_POLLING && mode != UART_MODE_INTERRUPT) {
    return HAL_ERROR;
  }

  uint32_t primask = irq_lock();

  if (mode == current_mode) {
    irq_unlock(primask);
    return HAL_OK;
  }

  HAL_StatusTypeDef status;

  if (mode == UART_MODE_POLLING) {
    if (tx_busy || !rb_empty(&tx_buffer)) {
      uart_tx_kick();

      irq_unlock(primask);
      return HAL_BUSY;
    }

    status = HAL_UART_AbortReceive(&huart1);

    if (status == HAL_OK) {
      HAL_NVIC_DisableIRQ(USART1_IRQn);
      HAL_NVIC_ClearPendingIRQ(USART1_IRQn);

      current_mode = UART_MODE_POLLING;
    }
  } else {
    HAL_NVIC_ClearPendingIRQ(USART1_IRQn);

    status = HAL_UART_Receive_IT(&huart1, &rx_byte, 1);

    if (status == HAL_OK) {
      current_mode = UART_MODE_INTERRUPT;

      HAL_NVIC_EnableIRQ(USART1_IRQn);
    }
  }

  irq_unlock(primask);

  return status;
}

uart_mode_t uart_get_mode(void) { return current_mode; }
