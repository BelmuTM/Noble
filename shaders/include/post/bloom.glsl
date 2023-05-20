/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if BLOOM == 1
	const vec2 bloomOffsets[] = vec2[](
		vec2(0.000, 0.000),
		vec2(0.502, 0.000),
    	vec2(0.502, 0.254),
    	vec2(0.502, 0.382),
		vec2(0.502, 0.447),
		vec2(0.502, 0.481)
	);

	const int filterSize = 3;

	void writeBloomTile(out vec3 tile, int lod) {
		float scale = exp2(lod + 1); 
		vec2 coords = (textureCoords - bloomOffsets[lod]) * scale;

		vec2 texelScale = pixelSize * scale;

		if(any(greaterThanEqual(abs(coords - 0.5), texelScale + 0.5))) return;

        for(int x = -filterSize; x <= filterSize; x++) {
            for(int y = -filterSize; y <= filterSize; y++) {
                float weight = gaussianDistribution2D(vec2(x, y), 1.0);
                      tile  += textureLod(MAIN_BUFFER, coords + vec2(x, y) * texelScale, 0).rgb * weight;
            }
        }
	}

	vec3 getBloomTile(int lod) {
		return textureBicubic(SHADOWMAP_BUFFER, textureCoords / exp2(lod + 1) + bloomOffsets[lod]).rgb;
	}

	vec3 readBloom() {
		vec3 bloom;
    	bloom  = getBloomTile(0);
	    bloom += getBloomTile(1);
	    bloom += getBloomTile(2);
	    bloom += getBloomTile(3);
	    bloom += getBloomTile(4);
		bloom += getBloomTile(5);
    	return max0(bloom / 6.0);
	}
#endif
