#ifndef BUTTON_H
#define BUTTON_H

#include <stdbool.h>
#include <stdint.h>

bool button_is_pressed(void);
bool button_update(uint32_t now);
bool button_init(void);

#endif
