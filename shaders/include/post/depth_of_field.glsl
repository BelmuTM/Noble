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
	[Credits]:
		DrDesten - Providing a tool to generate Vogel disk samples (https://drdesten.github.io/web/tools/vogel_disk/)
*/

#if DOF_SAMPLES == 4

const vec2 vogelDisk[4] = vec2[](
	vec2( 0.218486500, -0.092113702),
	vec2(-0.586611265,  0.321537934),
	vec2(-0.065950785, -0.879656059),
	vec2( 0.434075550,  0.650231826)
);

#elif DOF_SAMPLES == 8

const vec2 vogelDisk[8] = vec2[](
	vec2( 0.292147349,  0.037989425),
	vec2(-0.277142740,  0.330485302),
	vec2( 0.091019815, -0.518887115),
	vec2( 0.444591827,  0.562906982),
	vec2(-0.696387764, -0.092647037),
	vec2( 0.741752281, -0.407041965),
	vec2(-0.191856808,  0.908473229),
	vec2(-0.404123958, -0.821278821)
);

#elif DOF_SAMPLES == 16

const vec2 vogelDisk[16] = vec2[](
	vec2( 0.189936456,  0.027087114),
	vec2(-0.212612426,  0.233912932),
	vec2( 0.047717813, -0.366684064),
	vec2( 0.297730981,  0.398259878),
	vec2(-0.509063425, -0.065286814),
	vec2( 0.507855152, -0.287597600),
	vec2(-0.152306165,  0.642612115),
	vec2(-0.302401706, -0.580507290),
	vec2( 0.697801923,  0.277117333),
	vec2(-0.699096324,  0.321096072),
	vec2( 0.356514260, -0.706641506),
	vec2( 0.266890002,  0.836019104),
	vec2(-0.751586130, -0.416098761),
	vec2( 0.910293744, -0.170145275),
	vec2(-0.534347143,  0.805859345),
	vec2(-0.113327011, -0.949002582)
);

#elif DOF_SAMPLES == 32

const vec2 vogelDisk[32] = vec2[](
	vec2( 0.120644265,  0.015554431),
	vec2(-0.164000779,  0.161802370),
	vec2( 0.020080498, -0.262883839),
	vec2( 0.196866504,  0.278013209),
	vec2(-0.373623291, -0.049763799),
	vec2( 0.345446731, -0.206961264),
	vec2(-0.121357813,  0.450796333),
	vec2(-0.227491388, -0.414079691),
	vec2( 0.479759380,  0.192352495),
	vec2(-0.507996843,  0.223450159),
	vec2( 0.238432559, -0.503270051),
	vec2( 0.175058639,  0.587555727),
	vec2(-0.545112740, -0.297825306),
	vec2( 0.630013788, -0.123909928),
	vec2(-0.391501580,  0.566229557),
	vec2(-0.093795389, -0.674645212),
	vec2( 0.544716022,  0.478312689),
	vec2(-0.743234206,  0.046109375),
	vec2( 0.534599390, -0.520777903),
	vec2(-0.040413920,  0.795345946),
	vec2(-0.517173266, -0.598972361),
	vec2( 0.808003858,  0.124856265),
	vec2(-0.692666375,  0.494463047),
	vec2( 0.183730322, -0.820506950),
	vec2( 0.430677530,  0.774745486),
	vec2(-0.854804145, -0.255761807),
	vec2( 0.821746666, -0.366125831),
	vec2(-0.362243936,  0.870709993),
	vec2(-0.323763069, -0.872479326),
	vec2( 0.845552900,  0.462242590),
	vec2(-0.948390381,  0.264398934),
	vec2( 0.532240073, -0.818975339)
);

#elif DOF_SAMPLES == 64

const vec2 vogelDisk[64] = vec2[](
	vec2( 0.079669140, -0.000573254),
	vec2(-0.121605301,  0.102839654),
	vec2( 0.008559818, -0.197458844),
	vec2( 0.133566402,  0.185013127),
	vec2(-0.269830801, -0.046760219),
	vec2( 0.238628488, -0.157915612),
	vec2(-0.091452171,  0.307189245),
	vec2(-0.166499941, -0.304370457),
	vec2( 0.333601873,  0.124441854),
	vec2(-0.364847250,  0.146431224),
	vec2( 0.162958041, -0.367437565),
	vec2( 0.118145912,  0.403892740),
	vec2(-0.391092153, -0.222166192),
	vec2( 0.439847784, -0.099189449),
	vec2(-0.282472659,  0.388812860),
	vec2(-0.071962593, -0.488618103),
	vec2( 0.379533155,  0.326646247),
	vec2(-0.531185185,  0.021032353),
	vec2( 0.372379616, -0.379817485),
	vec2(-0.034216195,  0.550822613),
	vec2(-0.371335961, -0.435109317),
	vec2( 0.565705769,  0.076714813),
	vec2(-0.495428328,  0.338066274),
	vec2( 0.124277719, -0.591757927),
	vec2( 0.298895764,  0.536255888),
	vec2(-0.610077045, -0.192422807),
	vec2( 0.575423402, -0.270461956),
	vec2(-0.261784381,  0.604113041),
	vec2(-0.234574299, -0.628507946),
	vec2( 0.592256951,  0.315282971),
	vec2(-0.676252507,  0.175386380),
	vec2( 0.370711327, -0.590674915),
	vec2( 0.111979885,  0.701740228),
	vec2(-0.580727015, -0.443568252),
	vec2( 0.722982722, -0.061193264),
	vec2(-0.514479478,  0.546138778),
	vec2(-0.005035179, -0.755754642),
	vec2( 0.505585737,  0.566372882),
	vec2(-0.781014073, -0.072149369),
	vec2( 0.617068100, -0.475523510),
	vec2(-0.151099776,  0.782076266),
	vec2(-0.437603148, -0.682112736),
	vec2( 0.777200925,  0.214814870),
	vec2(-0.742204728,  0.375839404),
	vec2( 0.281142468, -0.782425356),
	vec2( 0.309192261,  0.780368354),
	vec2(-0.778983130, -0.365615702),
	vec2( 0.814544093, -0.254394129),
	vec2(-0.448875737,  0.750475830),
	vec2(-0.193362447, -0.860424622),
	vec2( 0.715458148,  0.513848417),
	vec2(-0.898876568,  0.110365342),
	vec2( 0.578335054, -0.690268690),
	vec2( 0.024600692,  0.913115578),
	vec2(-0.656446164, -0.657849672),
	vec2( 0.921294923,  0.046978992),
	vec2(-0.733042321,  0.597898571),
	vec2( 0.122256115, -0.939339980),
	vec2( 0.533485682,  0.786876017),
	vec2(-0.948368229, -0.216784299),
	vec2( 0.837217542, -0.479847200),
	vec2(-0.311211104,  0.931862347),
	vec2(-0.418816301, -0.899674402),
	vec2( 0.908256660,  0.388454710)
);

#endif

float getCoC(float fragDepth, float targetDepth) {
    if (fragDepth <= handDepth) return 0.0;

    const float maxCoC = 10.0;

    return clamp(abs((FOCAL / F_STOPS) * ((FOCAL * (targetDepth - fragDepth)) / (fragDepth * (targetDepth - FOCAL)))) * 0.5, 0.0, maxCoC);
}

void depthOfField(inout vec3 color, sampler2D colorTex, vec2 coords, float coc) {
    color = vec3(0.0);

    float totalWeight = EPS;

    float distFromCenter = distance(coords, vec2(0.5));

    #if DOF_ABERRATION == 1
        vec2 caOffset = vec2(distFromCenter) * DOF_ABERRATION_STRENGTH * 15.0 * coc * texelSize;
    #endif

    for (int i = 0; i < DOF_SAMPLES; i++) {
        vec2 offset       = vogelDisk[i] * DOF_RADIUS * coc * texelSize;
        vec2 sampleCoords = coords + offset;

        if (saturate(sampleCoords) != sampleCoords) continue;

        #if DOF_ABERRATION == 1
            vec3 sampleColor = vec3(
                texture(colorTex, sampleCoords + caOffset).r,
                texture(colorTex, sampleCoords           ).g,
                texture(colorTex, sampleCoords - caOffset).b
            );
        #else
            vec3 sampleColor = texture(colorTex, sampleCoords).rgb;
        #endif

        sampleColor = exp2(sampleColor) - 1.0;

        float weight = mix(0.3, 1.0, smoothstep(0.2, 1.0, luminance(sampleColor)));

        color       += sampleColor * weight;
        totalWeight += weight;
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
            
            if (saturate(sampleCoords) != sampleCoords) continue;

            #if DOF_ABERRATION == 1
                vec3 sampleColor = vec3(
                    texture(colorTex, sampleCoords + caOffset).r,
                    texture(colorTex, sampleCoords           ).g,
                    texture(colorTex, sampleCoords - caOffset).b
                );
            #else
                vec3 sampleColor = texture(colorTex, sampleCoords).rgb;
            #endif

            sampleColor = exp2(sampleColor) - 1.0;

            color       += sampleColor * weight;
            totalWeight += weight;
        }
    }
    color /= totalWeight;
}
*/
