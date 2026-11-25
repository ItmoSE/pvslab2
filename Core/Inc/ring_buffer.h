#ifndef RING_BUFFER_H
#define RING_BUFFER_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
  uint8_t *data;
  size_t size;
  size_t head;
  size_t tail;
} ring_buffer_t;

void rb_init(ring_buffer_t *rb, uint8_t *data, size_t size);

bool rb_empty(const ring_buffer_t *rb);
bool rb_full(const ring_buffer_t *rb);

bool rb_push(ring_buffer_t *rb, uint8_t byte);
bool rb_pop(ring_buffer_t *rb, uint8_t *byte);

bool rb_peek(const ring_buffer_t *rb, uint8_t *byte);

#endif
