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

	vec3 writeBloomTile(int lod) {
		float scalingFactor = exp2(lod + 2); 

		vec2 coords = (textureCoords - bloomOffsets[lod]) * scalingFactor;
		vec2 scale  = texelSize * scalingFactor;

		if(any(greaterThanEqual(abs(coords - 0.5), scale + 0.5))) return vec3(0.0);

		vec3  tile        = vec3(0.0);
		float totalWeight = EPS;

        for(int x = -filterSize; x <= filterSize; x++) {
            for(int y = -filterSize; y <= filterSize; y++) {
                float weight = gaussianDistribution2D(vec2(x, y), 1.0);
                tile        += textureLod(MAIN_BUFFER, coords + vec2(x, y) * scale, lod).rgb * weight;
				totalWeight += weight;
            }
        }
		return tile / totalWeight;
	}

	vec3 sampleBloomTile(int lod) {
		return textureBicubic(SHADOWMAP_BUFFER, textureCoords / exp2(lod + 2) + bloomOffsets[lod]).rgb;
	}

	vec3 writeBloom() {
		vec3 bloom = vec3(0.0);
    	bloom  = writeBloomTile(0);
	    bloom += writeBloomTile(1);
	    bloom += writeBloomTile(2);
	    bloom += writeBloomTile(3);
	    bloom += writeBloomTile(4);
		bloom += writeBloomTile(5);
    	return bloom;
	}

	vec3 readBloom() {
		vec3 bloom = vec3(0.0);
    	bloom  = sampleBloomTile(0);
	    bloom += sampleBloomTile(1);
	    bloom += sampleBloomTile(2);
	    bloom += sampleBloomTile(3);
	    bloom += sampleBloomTile(4);
		bloom += sampleBloomTile(5);
    	return bloom / 6.0;
	}
#endif
