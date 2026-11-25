#ifndef GPIO_DRIVER_H
#define GPIO_DRIVER_H

#include "stm32f746xx.h" // IWYU pragma: keep
#include <stdbool.h>
#include <stdint.h>

void gpio_write(GPIO_TypeDef *port, uint16_t pins, bool high);
bool gpio_read(GPIO_TypeDef *port, uint16_t pins);
void gpio_toggle(GPIO_TypeDef *port, uint16_t pins);

typedef enum {
  GPIO_MODE_IN = 0u,
  GPIO_MODE_OUT = 1u,
  GPIO_MODE_AF = 2u,
  GPIO_MODE_ANALOG_INPUT = 3u
} gpio_mode_t;

typedef enum {
  GPIO_OUTPUT_PUSH_PULL = 0u,
  GPIO_OUTPUT_OPEN_DRAIN = 1u
} gpio_output_type_t;

typedef enum {
  GPIO_SPEED_LOW = 0u,
  GPIO_SPEED_MEDIUM = 1u,
  GPIO_SPEED_HIGH = 2u,
  GPIO_SPEED_VERY_HIGH = 3u
} gpio_speed_t;

typedef enum {
  GPIO_PULL_NONE = 0u,
  GPIO_PULL_UP = 1u,
  GPIO_PULL_DOWN = 2u
} gpio_pull_t;

typedef struct {
  gpio_mode_t mode;
  gpio_output_type_t output_type;
  gpio_speed_t speed;
  gpio_pull_t pull;
  uint8_t alternate;
  bool initial_high;
} gpio_config_t;

bool gpio_init(GPIO_TypeDef *port, uint16_t pins, const gpio_config_t *config);
uint16_t gpio_read_mask(GPIO_TypeDef *port, uint16_t pins);
void gpio_write_mask(GPIO_TypeDef *port, uint16_t pins, uint16_t values);

typedef struct {
  gpio_mode_t mode;
  gpio_output_type_t output_type;
  gpio_speed_t speed;
  gpio_pull_t pull;
  uint8_t alternate;
  bool output_high;
} gpio_pin_state_t;

bool gpio_get_config(GPIO_TypeDef *port, uint8_t pin, gpio_pin_state_t *result);

#endif
