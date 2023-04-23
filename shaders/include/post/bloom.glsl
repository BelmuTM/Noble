/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
    [Credits]:
        SixSeven   - help with bloom tiles (https://github.com/6ix7even)
        Capt Tatsu - inspiration for bloom (https://github.com/CaptTatsu)
*/

#if BLOOM == 1
	const vec2 bloomOffsets[] = vec2[](
		vec2(0.0   , 0.0   ),
        vec2(0.0   , 0.253 ),
        vec2(0.1265, 0.253 ),
		vec2(0.1265, 0.319 ),
		vec2(0.1595, 0.319 ),
		vec2(0.1595, 0.3375),
		vec2(0.1685, 0.3375)
	);

	const int   blurSize  = 3;
	const float blurSigma = 1.0;

	vec3 bloomTile(int lod) {
		float scale   = exp2(lod); 
		vec2 coords   = (texCoords - bloomOffsets[lod - 2]) * scale;
		vec2 texScale = pixelSize * scale;

		vec3 bloom = vec3(0.0);

		if(any(greaterThanEqual(abs(coords - 0.5), texScale + 0.5))) return bloom;

        for(int x = -blurSize; x <= blurSize; x++) {
            for(int y = -blurSize; y <= blurSize; y++) {
                float weight = gaussianDistribution2D(vec2(x, y), blurSigma);
                bloom  		+= textureLod(MAIN_BUFFER, coords + vec2(x, y) * texScale, lod).rgb * weight;
            }
        }
		return bloom;
	}

	vec3 getBloomTile(int lod) {
		return textureBicubic(SHADOWMAP_BUFFER, texCoords / exp2(lod) + bloomOffsets[lod - 2]).rgb;
	}

	void writeBloom(inout vec3 bloom) {
		bloom  = bloomTile(2);
		bloom += bloomTile(3);
		bloom += bloomTile(4);
		bloom += bloomTile(5);
		bloom += bloomTile(6);
		bloom += bloomTile(7);
		bloom += bloomTile(8);
	}

	vec3 readBloom() {
		vec3 bloom;
    	bloom  = getBloomTile(2);
	    bloom += getBloomTile(3);
	    bloom += getBloomTile(4);
	    bloom += getBloomTile(5);
	    bloom += getBloomTile(6);
	    bloom += getBloomTile(7);
	    bloom += getBloomTile(8);
    	return max0(bloom / 7.0);
	}
#endif
