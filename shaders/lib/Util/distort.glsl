/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

vec2 distortPosition(in vec2 position) {
    float CenterDistance = length(position);
    float DistortionFactor = mix(1.0f, CenterDistance, 0.923f);
    return position / DistortionFactor;
}
