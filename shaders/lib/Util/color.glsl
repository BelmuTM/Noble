/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

float blendOverlay(float base, float blend) {
    return base < 0.5f ? (2.0f * base * blend) : (1.0f - 2.0f * (1.0f - base ) * (1.0f - blend));
}

vec3 blendOverlay(vec3 base, vec3 blend) {
    return vec3(blendOverlay(base.r, blend.r), blendOverlay(base.g, blend.g), blendOverlay(base.b, blend.b));
}

vec3 blendOverlay(vec3 base, vec3 blend, float opacity) {
	  return blendOverlay(base, blend) * opacity + base * (1.0f - opacity);
}

vec4 lumaBasedReinhardToneMapping(vec4 color) {
    float lum = luma(color.rgb);
	  float white = 2.0f;
	  float toneMappedLuma = lum * (1.0f + lum / (white * white)) / (1.0f + lum);
	  color *= toneMappedLuma / lum;
	  return color;
}

vec4 uncharted2ToneMapping(vec4 color) {
	  float A = 0.15f;
	  float B = 0.50f;
	  float C = 0.10f;
	  float D = 0.20f;
	  float E = 0.02f;
	  float F = 0.30f;
	  float W = 11.2f;

	  color = ((color * (A * color + C * B) + D * E) / (color * (A * color + B) + D * F)) - E / F;
	  float white = ((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F;
	  color /= white;

	  return color;
}

vec3 saturation(vec3 color, float adjustment) {
    float lum = luma(color);
    vec3 intensity = vec3(lum);
    return mix(intensity, color, adjustment);
}

vec3 vibranceSaturation(vec3 color, float vibrance, float saturation) {
    float lum = luma(color);
    float mn = min(min(color.r, color.g), color.b);
    float mx = max(max(color.r, color.g), color.b);
    float sat = (1.0f - saturate(mx - mn)) * saturate(1.0f - mx) * lum * 5.0f;
    vec3 light = vec3((mn + mx) / 2.0f);

    color = mix(color, mix(light, color, vibrance), sat);
    color = mix(color, light, (1.0f - light) * (1.0f - vibrance) / 2.0f * abs(vibrance));
    color = mix(vec3(lum), color, saturation);
    return color;
}

vec3 brightnessContrast(vec3 color, float contrast, float brightness) {
    return (color - 0.5f) * contrast + 0.5f + brightness;
}
