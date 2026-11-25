#ifndef LED_H
#define LED_H

#include <stdbool.h>

typedef enum { LED_RED, LED_YELLOW, LED_GREEN } led_t;

void led_set(led_t led, bool enabled);
void led_toggle(led_t led);

#endif
