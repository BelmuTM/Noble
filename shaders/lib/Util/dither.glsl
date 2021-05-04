//Dithering from Jodie
float Bayer2(vec2 a) {
    a = floor(a);
    return fract(dot(a, vec2(0.5f, a.y * 0.75f)));
}

#define Bayer4(a)   (Bayer2(  0.5f * (a)) * 0.25f + Bayer2(a))
#define Bayer8(a)   (Bayer4(  0.5f * (a)) * 0.25f + Bayer2(a))
#define Bayer16(a)  (Bayer8(  0.5f * (a)) * 0.25f + Bayer2(a))
#define Bayer32(a)  (Bayer16( 0.5f * (a)) * 0.25f + Bayer2(a))
#define Bayer64(a)  (Bayer32( 0.5f * (a)) * 0.25f + Bayer2(a))
#define Bayer128(a) (Bayer64( 0.5f * (a)) * 0.25f + Bayer2(a))
#define Bayer256(a) (Bayer128(0.5f * (a)) * 0.25f + Bayer2(a))