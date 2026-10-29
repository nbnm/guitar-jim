#include "AudioRing.h"
#include <stdatomic.h>
#include <stdlib.h>
struct GJAudioRing { _Atomic uint32_t head; _Atomic uint32_t tail; uint32_t capacity; };
GJAudioRing *gj_ring_create(uint32_t capacity) {
    if (capacity < 2) return NULL;
    GJAudioRing *ring = calloc(1, sizeof(GJAudioRing));
    if (ring) { atomic_init(&ring->head, 0); atomic_init(&ring->tail, 0); ring->capacity = capacity; }
    return ring;
}
void gj_ring_destroy(GJAudioRing *ring) { free(ring); }
int32_t gj_ring_write_index(GJAudioRing *ring) {
    uint32_t head = atomic_load_explicit(&ring->head, memory_order_relaxed);
    return (head + 1) % ring->capacity == atomic_load_explicit(&ring->tail, memory_order_acquire) ? -1 : (int32_t)head;
}
void gj_ring_commit_write(GJAudioRing *ring) {
    uint32_t head = atomic_load_explicit(&ring->head, memory_order_relaxed);
    atomic_store_explicit(&ring->head, (head + 1) % ring->capacity, memory_order_release);
}
int32_t gj_ring_read_index(GJAudioRing *ring) {
    uint32_t tail = atomic_load_explicit(&ring->tail, memory_order_relaxed);
    return tail == atomic_load_explicit(&ring->head, memory_order_acquire) ? -1 : (int32_t)tail;
}
void gj_ring_consume_read(GJAudioRing *ring) {
    uint32_t tail = atomic_load_explicit(&ring->tail, memory_order_relaxed);
    atomic_store_explicit(&ring->tail, (tail + 1) % ring->capacity, memory_order_release);
}
