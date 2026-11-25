#include "led.h"
#include "gpio_driver.h"
#include "stm32f746xx.h"

typedef struct {
  GPIO_TypeDef *port;
  uint16_t pin;
} led_config_t;

static const led_config_t leds[LED_COUNT] = {
    [LED_RED] = {GPIOG, 1u << 6},
    [LED_YELLOW] = {GPIOG, 1u << 7},
    [LED_GREEN] = {GPIOI, 1u << 1},
};

void led_set(led_t led, bool enabled) {
  if ((unsigned)led >= LED_COUNT) {
    return;
  }
  gpio_write(leds[led].port, leds[led].pin, enabled ? 1 : 0);
}

void led_toggle(led_t led) {

  if ((unsigned)led >= LED_COUNT) {
    return;
  }
  gpio_toggle(leds[led].port, leds[led].pin);
}

bool led_init(void) {
  const gpio_config_t config = {.mode = GPIO_MODE_OUT,
                                .output_type = GPIO_OUTPUT_PUSH_PULL,
                                .speed = GPIO_SPEED_LOW,
                                .pull = GPIO_PULL_NONE,
                                .alternate = 0u,
                                .initial_high = false};

  for (unsigned i = 0u; i < LED_COUNT; ++i) {
    if (!gpio_init(leds[i].port, leds[i].pin, &config)) {
      return false;
    }
  }

  return true;
}
