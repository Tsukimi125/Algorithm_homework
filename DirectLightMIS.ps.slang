/***************************************************************************
 # Copyright (c) 2015-23, NVIDIA CORPORATION. All rights reserved.
 #
 # Redistribution and use in source and binary forms, with or without
 # modification, are permitted provided that the following conditions
 # are met:
 #  * Redistributions of source code must retain the above copyright
 #    notice, this list of conditions and the following disclaimer.
 #  * Redistributions in binary form must reproduce the above copyright
 #    notice, this list of conditions and the following disclaimer in the
 #    documentation and/or other materials provided with the distribution.
 #  * Neither the name of NVIDIA CORPORATION nor the names of its
 #    contributors may be used to endorse or promote products derived
 #    from this software without specific prior written permission.
 #
 # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS "AS IS" AND ANY
 # EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 # IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 # PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 # CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 # PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 # PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 # OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 # (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 # OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 **************************************************************************/
cbuffer ToyCB
{
    float2 iResolution;
    float iGlobalTime;
};

float rand(float n)
{
    return frac(sin(n) * 43758.5453123);
}

float2 rand2(float2 p)
{
    return frac(float2(sin(p.x * 591.32 + p.y * 154.077), cos(p.x * 391.32 + p.y * 49.077)));
}

static float seed = 0.0;

float randSeed()
{
    return frac(sin(seed++) * 43758.5453123);
}

//used macros and constants
#define HALF_PI 			1.5707963
#define PI 					3.1415926
#define TWO_PI 				6.2831852
#define FOUR_PI 			12.566370
#define INV_PI 				0.3183099
#define INV_TWO_PI 			0.1591549
#define INV_FOUR_PI 		0.0795775
#define EPSILON 			0.0001

//sampling types
#define SAMPLING_LIGHT				0
#define SAMPLING_BSDF				1
#define SAMPLING_LIGHT_AND_BSDF_MIS	2
#define SAMPLING_NONE				3
static int samplingTechnique = 2;

//sampling info
#define BSDF_SAMPLES 1
#define LIGHT_SAMPLES 1
#define MIS_HEURISTIC_POWER

//materials info
#define MATERIAL_COUNT 		8
#define BSDF_COUNT 			3
#define BSDF_R_DIFFUSE 		0
#define BSDF_R_GLOSSY 		1
#define BSDF_R_LIGHT 		2
// 场景设置
struct Ray
{
    float3 origin;
    float3 dir;
};
struct Camera
{
    float3x3 rotate;
    float3 pos;
    float fovV;
};
// 几何体
struct Sphere
{
    float3 pos;
    float radius;
    float radiusSq;
    float area;
};
struct Plane
{
    float4 abcd;
};
struct Range
{
    float min_;
    float max_;
};
// 光线与场景交互
struct RaySurfaceHit
{
    float3 N;
    float3 E;
    int mtl_id;
    int obj_id;
    float dist;
};
struct LightSamplingRecord
{
    float3 w;
    float d;
    float pdf;
};
// 材质
struct Material
{
    float3 color;
    float roughness_;
    int bsdf_;
};

#define WALL_COUNT 2
#define LIGHT_COUNT 4
#define PLANE_COUNT 3
#define LIGHT_COUNT_INV 0.25

static float planeHalfWidth = 2.3;

static Sphere light1 = { float3(-2.0, 1.4, -5.0), 0.05, 0.0025, 0.0314159 };
static Sphere light2 = { float3(-1.1, 1.4, -5.0), 0.2, 0.04, 0.5026548 };
static Sphere light3 = { float3(0.0, 1.4, -5.0), 0.4, 0.16, 2.0106193 };
static Sphere light4 = { float3(1.6, 1.4, -5.0), 0.8, 0.64, 8.0424770 };

Sphere getLight(int index)
{
    if(index == 0)
        return light1;
    else if(index == 1)
        return light2;
    else if(index == 2)
        return light3;
    return light4;
};

static Plane wall1 = { float4(0.0, 1.0, 0.0, 1.0) };
static Plane wall2 = { float4(0.0, 0.0, 1.0, 6.2) };

Plane getWall(int index) 
{
    if(index == 0)
        return wall1;
    return wall2;
};

static Plane plane1 = { float4(normalize(float3(0.0, 1.0, 1.2)), 3.8) };
static Plane plane2 = { float4(normalize(float3(0.0, 1.0, 0.7)), 2.8) };
static Plane plane3 = { float4(normalize(float3(0.0, 1.0, 0.3)), 1.8) };

Plane getPlane(int index)
{
    if(index == 0)
        return plane1;
    else if(index == 1)
        return plane2;
    return plane3;
};
    
static Range planeZRange1 = { -5.8, -5.0 };
static Range planeZRange2 = { -4.8, -4.0 };
static Range planeZRange3 = { -3.8, -3.0 };

Range getPlaneZRange(int index)
{
    if(index == 0)
        return planeZRange1;
    else if(index == 1)
        return planeZRange2;
    return planeZRange3;
};

static Material material1 = { float3(1.0, 1.0, 1.0), 0.0, BSDF_R_DIFFUSE };
static Material material2 = { float3(0.8, 0.8, 0.8), 4096.0, BSDF_R_GLOSSY };
static Material material3 = { float3(0.8, 0.8, 0.8), 128.0, BSDF_R_GLOSSY };
static Material material4 = { float3(0.8, 0.8, 0.8), 32.0, BSDF_R_GLOSSY };

float3 hsv2rgb(float3 c)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

//lights
static float totalIntencity = 6.0;
static float min_x = light1.pos.x;
static float max_x = light4.pos.x;
static float x_range = max_x - min_x;
static float h1 = ((light1.pos.x - min_x) / x_range) * 0.6;
static float h2 = ((light2.pos.x - min_x) / x_range) * 0.6;
static float h3 = ((light3.pos.x - min_x) / x_range) * 0.6;
static float h4 = ((light4.pos.x - min_x) / x_range) * 0.6;
static float s = 0.7;
static float v1 = 1.0 / (FOUR_PI * light1.radiusSq);
static float v2 = 1.0 / (FOUR_PI * light2.radiusSq);
static float v3 = 1.0 / (FOUR_PI * light3.radiusSq);
static float v4 = 1.0 / (FOUR_PI * light4.radiusSq);

static Material material5 = { hsv2rgb(float3(h1, s, v1)) * totalIntencity, 0.0, BSDF_R_LIGHT };
static Material material6 = { hsv2rgb(float3(h2, s, v2)) * totalIntencity, 0.0, BSDF_R_LIGHT };
static Material material7 = { hsv2rgb(float3(h3, s, v3)) * totalIntencity, 0.0, BSDF_R_LIGHT };
static Material material8 = { hsv2rgb(float3(h4, s, v4)) * totalIntencity, 0.0, BSDF_R_LIGHT };

Material getMaterialFromLibrary(int index)
{
    if(index == 0)
        return material1;
    else if(index == 1)
        return material2;
    else if(index == 2)
        return material3;
    else if(index == 3)
        return material4;
    else if(index == 4)
        return material5;
    else if(index == 5)
        return material6;
    else if(index == 6)
        return material7;
    return material8;
}

bool raySphereIntersection(Ray ray, in Sphere sph, out float t)
{
    t = -1.0;
    float3 ce = ray.origin - sph.pos;
    float b = dot(ray.dir, ce);
    float c = dot(ce, ce) - sph.radius * sph.radius;
    float h = b * b - c;
    if (h > 0.0)
    {
        t = -b - sqrt(h);
    }
    return (t > 0.0);
}

bool rayPlaneIntersection(Ray ray, Plane plane, out float t)
{
    float dotVN = dot(ray.dir, plane.abcd.xyz);
   
    if (abs(dotVN) < EPSILON)
    {
        return false;
    }
    
    t = -(dot(ray.origin, plane.abcd.xyz) + plane.abcd.w) / dotVN;
    
    return (t > 0.0);
}

void initCamera(in float3 pos, in float3 frontDir, in float3 upDir, in float fovV, out Camera dst)
{
    float3 back = normalize(-frontDir);
    float3 right = normalize(cross(upDir, back));
    float3 up = cross(back, right);
    dst.rotate[0] = -right;
    dst.rotate[1] = up;
    dst.rotate[2] = back;
    dst.fovV = fovV;
    dst.pos = pos;
}

Ray genRay(in Camera camera, in float2 pixel)
{
    float2 iPlaneSize = 2. * tan(0.5 * camera.fovV) * float2(iResolution.x / iResolution.y, 1.);
    float2 ixy = (pixel / iResolution.xy - 0.5) * iPlaneSize;
    
    Ray ray;
    ray.origin = camera.pos;
    ray.dir = mul(camera.rotate, normalize(float3(ixy.x, ixy.y, -1.0)));

    return ray;
}

bool raySceneIntersection(in Ray ray, in float distMin, out RaySurfaceHit hit)
{
    hit.obj_id = -1;
    hit.dist = 1000.0;
    hit.E = ray.dir * (-1.0);
    //check lights
    for (int i1 = 0; i1 < LIGHT_COUNT; i1++)
    {
        float dist;
        if (raySphereIntersection(ray, getLight(i1), dist) && (dist > distMin) && (dist < hit.dist))
        {
            hit.dist = dist;
            float3 hitpos = ray.origin + ray.dir * hit.dist;
            hit.N = (hitpos - getLight(i1).pos) * (1.0 / getLight(i1).radius);
            hit.mtl_id = 4 + i1;
            hit.obj_id = i1;
        }
    }
    
    //check walls
    for (int i = 0; i < WALL_COUNT; i++)
    {
        float dist;
        if (rayPlaneIntersection(ray, getWall(i), dist) && (dist > distMin) && (dist < hit.dist))
        {
            hit.dist = dist;
//            hit.pos = ray.origin + ray.dir*hit.dist;
            hit.N = getWall(i).abcd.xyz;
            hit.mtl_id = 0;
            hit.obj_id = LIGHT_COUNT + i;
        }
    }
    
    for( int i2 = 0; i2 < PLANE_COUNT; i2++ ){
        float dist;
        if( rayPlaneIntersection( ray, getPlane(i2), dist ) && (dist>distMin) && (dist < hit.dist ) ){
            float3 hitPos = ray.origin + ray.dir*dist;
            if( (hitPos.z < getPlaneZRange(i2).max_ ) && (hitPos.z > getPlaneZRange(i2).min_) && (hitPos.x < planeHalfWidth ) && (hitPos.x > -planeHalfWidth ) ) {
                hit.dist = dist;
                // hit.pos = hitPos;
                hit.N = getPlane(i2).abcd.xyz;
                hit.mtl_id = 1+i2;
                hit.obj_id = LIGHT_COUNT + WALL_COUNT + i2;
            }
        }
    }
    
    return (hit.obj_id != -1);

}


/***********************************************
* Sample Tool Functions
************************************************/
void basis(in float3 n, out float3 b1, out float3 b2)
{
    float sign_ = sign(n.z);
    float a = -1.0 / (sign_ + n.z);
    float b = n.x * n.y * a;
    b1 = float3(1.0 + sign_ * n.x * n.x * a, sign_ * b, -sign_ * n.x);
    b2 = float3(b, sign_ + n.y * n.y * a, -n.y);
}

float3 localToWorld(in float3 localDir, in float3 normal)
{
    float3 a, b;
    basis(normal, a, b);
    return localDir.x * a + localDir.y * b + localDir.z * normal;
}

float3 sphericalToCartesian(in float rho, in float phi, in float theta)
{
    float sinTheta = sin(theta);
    return float3(sinTheta * cos(phi), sinTheta * sin(phi), cos(theta)) * rho;
}

float3 sampleHemisphereCosWeighted(in float3 n, in float Xi1, in float Xi2)
{
    float theta = acos(sqrt(1.0 - Xi1));
    float phi = TWO_PI * Xi2;

    return localToWorld(sphericalToCartesian(1.0, phi, theta), n);
}

float evaluateBlinn(in float3 N, in float3 E, in float3 L, in float roughness)
{
    float3 H = normalize(E + L);
    float cosTheta = dot(N, H);
    return (roughness + 2.0) / (8.0 * PI) * pow(cosTheta, roughness);
}

float pdfBlinn(in float3 N, in float3 E, in float3 L, in float roughness)
{
    float3 H = normalize(E + L);
    float cosTheta = dot(N, H);
    float normalizationFactor = (roughness + 1.0) / TWO_PI;
    return pow(cosTheta, roughness) * normalizationFactor / (4.0 * dot(E, H));
}

float3 sampleBlinn(in float3 N, in float3 E, in float roughness, in float r1, in float r2, out float pdf)
{
    float cosTheta = pow(r1, 1.0 / (roughness));
    float phi = r2 * TWO_PI;
    float theta = acos(cosTheta);
    float3 H = localToWorld(sphericalToCartesian(1.0, phi, theta), N);
    float dotNH = dot(H, N);
    float3 L = reflect(E * (-1.0), H);
    
    pdf = pdfBlinn(N, E, L, roughness);
    
    return L;
}

float evaluateLambertian(in float3 N, in float3 L)
{
    return INV_PI;
}

float pdfLambertian(in float3 N, in float3 L)
{
    return max(.0, dot(N, L)) * INV_PI;
}

float3 sampleLambertian(in float3 N, in float r1, in float r2, out float pdf)
{
    float3 L = sampleHemisphereCosWeighted(N, r1, r2);
    pdf = pdfLambertian(N, L);
    return L;
}


float3 randomDirection(in float Xi1, in float Xi2)
{
    float theta = acos(1.0 - 2.0 * Xi1);
    float phi = TWO_PI * Xi2;
    return sphericalToCartesian(1.0, phi, theta);
}

// Converting PDF between from Area to Solid angle
float PdfAtoW(float aPdfA, float aDist2, float aCosThere)
{
    float absCosTheta = abs(aCosThere);
    if (absCosTheta < EPSILON)
        return 0.0;
    
    return aPdfA * aDist2 / absCosTheta;
}

void sampleSphericalLight(in float3 x, in Sphere sphere, float Xi1, float Xi2, out LightSamplingRecord sampleRec)
{
    float3 n = randomDirection( Xi1, Xi2 );
    float3 p = sphere.pos + n * sphere.radius;
    float pdfA = 1.0/sphere.area;
    float3 Wi = p - x;
    float d2 = dot(Wi,Wi);
    sampleRec.d = sqrt(d2);
    sampleRec.w = Wi/sampleRec.d; 
    float cosTheta = max( 0.0, dot(n, -sampleRec.w) );
    sampleRec.pdf = PdfAtoW( pdfA, d2, cosTheta );
}

/********************************************/



/*MIS Functions*/

float sphericalLightSamplingPdf(in float3 x, in float3 wi, float d, in float3 n1, in Sphere sphere)
{
    float lightPdfA = 1.0 / sphere.area;
    float cosTheta1 = max(0.0, dot(n1, -wi));
    return PdfAtoW(lightPdfA, d * d, cosTheta1);
}

float lightChoosingPdf(in float3 x, in int lightId)
{
    return 1.0 / float(LIGHT_COUNT);
}

float misWeightPower(in float a, in float b)
{
    float a2 = a * a;
    float b2 = b * b;
    float a2b2 = a2 + b2;
    return a2 / a2b2;
}
float misWeightBalance(in float a, in float b)
{
    float ab = a + b;
    
    return a / ab;
}
float misWeight(in float pdfA, in float pdfB)
{
#ifdef MIS_HEURISTIC_POWER
    return misWeightPower(pdfA,pdfB);
#else
    return misWeightBalance(pdfA, pdfB);
#endif
}

/**/
float3 sampleBSDF(in float3 x, in RaySurfaceHit hit, in Material mtl, in bool useMIS)
{
    float3 Lo = float3(0.0);
    float bsdfSamplingPdf = 1.0 / float(BSDF_SAMPLES);
    float3 n = hit.N * float3((dot(hit.E, hit.N) < 0.0) ? -1.0 : 1.0);
    
    for (int i = 0; i < BSDF_SAMPLES; i++)
    {
        //Generate direction proportional to bsdf
        float3 bsdfDir;
        float bsdfPdfW;
        float brdf;
        float Xi1 = randSeed();
        float Xi2 = randSeed();
        float strataSize = 1.0 / float(BSDF_SAMPLES);
        Xi2 = strataSize * (float(i) + Xi2);
        
        if (mtl.bsdf_ == BSDF_R_GLOSSY)
        {
            bsdfDir = sampleBlinn(n, hit.E, mtl.roughness_, Xi1, Xi2, bsdfPdfW);
            brdf = evaluateBlinn(n, hit.E, bsdfDir, mtl.roughness_);
        }
        else
        {
            bsdfDir = sampleLambertian(n, Xi1, Xi2, bsdfPdfW);
            brdf = evaluateLambertian(n, bsdfDir);
        }
        
        float dotNWi = dot(bsdfDir, n);

        //Continue if sampled direction is under surface
        if ((dotNWi > 0.0) && (bsdfPdfW > EPSILON))
        {
            //calculate light visibility
            RaySurfaceHit newHit;
            Ray r = { x, bsdfDir };

            // only one bounce
            if (raySceneIntersection(r, EPSILON, newHit) && (newHit.obj_id < LIGHT_COUNT))
            {
                //Get hit light Info
                
                Sphere lightSphere = getLight(newHit.obj_id);
                float3 Li = getMaterialFromLibrary(4 + newHit.obj_id).color;

                //Read light info
                float weight = 1.0;
                float lightPdfW;
                if (useMIS)
                {
                    lightPdfW = sphericalLightSamplingPdf(x, bsdfDir, newHit.dist, newHit.N, lightSphere);
                    lightPdfW *= lightChoosingPdf(x, newHit.obj_id);
                    weight = misWeight(bsdfPdfW, lightPdfW);
                }

                Lo += brdf * dotNWi * (Li / bsdfPdfW) * weight;
            }
        }
    }

    return Lo * bsdfSamplingPdf;
}


float3 sampleLight(in float3 x, in RaySurfaceHit hit, in Material mtl, in bool useMIS)
{
    float3 Lo = float3(0.0); //outgoing radiance
    float lightSamplingPdf = 1.0 / float(LIGHT_SAMPLES);
   
    for (int i = 0; i < LIGHT_SAMPLES; i++)
    {
        //select light uniformly
        float Xi = randSeed();
        float strataSize = 1.0 / float(LIGHT_SAMPLES);
        Xi = strataSize * (float(i) + Xi);

        // choose one light
        float lightPickPdf = 1.0 / float(LIGHT_COUNT);
        int lightId = int(Xi * float(LIGHT_COUNT));
        
        //Read light info
         //incomming radiance
        Sphere lightSphere = getLight(lightId);
        float3 Li = getMaterialFromLibrary(4 + lightId).color;

        float Xi1 = randSeed();
        float Xi2 = randSeed();

        LightSamplingRecord sampleRec;
        sampleSphericalLight(x, lightSphere, Xi1, Xi2, sampleRec);
        
        float lightPdfW = lightPickPdf * sampleRec.pdf;
        float3 Wi = sampleRec.w;
        
        float dotNWi = dot(Wi, hit.N);

        if ((dotNWi > 0.0) && (lightPdfW > EPSILON))
        {
            Ray shadowRay = { x, Wi };
            RaySurfaceHit newHit;
            bool visible = true;

            visible = (raySceneIntersection(shadowRay, EPSILON, newHit) && ((newHit.dist - abs(sampleRec.d)) < EPSILON));

            if (visible)
            {
                float brdf;
                float brdfPdfW; //pdf of choosing Wi with 'bsdf sampling' technique
                
                if (mtl.bsdf_ == BSDF_R_GLOSSY)
                {
                    brdf = evaluateBlinn(hit.N, hit.E, Wi, mtl.roughness_);
                    brdfPdfW = pdfBlinn(hit.N, hit.E, Wi, mtl.roughness_); //sampling Pdf matches brdf
                }
                else
                {
                    brdf = evaluateLambertian(hit.N, Wi);
                    brdfPdfW = pdfLambertian(hit.N, Wi); //sampling Pdf matches brdf
                }

                float weight = 1.0;
                if (useMIS)
                {
                    weight = misWeight(lightPdfW, brdfPdfW);
                }
                
                Lo += (Li * brdf * weight * dotNWi) / lightPdfW;
            }
        }
    }
    
    return Lo * lightSamplingPdf;
}


/********************************************/
float3 Radiance(in Ray ray)
{
    RaySurfaceHit hit;
    if (raySceneIntersection(ray, 0.0, hit))
    {
        Material mtl = getMaterialFromLibrary(hit.mtl_id);

        float3 f, Le;

        if (mtl.bsdf_ == BSDF_R_LIGHT)
        {
            Le = mtl.color;
            f = float3(1.0, 1.0, 1.0);
        }
        else
        {
            Le = float3(0.0);
            f = mtl.color;
        }
        
        float3 hitPos = ray.origin + ray.dir * hit.dist;
            
        float3 directLight = float3(0.0);
        
        if (samplingTechnique == SAMPLING_LIGHT)
        {
            directLight += sampleLight(hitPos, hit, mtl, false);
        }
        else if (samplingTechnique == SAMPLING_BSDF)
        {
            directLight += sampleBSDF(hitPos, hit, mtl, false);
        }
        else
        {
            directLight += sampleBSDF(hitPos, hit, mtl, true);
            directLight += sampleLight(hitPos, hit, mtl, true);
        }

        return Le + f * directLight;
    }

    return float3(0.2); // background color
}

float4 mainImage(float2 fragCoord)
{
    float2 uv = fragCoord / iResolution.y;
    seed = iGlobalTime + iResolution.y * fragCoord.x / iResolution.x + fragCoord.y / iResolution.y;
    
    // Time Setting
    float t = 0.0;
    
    // Camera Setting
    Camera camera;
    float3 cameraPos = float3(0.0, 2.0 + sin(t * 0.45), 1.0 + sin(t * 0.4) * 3.0);
    float3 cameraTarget = float3(sin(t * 0.4) * 0.3, 0.0, -5.0);
    initCamera(cameraPos, cameraTarget - cameraPos, float3(0.0, 0.0, 1.0), radians(45.0), camera);


    float2 subPixelCoord = float2(randSeed(), randSeed());
    float2 screenCoord = fragCoord.xy + subPixelCoord;
    Ray ray = genRay(camera, screenCoord);
    
    float4 color = float4(1.0);
    RaySurfaceHit hit;
    //if (raySceneIntersection(ray, 0.0, hit))
    //{
    //    color = float4(hit.N, 1.0);
    //}
    color.rgb = Radiance(ray);
    return color;
}

float4 main(float2 texC : TEXCOORD) : SV_TARGET
{
    return mainImage(texC * iResolution);
}
