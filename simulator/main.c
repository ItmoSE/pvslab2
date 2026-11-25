#include "command_parser.h"
#include "traffic_light.h"
#include "uart_driver.h"

#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>

static uint32_t get_tick(void) {
  struct timespec ts;

  clock_gettime(CLOCK_MONOTONIC, &ts);

  return (uint32_t)((uint64_t)ts.tv_sec * 1000u + ts.tv_nsec / 1000000u);
}

static bool button_update(void) {
  struct pollfd pfd = {.fd = STDIN_FILENO, .events = POLLIN};

  if (poll(&pfd, 1, 0) <= 0)
    return false;

  if (!(pfd.revents & POLLIN))
    return false;

  char buf[64];
  ssize_t count = read(STDIN_FILENO, buf, sizeof(buf));

  for (ssize_t i = 0; i < count; i++) {
    if (buf[i] == 'b')
      return true;
  }

  return false;
}

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "Usage: %s <tty>\n", argv[0]);
    return 1;
  }

  if (uart_init(argv[1]) != 0) {
    perror("uart_init");
    return 1;
  }

  printf("Simulator ready: %s\n", argv[1]);
  printf("Press b + Enter to simulate button\n");

  traffic_light_init(get_tick());

  const struct timespec delay = {.tv_sec = 0, .tv_nsec = 1000000};

  while (1) {
    uint32_t now = get_tick();

    bool pressed_event = button_update();

    traffic_light_update(now, pressed_event);
    command_parser_update();

    nanosleep(&delay, NULL);
  }
}
