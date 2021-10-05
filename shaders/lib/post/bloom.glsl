/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// Bloom tiles concept from Capt Tatsu#7124
// Gaussian blur by Belmu#4066

vec4 bloomTile(int LOD, vec2 offset) {
	float scale = exp2(LOD);
	vec2 coords = (texCoords - offset) * scale;
	float padding = 0.5 + 0.005 * scale;

	vec4 color;
	if(abs(coords.x - 0.5) < padding && abs(coords.y - 0.5) < padding) {
		color = gaussianBlur(texCoords - offset, colortex5, vec2(1.0, 0.0), scale);
	}
	return color;
}

vec4 getBloomTile(int LOD, vec2 offset) {
	return gaussianBlur(texCoords / exp2(LOD) + offset, colortex5, vec2(0.0, 1.0), 1.0);
}

vec4 writeBloom() {
	vec4 bloom  = bloomTile(2, vec2(0.0      , 0.0   ));
	     bloom += bloomTile(3, vec2(0.0      , 0.26  ));
	     bloom += bloomTile(4, vec2(0.135    , 0.26  ));
	     bloom += bloomTile(5, vec2(0.2075   , 0.26  ));
	     bloom += bloomTile(6, vec2(0.135    , 0.3325));
	     bloom += bloomTile(7, vec2(0.160625 , 0.3325));
	     bloom += bloomTile(8, vec2(0.1784375, 0.3325));
	return bloom;
}

vec4 readBloom() {
    vec4 bloom  = getBloomTile(2, vec2(0.0      , 0.0   ));
	     bloom += getBloomTile(3, vec2(0.0      , 0.26  ));
	     bloom += getBloomTile(4, vec2(0.135    , 0.26  ));
	     bloom += getBloomTile(5, vec2(0.2075   , 0.26  ));
	     bloom += getBloomTile(6, vec2(0.135    , 0.3325));
	     bloom += getBloomTile(7, vec2(0.160625 , 0.3325));
	     bloom += getBloomTile(8, vec2(0.1784375, 0.3325));
    return bloom;
}
