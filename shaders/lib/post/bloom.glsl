/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// Bloom tiles concept from Capt Tatsu#7124
// Gaussian blur by Belmu#4066

const int BLOOM_KERNEL = 11;
const float bloomWeights[] = float[](
	0.019590831,
	0.042587370,
	0.077902496,
	0.119916743,
	0.155336773,
	0.169331570,
	0.155336773,
	0.119916743,
	0.077902496,
	0.042587370,
	0.019590831
);

vec3 gaussianBloom(vec2 direction, vec2 coords, float scale) {
    vec3 color = vec3(0.0);

    for(int i = 0; i < BLOOM_KERNEL; i++) {
        vec2 sampleCoords = (coords + (direction * float(i - 5) * pixelSize)) * scale;
        color += texture2D(colortex5, sampleCoords).rgb * bloomWeights[i];
    }
    return color;
}

vec3 bloomTile(int LOD, vec2 offset) {
	float scale = exp2(LOD);
	vec2 coords = (texCoords - offset) * scale;
	float padding = 0.5 + 0.005 * scale;

	vec3 color;
	if(abs(coords.x - 0.5) < padding && abs(coords.y - 0.5) < padding) {
		color = gaussianBloom(vec2(1.0, 0.0), texCoords - offset, scale);
	}
	return color;
}

vec3 getBloomTile(int LOD, vec2 offset) {
	return gaussianBloom(vec2(0.0, 1.0), texCoords / exp2(LOD) + offset, 1.0);
}

vec3 writeBloom() {
	vec3 bloom  = bloomTile(2, vec2(0.0      , 0.0   ));
	     bloom += bloomTile(3, vec2(0.0      , 0.26  ));
	     bloom += bloomTile(4, vec2(0.135    , 0.26  ));
	     bloom += bloomTile(5, vec2(0.2075   , 0.26  ));
	     bloom += bloomTile(6, vec2(0.135    , 0.3325));
	     bloom += bloomTile(7, vec2(0.160625 , 0.3325));
	     bloom += bloomTile(8, vec2(0.1784375, 0.3325));
	return bloom;
}

vec3 readBloom() {
    vec3 bloom  = getBloomTile(2, vec2(0.0      , 0.0   ));
	     bloom += getBloomTile(3, vec2(0.0      , 0.26  ));
	     bloom += getBloomTile(4, vec2(0.135    , 0.26  ));
	     bloom += getBloomTile(5, vec2(0.2075   , 0.26  ));
	     bloom += getBloomTile(6, vec2(0.135    , 0.3325));
	     bloom += getBloomTile(7, vec2(0.160625 , 0.3325));
	     bloom += getBloomTile(8, vec2(0.1784375, 0.3325));
    return bloom;
}
