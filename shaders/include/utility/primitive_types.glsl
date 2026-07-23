/*
    [Credits]:
        Luracasmus - https://gist.github.com/Luracasmus/ff78f1998a5a440899e1904fa23cc9c6#optional-168-bit-types
        Thanks to them.
*/

#define CONST_IMMUT 1 // [0 1 2]

#if (CONST_IMMUT == 1 && defined MC_GL_VENDOR_NVIDIA) || CONST_IMMUT == 2
	#define immut const
#else
	#define immut
#endif

#define ASSUME_NV_GPU_SHADER5
#define ASSUME_AMD_GPU_SHADER_HALF_FLOAT
#define ASSUME_AMD_GPU_SHADER_INT16

#ifdef ASSUME_NV_GPU_SHADER5
#endif
#ifdef ASSUME_AMD_GPU_SHADER_HALF_FLOAT
#endif
#ifdef ASSUME_AMD_GPU_SHADER_INT16
#endif

#if (defined GL_NV_gpu_shader5 || defined MC_GL_NV_gpu_shader5) || (defined ASSUME_NV_GPU_SHADER5 && defined MC_GL_VENDOR_NVIDIA)
	#extension GL_NV_gpu_shader5 : require
	#define FLOAT16
	#define INT16
	#define INT8
#endif

#if (defined GL_AMD_gpu_shader_half_float || defined MC_GL_AMD_gpu_shader_half_float) || (defined ASSUME_AMD_GPU_SHADER_HALF_FLOAT && defined MC_GL_RENDERER_RADEON && defined MC_OS_WINDOWS && (defined MC_GL_VENDOR_AMD || defined MC_GL_VENDOR_ATI))
	#extension GL_AMD_gpu_shader_half_float : require
	#define FLOAT16

	#define AMD_FLOAT16
#endif

#if defined GL_EXT_shader_explicit_arithmetic_types_float16 || defined MC_GL_EXT_shader_explicit_arithmetic_types_float16
	#extension GL_EXT_shader_explicit_arithmetic_types_float16 : require
	#define FLOAT16

	#define ARITH_FLOAT16
#endif

#if IRIS_VERSION >= 10902
	#if (defined GL_AMD_gpu_shader_int16 || defined MC_GL_AMD_gpu_shader_int16) || (defined ASSUME_AMD_GPU_SHADER_INT16 && defined MC_GL_RENDERER_RADEON && defined MC_OS_WINDOWS && (defined MC_GL_VENDOR_AMD || defined MC_GL_VENDOR_ATI))
		#extension GL_AMD_gpu_shader_int16 : require
		#define INT16
		#define PACK_INT16

		#define AMD_INT16
	#endif

	#if defined AMD_FLOAT16 && defined AMD_INT16
		#define TRANSMUTE_AND_PACK_INT16
	#endif

	#if defined GL_EXT_shader_16bit_storage || defined MC_GL_EXT_shader_16bit_storage
		#extension GL_EXT_shader_16bit_storage : require
		#define FLOAT16 // How does this interact with trinary min/max?
		#define INT16
	#endif

	#if defined GL_EXT_shader_8bit_storage || defined MC_GL_EXT_shader_8bit_storage
		#extension GL_EXT_shader_8bit_storage : require
		#define INT8
	#endif

	#if defined GL_EXT_shader_16bit_storage || defined MC_GL_EXT_shader_explicit_arithmetic_types_int16
		#extension GL_EXT_shader_explicit_arithmetic_types_int16 : require
		#define INT16
		#define PACK_INT16

		#define ARITH_INT16
	#endif

	#if defined ARITH_FLOAT16 && defined ARITH_INT16
		#define TRANSMUTE_AND_PACK_INT16
	#endif

	#if defined GL_EXT_shader_explicit_arithmetic_types_int8 || defined MC_GL_EXT_shader_explicit_arithmetic_types_int8
		#extension GL_EXT_shader_explicit_arithmetic_types_int8 : require
		#define INT8
	#endif
#else
	// Iris < 1.9.2 has issues with 16-bit uint vectors due to a glsl-transformer bug.
	#undef INT16
	#undef INT8
#endif

// 16/8-bit fallback definitions.
// WARN: Possibly don't cover everything!
// We use macro aliases to work around an AMD compiler bug on Windows where the fallback functions collide with nonexistent built-ins.

#ifndef INT16
	#define int16_t int
	#define i16vec2 ivec2
	#define i16vec3 ivec3
	#define i16vec4 ivec4

	#define uint16_t uint
	#define u16vec2 uvec2
	#define u16vec3 uvec3
	#define u16vec4 uvec4

	// Work around Iris bug.
	// https://discord.com/channels/774352792659820594/774354522361299006/1360611068812198001 (The Iris Project)
	#undef INT16
#endif

#ifndef INT8
	#define int8_t int16_t
	#define i8vec2 i16vec2
	#define i8vec3 i16vec3
	#define i8vec4 i16vec4

	#define uint8_t uint16_t
	#define u8vec2 u16vec2
	#define u8vec3 u16vec3
	#define u8vec4 u16vec4
#endif

#ifndef FLOAT16
	#define float16_t float
	#define f16vec2 vec2
	#define f16vec3 vec3
	#define f16vec4 vec4

	#define packFloat2x16(v) _packFloat2x16(v)
	uint _packFloat2x16(vec2 v) { return packHalf2x16(v); }

	#define unpackFloat2x16(v) _unpackFloat2x16(v)
	vec2 _unpackFloat2x16(uint v) { return unpackHalf2x16(v); }
#endif

#ifndef TRANSMUTE_AND_PACK_INT16
	#ifdef PACK_INT16
		#define float16BitsToInt16(v) _float16BitsToInt16(v)
		int16_t _float16BitsToInt16(float16_t v) { return int16_t(packFloat2x16(f16vec2(v, 0.0))); }
		i16vec2 _float16BitsToInt16(f16vec2 v) { return unpackInt2x16(int(packFloat2x16(v))); }
		i16vec3 _float16BitsToInt16(f16vec3 v) { return i16vec3(float16BitsToInt16(v.xy), float16BitsToInt16(v.z)); }
		i16vec4 _float16BitsToInt16(f16vec4 v) { return i16vec4(float16BitsToInt16(v.xy), float16BitsToInt16(v.zw)); }

		#define int16BitsToFloat16(v) _int16BitsToFloat16(v)
		float16_t _int16BitsToFloat16(int16_t v) { return unpackFloat2x16(uint(v)).x; }
		f16vec2 _int16BitsToFloat16(i16vec2 v) { return unpackFloat2x16(uint(packInt2x16(v))); }
		f16vec3 _int16BitsToFloat16(i16vec3 v) { return f16vec3(int16BitsToFloat16(v.xy), int16BitsToFloat16(v.z)); }
		f16vec4 _int16BitsToFloat16(i16vec4 v) { return f16vec4(int16BitsToFloat16(v.xy), int16BitsToFloat16(v.zw)); }
	#else
		#define packUint2x16(v) _packUint2x16(v)
		uint _packUint2x16(u16vec2 v) {
			immut uvec2 v_u32 = uvec2(v);
			return bitfieldInsert(v_u32.x, v_u32.y, 16, 16);
		}

		#define unpackUint2x16(v) _unpackUint2x16(v)
		u16vec2 _unpackUint2x16(uint v) { return u16vec2(v & 65535u, v >> 16u); }
	#endif

	//#define float16BitsToUint16(v) _float16BitsToUint16(v)
	//uint16_t _float16BitsToUint16(float16_t v) { return uint16_t(packFloat2x16(f16vec2(v, 0.0))); }
	//u16vec2 _float16BitsToUint16(f16vec2 v) { return unpackUint2x16(packFloat2x16(v)); }
	//u16vec3 _float16BitsToUint16(f16vec3 v) { return u16vec3(float16BitsToUint16(v.xy), float16BitsToUint16(v.z)); }
	//u16vec4 _float16BitsToUint16(f16vec4 v) { return u16vec4(float16BitsToUint16(v.xy), float16BitsToUint16(v.zw)); }

	//#define uint16BitsToFloat16(v) _uint16BitsToFloat16(v)
	//float16_t _uint16BitsToFloat16(uint16_t v) { return unpackFloat2x16(uint(v)).x; }
	//f16vec2 _uint16BitsToFloat16(u16vec2 v) { return unpackFloat2x16(packUint2x16(v)); }
	//f16vec3 _uint16BitsToFloat16(u16vec3 v) { return f16vec3(uint16BitsToFloat16(v.xy), uint16BitsToFloat16(v.z)); }
	//f16vec4 _uint16BitsToFloat16(u16vec4 v) { return f16vec4(uint16BitsToFloat16(v.xy), uint16BitsToFloat16(v.zw)); }
#endif
