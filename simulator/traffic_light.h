#ifndef TRAFFIC_LIGHT_H
#define TRAFFIC_LIGHT_H

#include <stdbool.h>
#include <stdint.h>

typedef enum {
  TRAFFIC_RED,
  TRAFFIC_YELLOW,
  TRAFFIC_GREEN,
  TRAFFIC_BLINK_GREEN
} traffic_state_t;

void traffic_light_init(uint32_t now);
void traffic_light_update(uint32_t now, bool button_pressed_event);

void traffic_light_set_timeout(uint32_t seconds);
void traffic_light_set_mode(bool enabled);

uint32_t traffic_light_get_timeout(void);
bool traffic_light_get_mode(void);
traffic_state_t traffic_light_get_state(void);

#endif
