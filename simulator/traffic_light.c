#include "traffic_light.h"
#include "led.h"

static uint32_t init_time;
static uint32_t last_blink_green;
static traffic_state_t current_state;
static uint32_t time_to_shine_red;
static bool reduce_red_time = false;

static uint32_t red_timeout = 12000u;
static bool button_enabled = true;

void traffic_light_init(uint32_t now) {
  init_time = now;
  current_state = TRAFFIC_RED;
  time_to_shine_red = red_timeout;
  reduce_red_time = false;

  led_set(LED_GREEN, false);
  led_set(LED_YELLOW, false);
  led_set(LED_RED, true);
}

void traffic_light_update(uint32_t now, bool button_pressed_event) {

  button_pressed_event = button_pressed_event && button_enabled;

  if (button_pressed_event && (current_state == TRAFFIC_BLINK_GREEN ||
                               current_state == TRAFFIC_YELLOW)) {
    reduce_red_time = true;
  }

  switch (current_state) {

  case TRAFFIC_RED:
    if (button_pressed_event && (now - init_time) < time_to_shine_red &&
        time_to_shine_red - (now - init_time) > 3000u) {
      time_to_shine_red = (now - init_time) + 3000u;
    }

    if ((now - init_time) >= time_to_shine_red) {
      led_set(LED_RED, false);
      led_set(LED_GREEN, true);

      current_state = TRAFFIC_GREEN;
      init_time = now;
    }
    break;

  case TRAFFIC_GREEN:
    if ((now - init_time) >= 3000u) {
      current_state = TRAFFIC_BLINK_GREEN;
      init_time = now;
      last_blink_green = now;
    }
    break;

  case TRAFFIC_BLINK_GREEN:
    if ((now - init_time) < 2000u && (now - last_blink_green) >= 300u) {
      led_toggle(LED_GREEN);
      last_blink_green = now;
    }

    if ((now - init_time) >= 2000u) {
      led_set(LED_GREEN, false);
      led_set(LED_YELLOW, true);
      current_state = TRAFFIC_YELLOW;
      init_time = now;
    }
    break;

  case TRAFFIC_YELLOW:
    if ((now - init_time) >= 3000u) {
      led_set(LED_YELLOW, false);
      led_set(LED_RED, true);

      time_to_shine_red = reduce_red_time ? red_timeout / 4u : red_timeout;

      reduce_red_time = false;
      current_state = TRAFFIC_RED;
      init_time = now;
    }
    break;

  default:
    break;
  }
}

void traffic_light_set_timeout(uint32_t seconds) {
  if (seconds > 0 && seconds <= UINT32_MAX / 1000u) {
    red_timeout = seconds * 1000u;
  }
}

void traffic_light_set_mode(bool enabled) {
  button_enabled = enabled;

  if (!enabled) {
    reduce_red_time = false;
  }
}

uint32_t traffic_light_get_timeout(void) { return red_timeout / 1000u; }

bool traffic_light_get_mode(void) { return button_enabled; }

traffic_state_t traffic_light_get_state(void) { return current_state; }
