/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

out vec3 color;

in vec2 textureCoords;

#include "/include/common.glsl"

#if UNDERWATER_DISTORTION == 1
    void underwaterDistortion(inout vec2 coords) {
        float speed   = frameTimeCounter * WATER_DISTORTION_SPEED;
        float offsetX = coords.x * 25.0 + speed;
        float offsetY = coords.y * 25.0 + speed;

        vec2 distorted = coords + vec2(
            WATER_DISTORTION_AMPLITUDE * cos(offsetX + offsetY) * 0.01 * cos(offsetY),
            WATER_DISTORTION_AMPLITUDE * sin(offsetX - offsetY) * 0.01 * sin(offsetY)
        );
        coords = saturate(distorted) != distorted ? coords : distorted;
    }
#endif

#if LUT > 0 || CEL_SHADING == 1
    const int lutTileSize = 8;
    const int lutSize     = lutTileSize  * lutTileSize;
    const vec2 lutRes     = vec2(lutSize * lutTileSize);

    const float rcpLutTileSize = 1.0 / lutTileSize;
    const vec2  rcpLutTexSize  = 1.0 / lutRes;

    #include "/include/utility/sampling.glsl"

    // https://developer.nvidia.com/gpugems/gpugems2/part-iii-high-quality-rendering/chapter-24-using-lookup-tables-accelerate-color
    void applyLUT(sampler2D lookupTable, inout vec3 color) {
        color = clamp(color, vec3(0.02745098039), vec3(0.96862745098));

        #if DEBUG_LUT == 1
            if(all(lessThan(gl_FragCoord.xy, ivec2(256)))) {
                color = texture(lookupTable, gl_FragCoord.xy * rcpLutTexSize * 2.0).rgb;
                return;
            }
        #endif

        color.b *= (lutSize - 1.0);
        int bL   = int(color.b);
        int bH   = bL + 1;

        vec2 offLo = vec2(bL % lutTileSize, bL / lutTileSize) * rcpLutTileSize;
        vec2 offHi = vec2(bH % lutTileSize, bH / lutTileSize) * rcpLutTileSize;

        color = mix(
            textureLodLinearRGB(lookupTable, offLo + color.rg * rcpLutTileSize, lutRes, 0).rgb,
            textureLodLinearRGB(lookupTable, offHi + color.rg * rcpLutTileSize, lutRes, 0).rgb,
            color.b - bL
        );
    }
#endif

#if SHARPEN == 1
    /*
        SOURCES / CREDITS:
        spolsh: https://www.shadertoy.com/view/XlSBRW
    */

    void sharpeningFilter(inout vec3 color, vec2 coords) {
        float avgLuma = 0.0, weight = 0.0;

        for(int x = -1; x <= 1; x++) {
            for(int y = -1; y <= 1; y++, weight++) {
                avgLuma += luminance(texture(MAIN_BUFFER, coords + vec2(x, y) * texelSize).rgb);
            }
        }
        avgLuma /= weight;

        float centerLuma = luminance(color);
        color *= (centerLuma + (centerLuma - avgLuma) * SHARPEN_STRENGTH) / centerLuma;
    }
#endif

#if EIGHT_BITS_FILTER == 1
    void quantizeColor(inout vec3 color, float quantizationPeriod) {
        color = floor((color + quantizationPeriod * 0.5) / quantizationPeriod) * quantizationPeriod;
    }

    void ditherColor(inout vec3 color, float quantizationPeriod) {
        color += (bayer2(gl_FragCoord.xy) - 0.5) * quantizationPeriod;
    }
#endif

#if CEL_SHADING == 1
    void celShading(inout vec3 color) {
        float luminance = luminance(color);
	          color    /= luminance / (floor(luminance * CEL_SHADES) / CEL_SHADES);
    }
#endif

/*
const vec3 turboCurve[] = vec3[](vec3(0.18995, 0.07176, 0.23217), vec3(0.19483, 0.08339, 0.26149), vec3(0.19956, 0.09498, 0.29024), vec3(0.20415, 0.10652, 0.31844), vec3(0.20860, 0.11802, 0.34607), vec3(0.21291, 0.12947, 0.37314), vec3(0.21708, 0.14087, 0.39964), vec3(0.22111, 0.15223, 0.42558), vec3(0.22500, 0.16354, 0.45096), vec3(0.22875, 0.17481, 0.47578), vec3(0.23236, 0.18603, 0.50004), vec3(0.23582, 0.19720, 0.52373), vec3(0.23915, 0.20833, 0.54686), vec3(0.24234, 0.21941, 0.56942), vec3(0.24539, 0.23044, 0.59142), vec3(0.24830, 0.24143, 0.61286), vec3(0.25107, 0.25237, 0.63374), vec3(0.25369, 0.26327, 0.65406), vec3(0.25618, 0.27412, 0.67381), vec3(0.25853, 0.28492, 0.69300), vec3(0.26074, 0.29568, 0.71162), vec3(0.26280, 0.30639, 0.72968), vec3(0.26473, 0.31706, 0.74718), vec3(0.26652, 0.32768, 0.76412), vec3(0.26816, 0.33825, 0.78050), vec3(0.26967, 0.34878, 0.79631), vec3(0.27103, 0.35926, 0.81156), vec3(0.27226, 0.36970, 0.82624), vec3(0.27334, 0.38008, 0.84037), vec3(0.27429, 0.39043, 0.85393), vec3(0.27509, 0.40072, 0.86692), vec3(0.27576, 0.41097, 0.87936), vec3(0.27628, 0.42118, 0.89123), vec3(0.27667, 0.43134, 0.90254), vec3(0.27691, 0.44145, 0.91328), vec3(0.27701, 0.45152, 0.92347), vec3(0.27698, 0.46153, 0.93309), vec3(0.27680, 0.47151, 0.94214), vec3(0.27648, 0.48144, 0.95064), vec3(0.27603, 0.49132, 0.95857), vec3(0.27543, 0.50115, 0.96594), vec3(0.27469, 0.51094, 0.97275), vec3(0.27381, 0.52069, 0.97899), vec3(0.27273, 0.53040, 0.98461), vec3(0.27106, 0.54015, 0.98930), vec3(0.26878, 0.54995, 0.99303), vec3(0.26592, 0.55979, 0.99583), vec3(0.26252, 0.56967, 0.99773), vec3(0.25862, 0.57958, 0.99876), vec3(0.25425, 0.58950, 0.99896), vec3(0.24946, 0.59943, 0.99835), vec3(0.24427, 0.60937, 0.99697), vec3(0.23874, 0.61931, 0.99485), vec3(0.23288, 0.62923, 0.99202), vec3(0.22676, 0.63913, 0.98851), vec3(0.22039, 0.64901, 0.98436), vec3(0.21382, 0.65886, 0.97959), vec3(0.20708, 0.66866, 0.97423), vec3(0.20021, 0.67842, 0.96833), vec3(0.19326, 0.68812, 0.96190), vec3(0.18625, 0.69775, 0.95498), vec3(0.17923, 0.70732, 0.94761), vec3(0.17223, 0.71680, 0.93981), vec3(0.16529, 0.72620, 0.93161), vec3(0.15844, 0.73551, 0.92305), vec3(0.15173, 0.74472, 0.91416), vec3(0.14519, 0.75381, 0.90496), vec3(0.13886, 0.76279, 0.89550), vec3(0.13278, 0.77165, 0.88580), vec3(0.12698, 0.78037, 0.87590), vec3(0.12151, 0.78896, 0.86581), vec3(0.11639, 0.79740, 0.85559), vec3(0.11167, 0.80569, 0.84525), vec3(0.10738, 0.81381, 0.83484), vec3(0.10357, 0.82177, 0.82437), vec3(0.10026, 0.82955, 0.81389), vec3(0.09750, 0.83714, 0.80342), vec3(0.09532, 0.84455, 0.79299), vec3(0.09377, 0.85175, 0.78264), vec3(0.09287, 0.85875, 0.77240), vec3(0.09267, 0.86554, 0.76230), vec3(0.09320, 0.87211, 0.75237), vec3(0.09451, 0.87844, 0.74265), vec3(0.09662, 0.88454, 0.73316), vec3(0.09958, 0.89040, 0.72393), vec3(0.10342, 0.89600, 0.71500), vec3(0.10815, 0.90142, 0.70599), vec3(0.11374, 0.90673, 0.69651), vec3(0.12014, 0.91193, 0.68660), vec3(0.12733, 0.91701, 0.67627), vec3(0.13526, 0.92197, 0.66556), vec3(0.14391, 0.92680, 0.65448), vec3(0.15323, 0.93151, 0.64308), vec3(0.16319, 0.93609, 0.63137), vec3(0.17377, 0.94053, 0.61938), vec3(0.18491, 0.94484, 0.60713), vec3(0.19659, 0.94901, 0.59466), vec3(0.20877, 0.95304, 0.58199), vec3(0.22142, 0.95692, 0.56914), vec3(0.23449, 0.96065, 0.55614), vec3(0.24797, 0.96423, 0.54303), vec3(0.26180, 0.96765, 0.52981), vec3(0.27597, 0.97092, 0.51653), vec3(0.29042, 0.97403, 0.50321), vec3(0.30513, 0.97697, 0.48987), vec3(0.32006, 0.97974, 0.47654), vec3(0.33517, 0.98234, 0.46325), vec3(0.35043, 0.98477, 0.45002), vec3(0.36581, 0.98702, 0.43688), vec3(0.38127, 0.98909, 0.42386), vec3(0.39678, 0.99098, 0.41098), vec3(0.41229, 0.99268, 0.39826), vec3(0.42778, 0.99419, 0.38575), vec3(0.44321, 0.99551, 0.37345), vec3(0.45854, 0.99663, 0.36140), vec3(0.47375, 0.99755, 0.34963), vec3(0.48879, 0.99828, 0.33816), vec3(0.50362, 0.99879, 0.32701), vec3(0.51822, 0.99910, 0.31622), vec3(0.53255, 0.99919, 0.30581), vec3(0.54658, 0.99907, 0.29581), vec3(0.56026, 0.99873, 0.28623), vec3(0.57357, 0.99817, 0.27712), vec3(0.58646, 0.99739, 0.26849), vec3(0.59891, 0.99638, 0.26038), vec3(0.61088, 0.99514, 0.25280), vec3(0.62233, 0.99366, 0.24579), vec3(0.63323, 0.99195, 0.23937), vec3(0.64362, 0.98999, 0.23356), vec3(0.65394, 0.98775, 0.22835), vec3(0.66428, 0.98524, 0.22370), vec3(0.67462, 0.98246, 0.21960), vec3(0.68494, 0.97941, 0.21602), vec3(0.69525, 0.97610, 0.21294), vec3(0.70553, 0.97255, 0.21032), vec3(0.71577, 0.96875, 0.20815), vec3(0.72596, 0.96470, 0.20640), vec3(0.73610, 0.96043, 0.20504), vec3(0.74617, 0.95593, 0.20406), vec3(0.75617, 0.95121, 0.20343), vec3(0.76608, 0.94627, 0.20311), vec3(0.77591, 0.94113, 0.20310), vec3(0.78563, 0.93579, 0.20336), vec3(0.79524, 0.93025, 0.20386), vec3(0.80473, 0.92452, 0.20459), vec3(0.81410, 0.91861, 0.20552), vec3(0.82333, 0.91253, 0.20663), vec3(0.83241, 0.90627, 0.20788), vec3(0.84133, 0.89986, 0.20926), vec3(0.85010, 0.89328, 0.21074), vec3(0.85868, 0.88655, 0.21230), vec3(0.86709, 0.87968, 0.21391), vec3(0.87530, 0.87267, 0.21555), vec3(0.88331, 0.86553, 0.21719), vec3(0.89112, 0.85826, 0.21880), vec3(0.89870, 0.85087, 0.22038), vec3(0.90605, 0.84337, 0.22188), vec3(0.91317, 0.83576, 0.22328), vec3(0.92004, 0.82806, 0.22456), vec3(0.92666, 0.82025, 0.22570), vec3(0.93301, 0.81236, 0.22667), vec3(0.93909, 0.80439, 0.22744), vec3(0.94489, 0.79634, 0.22800), vec3(0.95039, 0.78823, 0.22831), vec3(0.95560, 0.78005, 0.22836), vec3(0.96049, 0.77181, 0.22811), vec3(0.96507, 0.76352, 0.22754), vec3(0.96931, 0.75519, 0.22663), vec3(0.97323, 0.74682, 0.22536), vec3(0.97679, 0.73842, 0.22369), vec3(0.98000, 0.73000, 0.22161), vec3(0.98289, 0.72140, 0.21918), vec3(0.98549, 0.71250, 0.21650), vec3(0.98781, 0.70330, 0.21358), vec3(0.98986, 0.69382, 0.21043), vec3(0.99163, 0.68408, 0.20706), vec3(0.99314, 0.67408, 0.20348), vec3(0.99438, 0.66386, 0.19971), vec3(0.99535, 0.65341, 0.19577), vec3(0.99607, 0.64277, 0.19165), vec3(0.99654, 0.63193, 0.18738), vec3(0.99675, 0.62093, 0.18297), vec3(0.99672, 0.60977, 0.17842), vec3(0.99644, 0.59846, 0.17376), vec3(0.99593, 0.58703, 0.16899), vec3(0.99517, 0.57549, 0.16412), vec3(0.99419, 0.56386, 0.15918), vec3(0.99297, 0.55214, 0.15417), vec3(0.99153, 0.54036, 0.14910), vec3(0.98987, 0.52854, 0.14398), vec3(0.98799, 0.51667, 0.13883), vec3(0.98590, 0.50479, 0.13367), vec3(0.98360, 0.49291, 0.12849), vec3(0.98108, 0.48104, 0.12332), vec3(0.97837, 0.46920, 0.11817), vec3(0.97545, 0.45740, 0.11305), vec3(0.97234, 0.44565, 0.10797), vec3(0.96904, 0.43399, 0.10294), vec3(0.96555, 0.42241, 0.09798), vec3(0.96187, 0.41093, 0.09310), vec3(0.95801, 0.39958, 0.08831), vec3(0.95398, 0.38836, 0.08362), vec3(0.94977, 0.37729, 0.07905), vec3(0.94538, 0.36638, 0.07461), vec3(0.94084, 0.35566, 0.07031), vec3(0.93612, 0.34513, 0.06616), vec3(0.93125, 0.33482, 0.06218), vec3(0.92623, 0.32473, 0.05837), vec3(0.92105, 0.31489, 0.05475), vec3(0.91572, 0.30530, 0.05134), vec3(0.91024, 0.29599, 0.04814), vec3(0.90463, 0.28696, 0.04516), vec3(0.89888, 0.27824, 0.04243), vec3(0.89298, 0.26981, 0.03993), vec3(0.88691, 0.26152, 0.03753), vec3(0.88066, 0.25334, 0.03521), vec3(0.87422, 0.24526, 0.03297), vec3(0.86760, 0.23730, 0.03082), vec3(0.86079, 0.22945, 0.02875), vec3(0.85380, 0.22170, 0.02677), vec3(0.84662, 0.21407, 0.02487), vec3(0.83926, 0.20654, 0.02305), vec3(0.83172, 0.19912, 0.02131), vec3(0.82399, 0.19182, 0.01966), vec3(0.81608, 0.18462, 0.01809), vec3(0.80799, 0.17753, 0.01660), vec3(0.79971, 0.17055, 0.01520), vec3(0.79125, 0.16368, 0.01387), vec3(0.78260, 0.15693, 0.01264), vec3(0.77377, 0.15028, 0.01148), vec3(0.76476, 0.14374, 0.01041), vec3(0.75556, 0.13731, 0.00942), vec3(0.74617, 0.13098, 0.00851), vec3(0.73661, 0.12477, 0.00769), vec3(0.72686, 0.11867, 0.00695), vec3(0.71692, 0.11268, 0.00629), vec3(0.70680, 0.10680, 0.00571), vec3(0.69650, 0.10102, 0.00522), vec3(0.68602, 0.09536, 0.00481), vec3(0.67535, 0.08980, 0.00449), vec3(0.66449, 0.08436, 0.00424), vec3(0.65345, 0.07902, 0.00408), vec3(0.64223, 0.07380, 0.00401), vec3(0.63082, 0.06868, 0.00401), vec3(0.61923, 0.06367, 0.00410), vec3(0.60746, 0.05878, 0.00427), vec3(0.59550, 0.05399, 0.00453), vec3(0.58336, 0.04931, 0.00486), vec3(0.57103, 0.04474, 0.00529), vec3(0.55852, 0.04028, 0.00579), vec3(0.54583, 0.03593, 0.00638), vec3(0.53295, 0.03169, 0.00705), vec3(0.51989, 0.02756, 0.00780), vec3(0.50664, 0.02354, 0.00863), vec3(0.49321, 0.01963, 0.00955), vec3(0.47960, 0.01583, 0.01055));

vec3 interpolateTurbo(float x) {
    x = saturate(x) * 255.0;
    return turboCurve[int(x)] + (turboCurve[min(255, int(x) + 1)] - turboCurve[int(x)]) * fract(x);
}
*/

void main() {
    vec2 distortCoords = textureCoords;

    #if UNDERWATER_DISTORTION == 1
        if(isEyeInWater == 1) underwaterDistortion(distortCoords);
    #endif

    color = texture(MAIN_BUFFER, distortCoords).rgb;

    #if SHARPEN == 1
        sharpeningFilter(color, distortCoords);
    #endif

    #if LUT > 0
        applyLUT(LUT_BUFFER, color);
    #endif

    #if FILM_GRAIN == 1
        color += randF() * color * FILM_GRAIN_STRENGTH;
    #endif

    #if VIGNETTE == 1
        vec2 coords = textureCoords * (1.0 - textureCoords.yx);
        color      *= pow(coords.x * coords.y * 15.0, VIGNETTE_STRENGTH);
    #endif

    #if CEL_SHADING == 1
        applyLUT(LUT_BUFFER, color);
        celShading(color);
    #endif

    #if EIGHT_BITS_FILTER == 1
        const int   colorPaletteSize   = 2;
        const float quantizationPeriod = 1.0 / colorPaletteSize;

        ditherColor  (color, quantizationPeriod);
        quantizeColor(color, quantizationPeriod);
    #else
        #if CEL_SHADING == 0
            color += bayer8(gl_FragCoord.xy) * rcpMaxVal8;
        #endif
    #endif
}
