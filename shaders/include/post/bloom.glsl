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

	vec3 sampleBloomTile(int lod) {
		float scale = exp2(lod + 2); 
		vec2 coords = (textureCoords - bloomOffsets[lod]) * scale;

		vec2 texelScale = pixelSize * scale;

		if(any(greaterThanEqual(abs(coords - 0.5), texelScale + 0.5))) return vec3(0.0);

		vec3 bloom = vec3(0.0);
        for(int x = -filterSize; x <= filterSize; x++) {
            for(int y = -filterSize; y <= filterSize; y++) {
                float weight = gaussianDistribution2D(vec2(x, y), 1.0);
                bloom  		+= textureLod(MAIN_BUFFER, coords + vec2(x, y) * texelScale, 0).rgb * weight;
            }
        }
		return bloom;
	}

	vec3 getBloomTile(int lod) {
		return textureBicubic(SHADOWMAP_BUFFER, textureCoords / exp2(lod + 2) + bloomOffsets[lod]).rgb;
	}

	void writeBloom(inout vec3 bloom) {
		bloom  = sampleBloomTile(0);
		bloom += sampleBloomTile(1);
		bloom += sampleBloomTile(2);
		bloom += sampleBloomTile(3);
		bloom += sampleBloomTile(4);
		bloom += sampleBloomTile(5);
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
