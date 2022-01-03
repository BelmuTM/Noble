/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*
	SOURCES:
	BSL 	- Capt Tatsu
	Voyager - SixSeven
*/

const bool colortex5MipmapEnabled = true;

#if BLOOM == 1
	const vec2 bloomOffsets[] = vec2[](
		vec2(0.0      , 0.0   ),
		vec2(0.0      , 0.26  ),
		vec2(0.135    , 0.26  ),
		vec2(0.2075   , 0.26  ),
		vec2(0.135    , 0.3325),
		vec2(0.160625 , 0.3325),
		vec2(0.1784375, 0.3325)
	);

	vec3 bloomTile(int LOD) {
		float scale = exp2(LOD); 
		vec2 offset = bloomOffsets[LOD - 2];

		vec2 coords   = (texCoords - offset) * scale;
		vec2 texScale = pixelSize * scale;
		vec3 color 	  = vec3(0.0);

		if(any(greaterThanEqual(abs(coords - 0.5), texScale + 0.5))) return vec3(0.0);

		const int steps   = 5;
		const float sigma = 2.0;

        for(int i = -steps; i <= steps; i++) {
            for(int j = -steps; j <= steps; j++) {
                float weight = gaussianDistrib1D(i, sigma) * gaussianDistrib1D(j, sigma);
                color  		+= textureLod(colortex5, coords + vec2(i, j) * texScale, LOD).rgb * weight;
            }
        }
		return color;
	}

	vec3 getBloomTile(int LOD) {
		return texture(colortex5, texCoords / exp2(LOD) + bloomOffsets[LOD - 2]).rgb;
	}

	vec3 writeBloom() {
		vec3 bloom  = bloomTile(2);
	     	 bloom += bloomTile(3);
	     	 bloom += bloomTile(4);
	     	 bloom += bloomTile(5);
	     	 bloom += bloomTile(6);
	     	 bloom += bloomTile(7);
	      	 bloom += bloomTile(8);
		return bloom;
	}

	vec3 readBloom() {
    	vec3 bloom  = getBloomTile(2);
	     	 bloom += getBloomTile(3);
	     	 bloom += getBloomTile(4);
	     	 bloom += getBloomTile(5);
	     	 bloom += getBloomTile(6);
	     	 bloom += getBloomTile(7);
	     	 bloom += getBloomTile(8);
    	return bloom;
	}
#endif
