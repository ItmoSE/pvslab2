#include "led.h"
#include <stdio.h>

static bool states[3];

static const char *names[] = {"RED", "YELLOW", "GREEN"};

void led_set(led_t led, bool enabled) {
  if (states[led] == enabled)
    return;

  states[led] = enabled;

  printf("[LED] %s %s\n", names[led], enabled ? "ON" : "OFF");
}

void led_toggle(led_t led) { led_set(led, !states[led]); }
