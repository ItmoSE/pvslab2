#include "button.h"
#include "gpio_driver.h"

#include "stm32f7xx_hal.h" // IWYU pragma: keep

bool button_is_pressed(void) {
  return gpio_read(GPIOI, GPIO_PIN_11) == GPIO_PIN_SET;
}

bool button_update(uint32_t now) {
  static bool last_read_pressed = false;
  static bool confirmed_pressed = false;
  static uint32_t last_change_time = 0;

  bool pressed_now = button_is_pressed();

  if (pressed_now != last_read_pressed) {
    last_read_pressed = pressed_now;
    last_change_time = now;
  }

  if (last_read_pressed != confirmed_pressed &&
      (uint32_t)(now - last_change_time) >= 20u) {
    confirmed_pressed = last_read_pressed;
    return confirmed_pressed;
  }

  return false;
}

bool button_init(void) {
  const gpio_config_t config = {.mode = GPIO_MODE_IN,
                                .output_type = GPIO_OUTPUT_PUSH_PULL,
                                .speed = GPIO_SPEED_LOW,
                                .pull = GPIO_PULL_NONE,
                                .alternate = 0u,
                                .initial_high = false};

  return gpio_init(GPIOI, 1u << 11, &config);
}
