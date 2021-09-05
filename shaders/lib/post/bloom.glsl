// Bloom tiles concept from Capt Tatsu#7124

float weight[7] = float[7](1.0, 6.0, 15.0, 20.0, 15.0, 6.0, 1.0);

vec3 bloomTile(int LOD, vec2 offset) {
	float scale = exp2(LOD);
	vec2 coords = (texCoords - offset) * scale;
	float padding = 0.5 + 0.005 * scale;

	vec3 color;
	if(abs(coords.x - 0.5) < padding && abs(coords.y - 0.5) < padding) {
		for(int i = -3; i <= 3; i++) {
			for(int j = -3; j <= 3; j++) {
				float wg = weight[i + 3] * weight[j + 3];
				vec2 bloomCoord = (texCoords - offset + (vec2(i, j) * pixelSize)) * scale;
				color += texture2D(colortex5, bloomCoord).rgb * wg;
			}
		}
		color /= 4096.0;
	}
	return color;
}

vec3 getBloomTile(int LOD, vec2 offset) {
	return texture2D(colortex5, texCoords / exp2(LOD) + offset).rgb;
}
