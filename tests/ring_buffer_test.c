#include "ring_buffer.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
  uint8_t storage[4];
  ring_buffer_t rb;
  uint8_t byte;

  rb_init(&rb, storage, sizeof(storage));

  assert(rb_empty(&rb));
  assert(!rb_pop(&rb, &byte));

  assert(rb_push(&rb, 'A'));
  assert(rb_push(&rb, 'B'));
  assert(rb_push(&rb, 'C'));

  assert(rb_full(&rb));
  assert(!rb_push(&rb, 'D'));

  assert(rb_pop(&rb, &byte) && byte == 'A');

  assert(rb_push(&rb, 'D'));

  assert(rb_pop(&rb, &byte) && byte == 'B');
  assert(rb_pop(&rb, &byte) && byte == 'C');
  assert(rb_pop(&rb, &byte) && byte == 'D');

  assert(rb_empty(&rb));

  puts("All tests passed");

  return 0;
}
