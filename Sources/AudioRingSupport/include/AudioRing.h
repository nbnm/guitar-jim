#ifndef GUITAR_JIM_AUDIO_RING_H
#define GUITAR_JIM_AUDIO_RING_H
#include <stdint.h>
typedef struct GJAudioRing GJAudioRing;
GJAudioRing *gj_ring_create(uint32_t capacity);
void gj_ring_destroy(GJAudioRing *ring);
int32_t gj_ring_write_index(GJAudioRing *ring);
void gj_ring_commit_write(GJAudioRing *ring);
int32_t gj_ring_read_index(GJAudioRing *ring);
void gj_ring_consume_read(GJAudioRing *ring);
#endif
