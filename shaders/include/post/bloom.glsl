/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// Bloom tiles concept originally from Capt Tatsu#7124
// Heavily modified by Belmu#4066

/*
const bool colortex5MipmapEnabled = true;
*/

const vec2 bloomOffsets[] = vec2[](
	vec2(0.0      , 0.0   ),
	vec2(0.0      , 0.26  ),
	vec2(0.135    , 0.26  ),
	vec2(0.2075   , 0.26  ),
	vec2(0.135    , 0.3325),
	vec2(0.160625 , 0.3325),
	vec2(0.1784375, 0.3325)
);

vec4 bloomTile(int LOD) {
	float scale = exp2(LOD); 
	vec2 offset = bloomOffsets[LOD - 2];

	vec2 coords = (texCoords - offset) * scale;
	float padding = 0.5 + 0.005 * scale;

	vec4 color;
	if(abs(coords.x - 0.5) < padding && abs(coords.y - 0.5) < padding) {
		color = gaussianBlur(texCoords - offset, colortex5, vec2(1.0, 0.0), scale);
	}
	return color;
}

vec4 getBloomTile(int LOD) {
	return gaussianBlur(texCoords / exp2(LOD) + bloomOffsets[LOD - 2], colortex5, vec2(0.0, 1.0), 1.0);
}

vec4 writeBloom() {
	vec4 bloom  = bloomTile(2);
	     bloom += bloomTile(3);
	     bloom += bloomTile(4);
	     bloom += bloomTile(5);
	     bloom += bloomTile(6);
	     bloom += bloomTile(7);
	     bloom += bloomTile(8);
	return bloom;
}

vec4 readBloom() {
    vec4 bloom  = getBloomTile(2);
	     bloom += getBloomTile(3);
	     bloom += getBloomTile(4);
	     bloom += getBloomTile(5);
	     bloom += getBloomTile(6);
	     bloom += getBloomTile(7);
	     bloom += getBloomTile(8);
    return bloom;
}
