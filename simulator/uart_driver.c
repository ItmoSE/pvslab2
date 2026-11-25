#include "uart_driver.h"

#include <errno.h>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>

static int fd = -1;
static uart_mode_t current_mode = UART_MODE_POLLING;

int uart_init(const char *path) {
  fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK);

  if (fd < 0)
    return -1;

  struct termios tty;

  if (tcgetattr(fd, &tty) < 0)
    goto error;

  cfmakeraw(&tty);

  cfsetispeed(&tty, B57600);
  cfsetospeed(&tty, B57600);

  tty.c_cflag |= CLOCAL | CREAD;
  tty.c_cflag &= ~CRTSCTS;

  if (tcsetattr(fd, TCSANOW, &tty) < 0)
    goto error;

  return 0;

error:
  close(fd);
  fd = -1;
  return -1;
}

HAL_StatusTypeDef uart_read_byte(uint8_t *byte) {
  ssize_t result = read(fd, byte, 1);

  if (result == 1)
    return HAL_OK;

  if (result == 0 || errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
    return HAL_TIMEOUT;

  return HAL_ERROR;
}

HAL_StatusTypeDef uart_write_byte(uint8_t byte) {
  ssize_t result = write(fd, &byte, 1);

  if (result == 1)
    return HAL_OK;

  if (result == 0 || errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
    return HAL_BUSY;

  return HAL_ERROR;
}

HAL_StatusTypeDef uart_set_mode(uart_mode_t mode) {
  current_mode = mode;
  return HAL_OK;
}

uart_mode_t uart_get_mode(void) { return current_mode; }
