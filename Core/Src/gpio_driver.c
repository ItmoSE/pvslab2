#include "gpio_driver.h"
#include <stddef.h>

void gpio_write(GPIO_TypeDef *port, uint16_t pins, bool high) {
  if (high) {
    port->BSRR = (uint32_t)pins;
  } else {
    port->BSRR = (uint32_t)pins << 16u;
  }
}

bool gpio_read(GPIO_TypeDef *port, uint16_t pins) {
  return (port->IDR & pins) != 0u;
}

void gpio_toggle(GPIO_TypeDef *port, uint16_t pins) {

  uint32_t current = port->ODR;
  uint32_t set_mask = (~current) & pins;
  uint32_t reset_mask = current & pins;
  port->BSRR = set_mask | (reset_mask << 16u);
}

static bool gpio_enable_clock(GPIO_TypeDef *port) {
  GPIO_TypeDef *const ports[] = {GPIOA, GPIOB, GPIOC, GPIOD, GPIOE, GPIOF,
                                 GPIOG, GPIOH, GPIOI, GPIOJ, GPIOK};

  for (uint32_t i = 0u; i < 11u; ++i) {
    if (port == ports[i]) {
      RCC->AHB1ENR |= 1u << i;
      (void)RCC->AHB1ENR;
      return true;
    }
  }

  return false;
}

bool gpio_init(GPIO_TypeDef *port, uint16_t pins, const gpio_config_t *config) {
  if (config == NULL || pins == 0u) {
    return false;
  }

  if ((unsigned)config->mode > 3u || (unsigned)config->output_type > 1u ||
      (unsigned)config->speed > 3u || (unsigned)config->pull > 2u ||
      config->alternate > 15u) {
    return false;
  }

  if (!gpio_enable_clock(port)) {
    return false;
  }

  // Не пытаемся изменить аппаратно заблокированные настройки.
  if ((port->LCKR & (1u << 16)) != 0u && (port->LCKR & pins) != 0u) {
    return false;
  }

  // Подготовить выходное значение до включения режима выхода.
  if (config->mode == GPIO_MODE_OUT) {
    gpio_write(port, pins, config->initial_high);
  }

  for (uint32_t pin = 0u; pin < 16u; ++pin) {
    uint32_t pin_mask = 1u << pin;

    if ((pins & pin_mask) == 0u) {
      continue;
    }

    uint32_t shift = pin * 2u;
    uint32_t field_mask = 3u << shift;

    port->OTYPER =
        (port->OTYPER & ~pin_mask) | ((uint32_t)config->output_type << pin);

    port->OSPEEDR =
        (port->OSPEEDR & ~field_mask) | ((uint32_t)config->speed << shift);

    port->PUPDR =
        (port->PUPDR & ~field_mask) | ((uint32_t)config->pull << shift);

    if (config->mode == GPIO_MODE_AF) {
      uint32_t index = pin / 8u;
      uint32_t af_shift = (pin % 8u) * 4u;

      port->AFR[index] = (port->AFR[index] & ~(15u << af_shift)) |
                         ((uint32_t)config->alternate << af_shift);
    }

    // Режим меняем после подготовки остальных настроек.
    port->MODER =
        (port->MODER & ~field_mask) | ((uint32_t)config->mode << shift);
  }

  return true;
}

uint16_t gpio_read_mask(GPIO_TypeDef *port, uint16_t pins) {
  return (uint16_t)(port->IDR & pins);
}

void gpio_write_mask(GPIO_TypeDef *port, uint16_t pins, uint16_t values) {
  uint32_t set_mask = (uint32_t)pins & values;
  uint32_t reset_mask = (uint32_t)pins & ~(uint32_t)values;

  port->BSRR = set_mask | (reset_mask << 16u);
}

bool gpio_get_config(GPIO_TypeDef *port, uint8_t pin,
                     gpio_pin_state_t *result) {
  if (result == NULL || pin > 15u) {
    return false;
  }

  if (!gpio_enable_clock(port)) {
    return false;
  }

  uint32_t shift = (uint32_t)pin * 2u;

  result->mode = (gpio_mode_t)((port->MODER >> shift) & 3u);

  result->output_type = (gpio_output_type_t)((port->OTYPER >> pin) & 1u);

  result->speed = (gpio_speed_t)((port->OSPEEDR >> shift) & 3u);

  result->pull = (gpio_pull_t)((port->PUPDR >> shift) & 3u);

  uint32_t index = pin / 8u;
  uint32_t af_shift = (pin % 8u) * 4u;

  result->alternate = (uint8_t)((port->AFR[index] >> af_shift) & 15u);

  result->output_high = ((port->ODR >> pin) & 1u) != 0u;

  return true;
}
