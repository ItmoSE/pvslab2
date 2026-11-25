#include "command_parser.h"
#include "stdlib.h"
#include "traffic_light.h"
#include "uart_driver.h"

#include <stdio.h>
#include <string.h>

#define CMD_SIZE 64
#define OUT_SIZE 128

static char cmd[CMD_SIZE];
static size_t cmd_len;
static bool overflow;
static bool ignore_lf;

static char out[OUT_SIZE];
static size_t out_len;
static size_t out_pos;

static bool switch_pending;
static uart_mode_t requested_mode;

static void reply(const char *text) {
  strcpy(out, text);
  out_len = strlen(out);
  out_pos = 0;
}

static const char *state_to_string(traffic_state_t state) {
  switch (state) {
  case TRAFFIC_RED:
    return "red";
  case TRAFFIC_YELLOW:
    return "yellow";
  case TRAFFIC_GREEN:
    return "green";
  case TRAFFIC_BLINK_GREEN:
    return "blinking green";
  default:
    return "unknown";
  }
}

static bool parse_timeout(const char *str, uint32_t *result) {
  uint32_t value = 0;
  const uint32_t limit = UINT32_MAX / 1000u;

  if (*str == '\0')
    return false;

  while (*str) {
    if (*str < '0' || *str > '9')
      return false;

    uint32_t digit = *str - '0';

    if (value > (limit - digit) / 10u)
      return false;

    value = value * 10u + digit;
    str++;
  }

  if (value == 0)
    return false;

  *result = value;
  return true;
}

static void execute_command(void) {

  if (strcmp(cmd, "?") == 0) {
    snprintf(out, sizeof(out), "\r\n%s, mode %d, timeout %lu, %c\r\n",
             state_to_string(traffic_light_get_state()),
             traffic_light_get_mode() ? 1 : 2,
             (unsigned long)traffic_light_get_timeout(),
             uart_get_mode() == UART_MODE_INTERRUPT ? 'I' : 'P');

    out_len = strlen(out);
    out_pos = 0;

  } else if (strcmp(cmd, "set mode 1") == 0) {
    traffic_light_set_mode(true);
    reply("\r\nOK\r\n");

  } else if (strcmp(cmd, "set mode 2") == 0) {
    traffic_light_set_mode(false);
    reply("\r\nOK\r\n");

  } else if (strncmp(cmd, "set timeout ", 12) == 0) {
    uint32_t seconds;

    if (parse_timeout(cmd + 12, &seconds)) {
      traffic_light_set_timeout(seconds);
      reply("\r\nOK\r\n");
    } else {
      reply("\r\nInvalid argument\r\n");
    }

  } else if (strcmp(cmd, "set interrupts on") == 0) {
    requested_mode = UART_MODE_INTERRUPT;
    switch_pending = true;
    reply("\r\n");

  } else if (strcmp(cmd, "set interrupts off") == 0) {
    requested_mode = UART_MODE_POLLING;
    switch_pending = true;
    reply("\r\n");

  } else {
    reply("\r\nUnknown command\r\n");
  }
}

void command_parser_update(void) {

  // Send pending output
  if (out_pos < out_len) {
    HAL_StatusTypeDef status = uart_write_byte(out[out_pos]);

    if (status == HAL_OK)
      out_pos++;
    else if (status != HAL_BUSY)
      abort();

    return;
  }

  // Handle pending UART mode change
  if (switch_pending) {
    HAL_StatusTypeDef status = uart_set_mode(requested_mode);

    if (status == HAL_OK) {
      switch_pending = false;
      reply("OK\r\n");
    } else if (status != HAL_BUSY) {
      switch_pending = false;
      reply("Error\r\n");
    }

    return;
  }

  uint8_t byte;

  if (uart_read_byte(&byte) != HAL_OK)
    return;

  // Handle CRLF as a single Enter
  if (byte == '\n' && ignore_lf) {
    ignore_lf = false;
    return;
  }

  ignore_lf = (byte == '\r');

  // Enter
  if (byte == '\r' || byte == '\n') {

    cmd[cmd_len] = '\0';

    if (overflow)
      reply("\r\nCommand too long\r\n");
    else if (cmd_len > 0)
      execute_command();
    else
      reply("\r\n");

    cmd_len = 0;
    overflow = false;

    return;
  }

  // Backspace
  if (byte == '\b' || byte == 127) {
    if (cmd_len > 0 && !overflow) {
      cmd_len--;
      reply("\b \b");
    }

    return;
  }

  // Echo
  out[0] = byte;
  out_len = 1;
  out_pos = 0;

  // Store received byte
  if (cmd_len < sizeof(cmd) - 1 && !overflow) {
    cmd[cmd_len++] = byte;
  } else {
    overflow = true;
  }
}
