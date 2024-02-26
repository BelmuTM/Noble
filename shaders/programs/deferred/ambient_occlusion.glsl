/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
	[References]:
		LearnOpenGL. (2015). SSAO. https://learnopengl.com/Advanced-Lighting/SSAO
		Jimenez et al. (2016). Practical Real-Time Strategies for Accurate Indirect Occlusion. https://www.activision.com/cdn/research/Practical_Real_Time_Strategies_for_Accurate_Indirect_Occlusion_NEW%20VERSION_COLOR.pdf
		Jimenez et al. (2016). Practical Realtime Strategies for Accurate Indirect Occlusion. https://blog.selfshadow.com/publications/s2016-shading-course/activision/s2016_pbs_activision_occlusion.pdf
*/

#include "/settings.glsl"
#include "/include/internalSettings.glsl"

#include "/include/taau_scale.glsl"

#if AO == 0 || GI == 1
	#include "/programs/discard.glsl"
#else
	#if defined STAGE_VERTEX
		#include "/programs/vertex_taau.glsl"

	#elif defined STAGE_FRAGMENT

		/* RENDERTARGETS: 12 */

		layout (location = 0) out vec3 ao;

		in vec2 textureCoords;
		in vec2 vertexCoords;

		#include "/include/common.glsl"
	
		#if AO_TYPE == 0

			float SSAO(vec3 viewPosition, vec3 normal) {
				float occlusion = 0.0;

				for(int i = 0; i < SSAO_SAMPLES; i++) {
					vec3 rayDirection = generateCosineVector(normal, rand2F());
					vec3 rayPosition  = viewPosition + rayDirection * SSAO_RADIUS;

					vec2  sampleCoords = viewToScreen(rayPosition).xy;
					float rayDepth     = screenToView(vec3(sampleCoords, texture(depthtex0, sampleCoords * RENDER_SCALE).r)).z;

					if(rayDepth >= rayPosition.z + EPS) {
						occlusion += quintic(0.0, 1.0, SSAO_RADIUS / abs(viewPosition.z - rayDepth));
					}
		    	}
		    	return pow(1.0 - occlusion * rcp(SSAO_SAMPLES), SSAO_STRENGTH);
	    	}

		#elif AO_TYPE == 1

			#include "/include/fragment/raytracer.glsl"

			float RTAO(vec3 viewPosition, vec3 normal, out vec3 bentNormal) {
				vec3 rayPosition = viewPosition + normal * 1e-2;
				float occlusion  = 1.0;

				vec3 hitPosition = vec3(0.0);

				for(int i = 0; i < RTAO_SAMPLES; i++) {
					vec3 rayDirection = generateCosineVector(normal, rand2F());

					if(!raytrace(depthtex0, rayPosition, rayDirection, RTAO_STEPS, randF(), RENDER_SCALE, hitPosition)) {
						bentNormal += rayDirection;
						continue;
					}
					occlusion -= rcp(RTAO_SAMPLES);
				}
				bentNormal = normalize(bentNormal);
				return saturate(occlusion);
			}

		#else

			float multiBounceApprox(float visibility) { 
				const float albedo = 0.2; 
				return visibility / (albedo * visibility + (1.0 - albedo)); 
 			}

			float findMaximumHorizon(vec3 viewPosition, vec3 viewDirection, vec3 normal, vec3 sliceDir, vec2 radius) {
				float horizonCos = -1.0;

				vec2 stepSize    = radius * rcp(GTAO_HORIZON_STEPS);
				vec2 increment   = sliceDir.xy * stepSize;
				vec2 rayPosition = textureCoords + rand2F() * increment;

				for(int i = 0; i < GTAO_HORIZON_STEPS; i++, rayPosition += increment) {
					float depth = texelFetch(depthtex0, ivec2(rayPosition * viewSize * RENDER_SCALE), 0).r;
					if(saturate(rayPosition) != rayPosition || depth == 1.0 || depth < handDepth) continue;

					vec3 horizonVec = screenToView(vec3(rayPosition, depth)) - viewPosition;
					float cosTheta  = mix(dot(horizonVec, viewDirection) * fastRcpLength(horizonVec), -1.0, linearStep(2.0, 3.0, lengthSqr(horizonVec)));
		
					horizonCos = max(horizonCos, cosTheta);
				}
				return fastAcos(horizonCos);
			}

			float GTAO(vec3 viewPosition, vec3 normal, out vec3 bentNormal) {
				float visibility = 0.0;

				float rcpViewLength = fastRcpLength(viewPosition);
				vec2  radius  		= GTAO_RADIUS * rcpViewLength * rcp(vec2(1.0, aspectRatio));
				vec3  viewDirection = viewPosition * -rcpViewLength;

				float dither = interleavedGradientNoise(gl_FragCoord.xy);

				for(int i = 0; i < GTAO_SLICES; i++) {
					float sliceAngle = (PI * rcp(GTAO_SLICES)) * (i + dither);
					vec3  sliceDir   = vec3(cos(sliceAngle), sin(sliceAngle), 0.0);

					vec3 orthoDir   = sliceDir - dot(sliceDir, viewDirection) * viewDirection;
					vec3 axis       = cross(sliceDir, viewDirection);
					vec3 projNormal = normal - axis * dot(normal, axis);

					float sgnGamma = sign(dot(projNormal, orthoDir));
					float normLen  = length(projNormal);
					float cosGamma = saturate(dot(projNormal, viewDirection) / normLen);
					float gamma    = sgnGamma * fastAcos(cosGamma);

					vec2 horizons;
					horizons.x = -findMaximumHorizon(viewPosition, viewDirection, normal,-sliceDir, radius);
					horizons.y =  findMaximumHorizon(viewPosition, viewDirection, normal, sliceDir, radius);
					horizons   =  gamma + clamp(horizons - gamma, -HALF_PI, HALF_PI);
			
					vec2 arc    = cosGamma + 2.0 * horizons * sin(gamma) - cos(2.0 * horizons - gamma);
					visibility += dot(arc, vec2(0.25)) * normLen;

					float bentAngle = dot(horizons, vec2(0.5));
					bentNormal 	   += viewDirection * cos(bentAngle) + orthoDir * sin(bentAngle);
				}
				bentNormal = normalize(normalize(bentNormal) - 0.5 * viewDirection);
				return multiBounceApprox(visibility * rcp(GTAO_SLICES));
			}

		#endif

		void main() {
			ao = vec3(0.0, 0.0, 1.0);

			vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
			if(saturate(fragCoords) != fragCoords) { discard; return; }
			
			float depth = texture(depthtex0, vertexCoords).r;

			if(depth == 1.0) return;

			Material material = getMaterial(vertexCoords);
			vec3 viewPosition = screenToView(vec3(textureCoords, depth));

			vec3 bentNormal = vec3(0.0);

			#if AO_TYPE == 0
				ao.b = SSAO(viewPosition, material.normal);
			#elif AO_TYPE == 1
				ao.b = RTAO(viewPosition, material.normal, bentNormal);
			#elif AO_TYPE == 2
				ao.b = GTAO(viewPosition, material.normal, bentNormal);
			#endif

			#if AO_FILTER == 1
				vec3 closestFragment = getClosestFragment(vec3(textureCoords, texture(depthtex0, vertexCoords).r));
				vec2 prevCoords      = vertexCoords + getVelocity(closestFragment).xy * RENDER_SCALE;

				vec3 prevAO = texture(AO_BUFFER, prevCoords).rgb;
		
				float weight = 1.0 / max(texture(ACCUMULATION_BUFFER, prevCoords).a, 1.0);

				#if AO_TYPE == 1 || AO_TYPE == 2
					vec3 prevBentNormal = decodeUnitVector(prevAO.xy);

					ao.xy = encodeUnitVector(mix(prevBentNormal, bentNormal, weight));
				#endif

				ao.b = mix(prevAO.b, ao.b, weight);
			#endif

			ao = saturate(ao);
		}
	#endif
#endif
	