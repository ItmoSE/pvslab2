#include "ring_buffer.h"

void rb_init(ring_buffer_t *rb, uint8_t *data, size_t size) {
  rb->data = data;
  rb->size = size;
  rb->head = 0;
  rb->tail = 0;
}

bool rb_empty(const ring_buffer_t *rb) { return rb->head == rb->tail; }

bool rb_full(const ring_buffer_t *rb) {
  return ((rb->head + 1) % rb->size) == rb->tail;
}
bool rb_push(ring_buffer_t *rb, uint8_t byte) {
  if (rb_full(rb))
    return false;

  rb->data[rb->head] = byte;
  rb->head = (rb->head + 1) % rb->size;

  return true;
}

bool rb_pop(ring_buffer_t *rb, uint8_t *byte) {
  if (rb_empty(rb))
    return false;

  *byte = rb->data[rb->tail];
  rb->tail = (rb->tail + 1) % rb->size;

  return true;
}

bool rb_peek(const ring_buffer_t *rb, uint8_t *byte) {
  if (rb_empty(rb))
    return false;

  *byte = rb->data[rb->tail];
  return true;
}
