/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if AO_TYPE == 0

	float SSAO(vec3 viewPos, vec3 normal) {
		float occlusion = 0.0;

		for(int i = 0; i < SSAO_SAMPLES; i++) {
			vec2 noise     = TAA == 1 ? vec2(randF(), randF()) : uniformNoise(i, blueNoise);
			vec3 rayDir    = generateCosineVector(normal, noise);
			vec3 rayPos    = viewPos + rayDir * SSAO_RADIUS;
			float rayDepth = getViewPos0(viewToScreen(rayPos).xy).z;

			// https://learnopengl.com/Advanced-Lighting/SSAO
			float rangeCheck = quintic(0.0, 1.0, SSAO_RADIUS / abs(viewPos.z - rayDepth));
        	occlusion 		+= (rayDepth >= rayPos.z + EPS ? 1.0 : 0.0) * rangeCheck;
		}
		return pow(1.0 - occlusion * rcp(SSAO_SAMPLES), SSAO_STRENGTH);
	}

#elif AO_TYPE == 1

	float RTAO(vec3 viewPos, vec3 normal, out vec3 bentNormal) {
		vec3 rayPos     = viewPos + normal * 1e-2;
		float occlusion = 1.0; vec3 hitPos;

		for(int i = 0; i < RTAO_SAMPLES; i++) {
			vec3 rayDir = generateCosineVector(normal, vec2(randF(), randF()));

			if(!raytrace(rayPos, rayDir, RTAO_STEPS, randF(), hitPos)) {
				bentNormal += rayDir;
				continue;
			}
			// Thanks Jessie#7257 for providing the occlusion computation method
			occlusion -= rcp(RTAO_SAMPLES);
		}
		bentNormal = normalize(bentNormal);
		return occlusion;
	}
#else

/* 
    SOURCES / CREDITS:
    Activision:  https://blog.selfshadow.com/publications/s2016-shading-course/activision/s2016_pbs_activision_occlusion.pdf
				 https://www.activision.com/cdn/research/Practical_Real_Time_Strategies_for_Accurate_Indirect_Occlusion_NEW%20VERSION_COLOR.pdf
*/

	float multiBounceApprox(float visibility) { 
    	const float albedo = 0.2; 
    	return visibility / (albedo * visibility + (1.0 - albedo)); 
 	}

	float findMaximumHorizon(vec2 coords, vec3 viewPos, vec3 viewDir, vec3 normal, vec3 sliceDir, vec2 radius) {
		float horizonCos = -1.0;

		vec2 stepSize  = radius * rcp(GTAO_HORIZON_STEPS);
		vec2 increment = sliceDir.xy * stepSize;
		vec2 screenPos = coords + uniformAnimatedNoise(blueNoise.rg) * increment;

		for(int i = 0; i < GTAO_HORIZON_STEPS; i++, screenPos += increment) {
			float depth = texelFetch(depthtex0, ivec2(screenPos * viewSize), 0).r;
			if(clamp01(screenPos) != screenPos || depth == 1.0 || isHand(screenPos)) continue;

			vec3 horizonVec = screenToView(vec3(screenPos, depth)) - viewPos;
			float cosTheta  = mix(dot(horizonVec, viewDir) * fastRcpLength(horizonVec), -1.0, linearStep(2.0, 3.0, lengthSqr(horizonVec)));
		
			horizonCos = max(horizonCos, cosTheta);
		}
		return fastAcos(horizonCos);
	}

	float GTAO(vec2 coords, vec3 viewPos, vec3 normal, out vec3 bentNormal) {
		float visibility = 0.0;

		float rcpViewLength = fastRcpLength(viewPos);
		vec2 radius  		= GTAO_RADIUS * rcpViewLength * rcp(vec2(1.0, aspectRatio));
		vec3 viewDir 		= viewPos * -rcpViewLength;

		for(int i = 0; i < GTAO_SLICES; i++) {
			float sliceAngle = (PI * rcp(GTAO_SLICES)) * (i + randF());
			vec3  sliceDir   = vec3(cos(sliceAngle), sin(sliceAngle), 0.0);

			vec3 orthoDir   = sliceDir - dot(sliceDir, viewDir) * viewDir;
			vec3 axis       = cross(sliceDir, viewDir);
			vec3 projNormal = normal - axis * dot(normal, axis);

			float sgnGamma = sign(dot(projNormal, orthoDir));
			float normLen  = fastRcpLength(projNormal);
			float cosGamma = clamp01(dot(projNormal, viewDir) * normLen);
			float gamma    = sgnGamma * fastAcos(cosGamma);

			vec2 horizons;
			horizons.x = -findMaximumHorizon(coords, viewPos, viewDir, normal,-sliceDir, radius);
			horizons.y =  findMaximumHorizon(coords, viewPos, viewDir, normal, sliceDir, radius);
			horizons   = gamma + clamp(horizons - gamma, -HALF_PI, HALF_PI);
			
			vec2 arc    = cosGamma + 2.0 * horizons * sin(gamma) - cos(2.0 * horizons - gamma);
			visibility += dot(arc, vec2(0.25)) * normLen;

			float bentAngle = dot(horizons, vec2(0.5));
			bentNormal 	   += viewDir * cos(bentAngle) + orthoDir * sin(bentAngle);
		}
		bentNormal = normalize(normalize(bentNormal) - viewDir * 0.5);
		return multiBounceApprox(visibility * rcp(GTAO_SLICES));
	}
#endif
