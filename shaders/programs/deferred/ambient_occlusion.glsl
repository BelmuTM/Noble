/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2025  Belmu                                                 */
/*                                                                              */
/*    This program is free software: you can redistribute it and/or modify      */
/*    it under the terms of the GNU General Public License as published by      */
/*    the Free Software Foundation, either version 3 of the License, or         */
/*    (at your option) any later version.                                       */
/*                                                                              */
/*    This program is distributed in the hope that it will be useful,           */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of            */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             */
/*    GNU General Public License for more details.                              */
/*                                                                              */
/*    You should have received a copy of the GNU General Public License         */
/*    along with this program.  If not, see <https://www.gnu.org/licenses/>.    */
/*                                                                              */
/********************************************************************************/

/*
	[References]:
		LearnOpenGL. (2015). SSAO. https://learnopengl.com/Advanced-Lighting/SSAO
		Jimenez et al. (2016). Practical Real-Time Strategies for Accurate Indirect Occlusion. https://www.activision.com/cdn/research/Practical_Real_Time_Strategies_for_Accurate_Indirect_Occlusion_NEW%20VERSION_COLOR.pdf
		Jimenez et al. (2016). Practical Realtime Strategies for Accurate Indirect Occlusion. https://blog.selfshadow.com/publications/s2016-shading-course/activision/s2016_pbs_activision_occlusion.pdf
*/

#include "/settings.glsl"
#include "/include/internal_settings.glsl"

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

		#include "/include/utility/rng.glsl"
		
		#if AO == 1

			float multiBounceApprox(float visibility) { 
				const float albedo = 0.2; 
				return visibility / (albedo * visibility + (1.0 - albedo)); 
 			}

			float findMaximumHorizon(bool dhFragment, vec3 viewPosition, vec3 viewDirection, vec3 normal, vec3 sliceDir, vec2 radius, mat4 projectionInverse) {
				float horizonCos = -1.0;

				vec2 stepSize    = radius * rcp(GTAO_HORIZON_STEPS);
				vec2 increment   = sliceDir.xy * stepSize;
				vec2 rayPosition = textureCoords + rand2F() * increment;

				for (int i = 0; i < GTAO_HORIZON_STEPS; i++, rayPosition += increment) {
					ivec2 coords = ivec2(rayPosition * viewSize * RENDER_SCALE);
					float depth  = dhFragment ? texelFetch(dhDepthTex0, coords, 0).r : texelFetch(depthtex0, coords, 0).r;

					if (saturate(rayPosition) != rayPosition || depth == 1.0 || depth < handDepth) continue;

					vec3 horizonVec = screenToView(vec3(rayPosition, depth), projectionInverse, true) - viewPosition;
					float cosTheta  = mix(dot(horizonVec, viewDirection) * fastRcpLength(horizonVec), -1.0, linearStep(2.0, 3.0, lengthSqr(horizonVec)));
		
					horizonCos = max(horizonCos, cosTheta);
				}
				return fastAcos(horizonCos);
			}

			float GTAO(bool dhFragment, vec3 viewPosition, vec3 normal, mat4 projectionInverse, out vec3 bentNormal) {
				float visibility = 0.0;

				float rcpViewLength = fastRcpLength(viewPosition);
				vec2  radius  		= GTAO_RADIUS * rcpViewLength * rcp(vec2(1.0, aspectRatio));
				vec3  viewDirection = viewPosition * -rcpViewLength;

				float dither = interleavedGradientNoise(gl_FragCoord.xy);

				for (int i = 0; i < GTAO_SLICES; i++) {
					float sliceAngle = PI * rcp(GTAO_SLICES) * (i + dither);
					vec3  sliceDir   = vec3(cos(sliceAngle), sin(sliceAngle), 0.0);

					vec3 orthoDir   = sliceDir - dot(sliceDir, viewDirection) * viewDirection;
					vec3 axis       = cross(sliceDir, viewDirection);
					vec3 projNormal = normal - axis * dot(normal, axis);

					float sgnGamma = sign(dot(projNormal, orthoDir));
					float normLen  = length(projNormal);
					float cosGamma = saturate(dot(projNormal, viewDirection) / normLen);
					float gamma    = sgnGamma * fastAcos(cosGamma);

					vec2 horizons;
					horizons.x = -findMaximumHorizon(dhFragment, viewPosition, viewDirection, normal,-sliceDir, radius, projectionInverse);
					horizons.y =  findMaximumHorizon(dhFragment, viewPosition, viewDirection, normal, sliceDir, radius, projectionInverse);
					horizons   =  gamma + clamp(horizons - gamma, -HALF_PI, HALF_PI);
			
					vec2 arc    = cosGamma + 2.0 * horizons * sin(gamma) - cos(2.0 * horizons - gamma);
					visibility += dot(arc, vec2(0.25)) * normLen;

					float bentAngle = dot(horizons, vec2(0.5));
					bentNormal 	   += viewDirection * cos(bentAngle) + orthoDir * sin(bentAngle);
				}
				bentNormal = normalize(normalize(bentNormal) - 0.5 * viewDirection);
				return multiBounceApprox(visibility * rcp(GTAO_SLICES));
			}

		#elif AO == 2

			float SSAO(bool dhFragment, mat4 projection, vec3 viewPosition, vec3 normal, mat4 projectionInverse) {
				float occlusion = 0.0;

				for (int i = 0; i < SSAO_SAMPLES; i++) {
					vec3 rayDirection = generateCosineVector(normal, rand2F());
					vec3 rayPosition  = viewPosition + rayDirection * SSAO_RADIUS;

					vec2 sampleCoords = viewToScreen(rayPosition, projection, true).xy;

					float sampleDepth;
					if (dhFragment) {
						sampleDepth = texture(dhDepthTex0, sampleCoords * RENDER_SCALE).r;
					} else {
						sampleDepth = texture(depthtex0, sampleCoords * RENDER_SCALE).r;
					}

					float rayDepth = screenToView(vec3(sampleCoords, sampleDepth), projectionInverse, true).z;

					if (rayDepth >= rayPosition.z + EPS) {
						occlusion += quinticStep(0.0, 1.0, SSAO_RADIUS / abs(viewPosition.z - rayDepth));
					}
		    	}
		    	return pow(1.0 - occlusion * rcp(SSAO_SAMPLES), SSAO_STRENGTH);
	    	}

		#elif AO == 3

			#include "/include/fragment/raytracer.glsl"

			float RTAO(bool dhFragment, mat4 projection, vec3 viewPosition, vec3 normal, out vec3 bentNormal) {
				vec3 rayPosition = viewPosition + normal * 1e-2;
				float occlusion  = 1.0;

				vec3 hitPosition = vec3(0.0);

				for (int i = 0; i < RTAO_SAMPLES; i++) {
					vec3 rayDirection = generateCosineVector(normal, rand2F());

					bool hit;
					if (dhFragment) {
						hit = raytrace(dhDepthTex0, projection, rayPosition, rayDirection, RTAO_STEPS, randF(), RENDER_SCALE, hitPosition);
					} else {
						hit = raytrace(depthtex0, projection, rayPosition, rayDirection, RTAO_STEPS, randF(), RENDER_SCALE, hitPosition);
					}

					if (!hit) {
						bentNormal += rayDirection;
						continue;
					}
					occlusion -= rcp(RTAO_SAMPLES);
				}
				bentNormal = normalize(bentNormal);
				return saturate(occlusion);
			}

		#endif

		void main() {
			ao = vec3(0.0, 0.0, 1.0);

			vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
			if (saturate(fragCoords) != fragCoords) { discard; return; }
			
			bool  dhFragment = false;
			float depth      = texture(depthtex0, vertexCoords).r;

			mat4 projection        = gbufferProjection;
			mat4 projectionInverse = gbufferProjectionInverse;

			#if defined DISTANT_HORIZONS
				if (depth >= 1.0) {
					dhFragment = true;
					depth      = texture(dhDepthTex0, vertexCoords).r;
					
					projection        = dhProjection;
					projectionInverse = dhProjectionInverse;
				}
			#endif

			if (depth == 1.0) return;

			Material material = getMaterial(vertexCoords);

			if (depth < handDepth) {
				ao = vec3(encodeUnitVector(material.normal), 1.0);
				return;
			}

			vec3 viewPosition = screenToView(vec3(textureCoords, depth), projectionInverse, true);

			vec3 bentNormal = vec3(0.0);

			#if AO == 1
				ao.b = GTAO(dhFragment, viewPosition, material.normal, projectionInverse, bentNormal);
			#elif AO == 2
				ao.b = SSAO(dhFragment, projection, viewPosition, material.normal, projectionInverse);
			#elif AO == 3
				ao.b = RTAO(dhFragment, projection, viewPosition, material.normal, bentNormal);
			#endif

			#if AO_FILTER == 1
				vec3 currFragment = vec3(textureCoords, depth);

			    vec3 closestFragment;
				if (dhFragment) {
					closestFragment = getClosestFragment(dhDepthTex0, currFragment);
				} else {
					closestFragment = getClosestFragment(depthtex0, currFragment);
				}

				vec2 prevCoords = vertexCoords + getVelocity(closestFragment, projectionInverse).xy * RENDER_SCALE;

				if (clamp(prevCoords, 0.0, RENDER_SCALE) == prevCoords) {
					vec3 prevAO = texture(AO_BUFFER, prevCoords).rgb;
			
					float weight = saturate(1.0 / max(texture(ACCUMULATION_BUFFER, prevCoords).a, 1.0));

					#if AO == 1 || AO == 3
						vec3 prevBentNormal = decodeUnitVector(prevAO.xy);

						ao.xy = encodeUnitVector(mix(prevBentNormal, bentNormal, weight));
					#endif

					ao.b = mix(prevAO.b, ao.b, weight);
				} else {
					ao = vec3(encodeUnitVector(material.normal), 1.0);
				}
			#endif

			ao = saturate(ao);
		}
		
	#endif
#endif
	