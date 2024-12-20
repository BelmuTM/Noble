/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

const float minExposure = 6e-5;
const float maxExposure = 6e-2;

const float bias = 8.0;

float computeEV100fromLuminance(float luminance) {
    return log2(luminance * bias * sensorSensitivity / calibration);
}

float computeExposureFromEV100(float ev100) {
    return exp2(-ev100);
}

float computeExposure(float averageLuminance) {
	#if MANUAL_CAMERA == 1 || EXPOSURE == 0
		float ev100    = log2(pow2(F_STOPS) / (1.0 / SHUTTER_SPEED) * sensorSensitivity / ISO);
        float exposure = computeExposureFromEV100(ev100);
	#else
		float ev100	   = computeEV100fromLuminance(averageLuminance);
		float exposure = computeExposureFromEV100(ev100);
	#endif

	return clamp(exposure, minExposure, maxExposure);
}
