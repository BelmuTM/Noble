/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2026  Belmu                                                 */
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
        Wikipedia. (2025). Circle of confusion. https://en.wikipedia.org/wiki/Circle_of_confusion
*/

float getCoC(float fragDepth, float targetDepth) {
    const float maxCoC = 2.0;

    return clamp(abs((FOCAL / F_STOPS) * ((FOCAL * (targetDepth - fragDepth)) / (fragDepth * (targetDepth - FOCAL)))) * 0.5, 0.0, maxCoC);
}

void depthOfField(inout vec3 color, sampler2D colorTex, vec2 coords, float coc, float exposure) {
    color = vec3(0.0);

    float totalWeight = EPS;

    float distFromCenter = distance(coords, vec2(0.5));

    #if DOF_ABERRATION == 1
        vec2 caOffset = vec2(distFromCenter) * DOF_ABERRATION_STRENGTH * 10.0 * coc * texelSize;
    #endif

    for (int i = 0; i < DOF_SAMPLES; i++) {
        vec2 offset       = sampleDisk(i, DOF_SAMPLES, randF(), randF()) * DOF_RADIUS * coc * texelSize;
        vec2 sampleCoords = coords + offset;

        if (insideScreenBounds(sampleCoords, 1.0)) {

			#if DOF_ABERRATION == 1

				vec3 sampleColor = vec3(
					texture(colorTex, sampleCoords + caOffset).r,
					texture(colorTex, sampleCoords           ).g,
					texture(colorTex, sampleCoords - caOffset).b
				);

			#else

				vec3 sampleColor = texture(colorTex, sampleCoords).rgb;

			#endif

			sampleColor /= exposure;

			float weight = mix(0.3, 1.0, smoothstep(0.2, 1.0, luminanceAP1(sampleColor)));

			color       += sampleColor * weight;
			totalWeight += weight;

		}
    }

    color /= totalWeight;
}

/*
void depthOfField_deprecated(inout vec3 color, sampler2D colorTex, vec2 coords, float coc) {
    color = vec3(0.0);

    float weight      = pow2(DOF_SAMPLES);
    float totalWeight = EPS;

    float distFromCenter = distance(coords, vec2(0.5));

    #if DOF_ABERRATION == 1
        vec2 caOffset = vec2(distFromCenter) * DOF_ABERRATION_STRENGTH * 0.5 * coc / weight;
    #endif

    for (float angle = 0.0; angle < TAU; angle += TAU / (3 * DOF_SAMPLES)) {
        for (int i = 0; i < 3 * DOF_SAMPLES; i++) {
            vec2 sampleCoords = coords + vec2(cos(angle), sin(angle)) * i * coc * texelSize;
            
            if (insideScreenBounds(sampleCoords, 1.0)) {

				#if DOF_ABERRATION == 1

					vec3 sampleColor = vec3(
						texture(colorTex, sampleCoords + caOffset).r,
						texture(colorTex, sampleCoords           ).g,
						texture(colorTex, sampleCoords - caOffset).b
					);

				#else

					vec3 sampleColor = texture(colorTex, sampleCoords).rgb;

				#endif

				sampleColor /= exposure;

				color       += sampleColor * weight;
				totalWeight += weight;
			}
        }
    }
    color /= totalWeight;
}
*/
