#version 120

/*
 _______ _________ _______  _______  _
(  ____ \\__   __/(  ___  )(  ____ )( )
| (    \/   ) (   | (   ) || (    )|| |
| (_____    | |   | |   | || (____)|| |
(_____  )   | |   | |   | ||  _____)| |
      ) |   | |   | |   | || (      (_)
/\____) |   | |   | (___) || )       _
\_______)   )_(   (_______)|/       (_)

Do not modify this code until you have read the LICENSE.txt contained in the root directory of this shaderpack!

*/



////////////////////////////////////////////////////ADJUSTABLE VARIABLES/////////////////////////////////////////////////////////

#define NORMAL_MAP_MAX_ANGLE 1.0f   		//The higher the value, the more extreme per-pixel normal mapping (bump mapping) will be.
#define TILE_RESOLUTION 128
//#define ColorTrip

//#define PARALLAX // Doesn't have any visible effect as far as I can tell.

///////////////////////////////////////////////////END OF ADJUSTABLE VARIABLES///////////////////////////////////////////////////

/* DRAWBUFFERS:0126 */

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;
//uniform float wetness;
uniform float wetness;
uniform float frameTimeCounter;
uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 worldPosition;
varying vec4 vertexPos;
varying mat3 tbnMatrix;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 worldNormal;

varying float materialIDs;

varying float distance;
varying float idCheck;

varying float materialIDs2;

varying vec4 shadowPosition;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

const float bump_distance = 78.0f;
const float fademult = 0.1f;

vec4 cubic(float x)
{
    float x2 = x * x;
    float x3 = x2 * x;
    vec4 w;
    w.x =   -x3 + 3*x2 - 3*x + 1;
    w.y =  3*x3 - 6*x2       + 4;
    w.z = -3*x3 + 3*x2 + 3*x + 1;
    w.w =  x3;
    return w / 6.f;
}

vec4 BicubicTexture(in sampler2D tex, in vec2 coord)
{
	int resolution = 64;

	coord *= resolution;

	float fx = fract(coord.x);
    float fy = fract(coord.y);
    coord.x -= fx;
    coord.y -= fy;

    vec4 xcubic = cubic(fx);
    vec4 ycubic = cubic(fy);

    vec4 c = vec4(coord.x - 0.5, coord.x + 1.5, coord.y - 0.5, coord.y + 1.5);
    vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
    vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;

    vec4 sample0 = texture2D(tex, vec2(offset.x, offset.z) / resolution);
    vec4 sample1 = texture2D(tex, vec2(offset.y, offset.z) / resolution);
    vec4 sample2 = texture2D(tex, vec2(offset.x, offset.w) / resolution);
    vec4 sample3 = texture2D(tex, vec2(offset.y, offset.w) / resolution);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix( mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}


vec2 OffsetCoord(in vec2 coord, in vec2 offset, in int level)
{
	int tileResolution = TILE_RESOLUTION;
	ivec2 atlasTiles = ivec2(32, 16);
	ivec2 atlasResolution = tileResolution * atlasTiles;

	coord *= atlasResolution;

	vec2 offsetCoord = coord + mod(offset.xy * atlasResolution, vec2(tileResolution));

	vec2 minCoord = vec2(coord.x - mod(coord.x, tileResolution), coord.y - mod(coord.y, tileResolution));
	vec2 maxCoord = minCoord + tileResolution;

	if (offsetCoord.x > maxCoord.x) {
		offsetCoord.x -= tileResolution;
	} else if (offsetCoord.x < minCoord.x) {
		offsetCoord.x += tileResolution;
	}

	if (offsetCoord.y > maxCoord.y) {
		offsetCoord.y -= tileResolution;
	} else if (offsetCoord.y < minCoord.y) {
		offsetCoord.y += tileResolution;
	}

	offsetCoord /= atlasResolution;

	return offsetCoord;
}

vec3 Get3DNoise(in vec3 pos)
{
	pos.z += 0.0f;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
		 f = f * f * (3.0f - 2.0f * f);

	vec2 uv =  (p.xy + p.z * vec2(17.0f, 37.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f, 37.0f)) + f.xy;
	vec2 coord =  (uv  + 0.5f) / 64.0f;
	vec2 coord2 = (uv2 + 0.5f) / 64.0f;
	vec3 xy1 = texture2D(noisetex, coord).xyz;
	vec3 xy2 = texture2D(noisetex, coord2).xyz;
	return mix(xy1, xy2, vec3(f.z));
}

vec3 Get3DNoiseNormal(in vec3 pos)
{
	float center = Get3DNoise(pos + vec3( 0.0f, 0.0f, 0.0f)).x * 2.0f - 1.0f;
	float left 	 = Get3DNoise(pos + vec3( 0.1f, 0.0f, 0.0f)).x * 2.0f - 1.0f;
	float up     = Get3DNoise(pos + vec3( 0.0f, 0.1f, 0.0f)).x * 2.0f - 1.0f;

	vec3 noiseNormal;
		 noiseNormal.x = center - left;
		 noiseNormal.y = center - up;

		 noiseNormal.x *= 0.2f;
		 noiseNormal.y *= 0.2f;

		 noiseNormal.b = sqrt(1.0f - noiseNormal.x * noiseNormal.x - noiseNormal.g * noiseNormal.g);
		 noiseNormal.b = 0.0f;

	return noiseNormal.xyz;
}


vec3 CalculateRainBump(in vec3 pos)
{



	pos.y += frameTimeCounter * 3.0f;
	pos.xz *= 1.0f;

	pos.y += Get3DNoise(pos.xyz * vec3(1.0f, 0.0f, 1.0f)).y * 2.0f;


	vec3 p = pos;
	vec3 noiseNormal = Get3DNoiseNormal(p);	p.y += 0.25f;
		 noiseNormal += Get3DNoiseNormal(p); p.y += 0.5f;
		 noiseNormal += Get3DNoiseNormal(p); p.y += 0.75f;
		 noiseNormal += Get3DNoiseNormal(p);
		 noiseNormal /= 4.0f;

	return Get3DNoiseNormal(pos).xyz;
}

float GetModulatedRainSpecular(in vec3 pos)
{
	//pos.y += frameTimeCounter * 3.0f;
	pos.xz *= 1.0f;
	pos.y *= 0.2f;

	// pos.y += Get3DNoise(pos.xyz * vec3(1.0f, 0.0f, 1.0f)).x * 2.0f;

	vec3 p = pos;

	float n = Get3DNoise(p).y;
		  n += Get3DNoise(p / 2.0f).x * 2.0f;
		  n += Get3DNoise(p / 4.0f).x * 4.0f;

		  n /= 7.0f;

	return n;
}


vec4 GetTexture(in sampler2D tex, in vec2 coord)
{
	#ifdef PARALLAX
		vec4 t = vec4(0.0f);
		if (distance < 10.0f)
		{
			t = texture2DLod(tex, coord, 0);
		}
		else
		{
			t = texture2D(tex, coord);
		}
		return t;
	#else
		return texture2D(tex, coord);
	#endif
}

vec2 CalculateParallaxCoord(in vec2 coord, in vec3 viewVector)
{
	vec2 parallaxCoord = coord.st;
	const int maxSteps = 112;
	vec3 stepSize = vec3(0.002f, 0.002f, 0.2f);

	float parallaxDepth = 1.0f;

	if (materialIDs > 2.5f && materialIDs < 3.5f)
		parallaxDepth = 2.0f;

	stepSize.xy *= parallaxDepth;


	float heightmap = GetTexture(normals, coord.st).a;

	//if (viewVector.z < 0.0f)
	//{
		vec3 pCoord = vec3(0.0f, 0.0f, 1.0f);

		//make "pop out"
		//pCoord.st += (viewVector.xy * stepSize.xy) / (viewVector.z * stepSize.z);

		if (heightmap < 1.0f)
		{
			vec3 step = viewVector * stepSize;
			float distAngleWeight = ((distance * 0.6f) * (2.1f - viewVector.z)) / 16.0;
				 step *= distAngleWeight;
				 step *= 2.0f;

			float sampleHeight = heightmap;

			for (int i = 0; sampleHeight < pCoord.z && i < 240; ++i)
			{
				//if (heightmap < pCoord.z)
				pCoord.xy = mix(pCoord.xy, pCoord.xy + step.xy, clamp((pCoord.z - sampleHeight) / (stepSize.z * 1.0 * distAngleWeight / (-viewVector.z + 0.05)), 0.0, 1.0));
				pCoord.z += step.z;
				//pCoord += step;
				sampleHeight = GetTexture(normals, OffsetCoord(coord.st, pCoord.st, 0)).a;

			}


			parallaxCoord.xy = OffsetCoord(coord.st, pCoord.st, 0);
		}

	//}

	//parallaxCoord.xy = OffsetCoord(coord.st, viewVector.xy * (1.0f - heightmap) * 0.0045f, 0);

	return parallaxCoord;
}

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;

    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);

    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


void main() {

	vec4 modelView = (gl_ModelViewMatrix * vertexPos);
		 // modelView.x *= aspectRatio;
		 // modelView.z *= 1.4f;
		 // modelView = gl_ProjectionMatrix * modelView;
		 // modelView.xyz /= modelView.w;

		 // modelView.z = -modelView.z;

	vec3 viewVector = normalize(tbnMatrix * modelView.xyz);
		 viewVector.x /= 2.0f;

		 viewVector = normalize(viewVector);

	vec2 parallaxCoord = texcoord.st;
	#ifdef PARALLAX
		if (distance < 10.0f)
		 parallaxCoord = CalculateParallaxCoord(texcoord.st, viewVector);
	#endif

	float height = GetTexture(normals, parallaxCoord).a;


	float w = wetness;



	vec4 spec = GetTexture(specular, parallaxCoord.st);

	float wet = GetModulatedRainSpecular(worldPosition.xyz);

	float wetAngle = dot(worldNormal, vec3(0.0f, 1.0f, 0.0f)) * 0.5f + 0.5f;
	wet *= wetAngle;

	if (abs(materialIDs - 20.0f) < 0.1f || abs(materialIDs - 21.0f) < 0.1f)
	{
		spec.g = 0.0f;
	}
	else
	{
		wet = clamp(wet * 1.5f - 0.2f, 0.0f, 1.0f);
		 spec.g *= max(0.0f, clamp((wet * 1.0f + 0.2f), 0.0f, 1.0f) - (1.0f - w) * 1.0f);
		 spec.b += max(0.0f, (wet) - (1.0f - w) * 1.0f) * w;
		 // spec.g += wet;
		 // spec.b += wet;
	}

	//store lightmap in auxilliary texture. r = torch light. g = lightning. b = sky light.
	vec4 lightmap = vec4(0.0f, 0.0f, 0.0f, 1.0f);

	//Separate lightmap types
	lightmap.r = clamp((lmcoord.s * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
	lightmap.b = clamp((lmcoord.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);

	lightmap.b = pow(lightmap.b, 1.0f);
	lightmap.r = pow(lightmap.r, 3.0f);
	// vec4 clr = color;
	// 	 clr.rgb = clr.rgb / normalize(clr.rbg);
	// 	 clr.rgb *= 0.5f;
	// 	 clr.rgb = vec3(max(color.r, max(color.g, color.b)));

	// float ao = (color.r + color.g + color.b) / 3.0f;

	// float colorDiff = abs(color.r - color.g);
	// 	  colorDiff += abs(color.r - color.b);
	// 	  colorDiff += abs(color.g - color.b);

	// if (colorDiff > 0.001f) {
	// 	ao = 1.0f;
	// }

	// ao = pow(ao, 13.0f);

	 // lightmap.b *= ao;

	 // lightmap.r *= ao * 0.5f + 0.5f;

	 float wetfactor = clamp(lightmap.b * 1.05f - 0.9f, 0.0f, 0.1f) / 0.1f;
	 	   wetfactor *= w;

	 //spec.g += 0.9f;
	 spec.g *= wetfactor;







	vec4 frag2;

	if (distance < bump_distance) {

			vec3 bump = GetTexture(normals, parallaxCoord.st).rgb * 2.0f - 1.0f;

			float bumpmult = clamp(bump_distance * fademult - distance * fademult, 0.0f, 1.0f) * NORMAL_MAP_MAX_ANGLE;
	              bumpmult *= 1.0f - (clamp(spec.g * 1.0f - 0.0f, 0.0f, 1.0f) * 0.97f);

			bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);

			//bump += CalculateRainBump(worldPosition.xyz);

			frag2 = vec4(bump * tbnMatrix * 0.5 + 0.5, 1.0);

	} else {

			frag2 = vec4((normal) * 0.5f + 0.5f, 1.0f);
	}

  vec4 color2 = color;
  color2.rgb = rgb2hsv(color2.rgb);
  if (materialIDs2 >= 1.5 && materialIDs2 <= 2.5) { // Grass block
    if (color2.g > 0.01) {
      color2.r = (102.0 / 255.0);
      color2.g = (194.0 / 255.0);
      color2.b = (81.0 / 255.0);
      color2.rgb = rgb2hsv(color2.rgb);
    }
  }

  if (materialIDs2 >= 50.5 && materialIDs2 <= 51.5) { // Tall grass
  //  if (color2.g > 0.01) {
      color2.r = (102.0 / 255.0);
      color2.g = (194.0 / 255.0);
      color2.b = (81.0 / 255.0);
      color2.rgb = rgb2hsv(color2.rgb);
  //  }
  }

  if (materialIDs2 >= 17.5 && materialIDs2 <= 18.5) { // Leaves
  //  if (color2.g > 0.01) {
      color2.r = (102.0 / 255.0);
      color2.g = (194.0 / 255.0);
      color2.b = (81.0 / 255.0);
      color2.rgb = rgb2hsv(color2.rgb);
  //  }
  }
  color2.rgb = hsv2rgb(color2.rgb);

  //Diffuse
  vec4 albedo = texture2D(texture, texcoord.st) * color2;

		//sunlightVisibility *= clamp(dot(frag2.rgb * 2.0f - 1.0f, normalize(sunPosition.xyz)), 0.0f, 1.0f);

		//albedo.rgb *= sunlightVisibility * 0.8f + 0.2f;

		 //albedo.rgb *= texture2D(normals, parallaxCoord.st, int(mipLevel), false).a;

     #ifdef ColorTrip
		 vec3 noise = Get3DNoise(worldPosition.xyz);

		 albedo.rgb = noise.rgb;
     #endif

	vec3 upVector = normalize(upPosition);

	float darkFactor = clamp(spec.g, 0.0f, 0.2f) / 0.2f;

	//albedo.rgb *= mix(1.0f, 0.9f, darkFactor);
	//albedo.rgb = pow(albedo.rgb, vec3(mix(1.0f, 1.25f, darkFactor)));
	//albedo.rgb = vec3(1.0f);



		float metallicMask = 0.0f;

		if (   abs(materialIDs - 20.0f) < 0.1f
			|| abs(materialIDs - 21.0f) < 0.1f
			|| abs(materialIDs - 22.0f) < 0.1f
			|| abs(materialIDs - 23.0f) < 0.1f) {
			metallicMask = 1.0f;
		}



	float mats_1 = materialIDs;
		  mats_1 += 0.1f;

	// if (abs(materialIDs - 60.0f) < 0.1f)
	// {
	// 	mats_1 = 0.0f;
	// 	albedo.rgb = gl_Fog.color.rgb * 1.0f;
	// }

	gl_FragData[0] = albedo;

	//Depth
	gl_FragData[1] = vec4(mats_1/255.0f, lightmap.r, lightmap.b, 1.0f);

	//normal
	gl_FragData[2] = frag2;

	//specularity
	//gl_FragData[3] = vec4(spec.r + spec.g, spec.b, 0.0f, 1.0f);

  gl_FragData[3] = vec4(shadowPosition.xyz, 1.0);

}
