//
//  RadiofunShaders.metal
//  traverse
//
//  1:1 Ported Metal Shaders from radiofun GitHub repositories.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - Fluted Glass Shader (flutedglasseffectmetal)
[[ stitchable ]] half4 fractalGlassEffect(float2 position, SwiftUI::Layer l, float4 boundingbox, float progress, float amplitude) {
    float2 size = float2(boundingbox[2], boundingbox[3]);
    float2 uv = position / size;
    float2 newpos = uv;
    float frequency = 12.0;
    float displacement = sin(uv.x * frequency * 6.28 + progress) * amplitude;
    newpos.x += displacement;
    half4 sampledColor = l.sample(newpos * size);
    return sampledColor;
}

// MARK: - Metal Warp Shader (MetalWarp)
[[ stitchable ]] half4 warp(float2 position, SwiftUI::Layer l, float2 size, float2 ct, float warp, float intensity) {
    float2 uv = position / size;
    float2 touch = ct / size;
    float distance = length(uv - touch);
    float warpFactor = warp / 40.0;
    float offsetfactor = warpFactor * warpFactor * intensity * intensity;
    float displacefactor = (0.5 - distance);
    float2 displacement = displacefactor * size * intensity;
    float2 newposition = (position + exp(displacement * warpFactor * 2.0));
    
    half3 f = half3(l.sample(newposition + offsetfactor * intensity).r,
                    l.sample(newposition + offsetfactor * 0.1).g,
                    l.sample(newposition - offsetfactor / 5.0).b);
    return half4(f, 1.0);
}

[[ stitchable ]] half4 light(float2 position, SwiftUI::Layer l, float2 size, float2 ct, float angle) {
    float2 uv = position / size;
    float2 center = ct / size;
    float2 direction = uv - center;
    float distance = length(direction);
    float normalizedAngle = angle / 40.0;
    
    float offsetfactor = normalizedAngle * normalizedAngle * 2.0;
    float displacefactor = 1.0 - (distance * distance) * normalizedAngle * 2.0;
    float2 newposition = position + position * displacefactor * 2.0;
    
    half3 c = half3(l.sample(newposition + offsetfactor).r,
                    l.sample(newposition + offsetfactor * 0.2).g,
                    l.sample(newposition - offsetfactor).b);
    return half4(c, 1.0);
}

// MARK: - Helper Functions for Slow Ripple and Light & Tilt
static float rf_random(float2 st) {
    return fract(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
}

static float rf_value_noise(float2 st) {
    float2 i = floor(st);
    float2 f = fract(st);

    float a = rf_random(i);
    float b = rf_random(i + float2(1.0, 0.0));
    float c = rf_random(i + float2(0.0, 1.0));
    float d = rf_random(i + float2(1.0, 1.0));

    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    return mix(mix(a, b, u.x),
               mix(c, d, u.x), u.y);
}

// MARK: - Slow Ripple Shader (slowripple)
[[ stitchable ]] half4 fbp(float2 pos, SwiftUI::Layer l, float4 boundingBox, float2 dragp, float time, float noise, float strength) {
    float2 size = float2(boundingBox[2], boundingBox[3]);
    float2 uv = pos / size;
    float2 c = dragp / size;
    
    float noiseScale = noise;
    float rippleFrequency = 16.0;
    float rippleSpeed = 3.0;
    float noisePerturbation = strength;
    float displacementStrength = 0.3;

    float baseNoise = rf_value_noise(uv * noiseScale);
    float2 rippleCenter = c;

    float dist = distance(uv, rippleCenter);
    float rippleWave = sin(
        dist * rippleFrequency
        - time * rippleSpeed
        + baseNoise * noisePerturbation
    );
    float2 direction = normalize(uv - rippleCenter + 1e-5);
    float2 displacement = direction * rippleWave * displacementStrength;
    float2 displacedUv = uv + displacement;

    float finalPattern = rf_value_noise(displacedUv * noiseScale * 1.2 + float2(time * 0.1, 0.0));
    float shading = smoothstep(0.0, 0.8, rippleWave) * 0.5 + 0.5;
    
    float2 newpos = uv;
    newpos *= finalPattern * shading;
    half4 color = l.sample(newpos * size);
    return color;
}

// MARK: - Lighting Simulation Shader (LightingSim)
static float2 sdSegmentSim(float2 p, float2 a, float2 b) {
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return float2(length(pa - ba * h), h);
}

[[ stitchable ]] half4 lightingSimulation(float2 position, SwiftUI::Layer layer, float2 size, float intensity, float disperse, float rotation, float radius) {
    float2 sourceUV = float2(0.5, 0.6);
    float2 sourcePos = sourceUV * size;
    
    float baseAngle = M_PI_F / 2.0; 
    float angle = baseAngle + rotation;
    float2 dir = float2(cos(angle), sin(angle));
    
    float beamLen = length(size);
    float2 endPos = sourcePos + dir * beamLen;
    
    float2 segment = sdSegmentSim(position, sourcePos, endPos);
    float distToAxis = segment.x;
    float t = segment.y;
    
    float w0 = radius;
    float spreadFactor = 2.0 * disperse;
    
    float distAlongAxis = t * beamLen;
    float startSmoothing = smoothstep(0.0, 0.2, t);
    float currentWidth = w0 + distAlongAxis * spreadFactor * startSmoothing;
    
    float clampedDisperse = min(disperse, 0.78) / 0.78;
    float offsetAmt = 160.0 * clampedDisperse * t;
    
    float2 perp = float2(-dir.y, dir.x);
    
    float2 posR = position + perp * offsetAmt;
    float distR = sdSegmentSim(posR, sourcePos, endPos).x;
    float beamR = 1.0 - smoothstep(0.0, currentWidth, distR);
    beamR = pow(beamR, 1.2);
    
    float distG = distToAxis;
    float beamG = 1.0 - smoothstep(0.0, currentWidth, distG);
    beamG = pow(beamG, 1.2);
    
    float2 posB = position - perp * offsetAmt;
    float distB = sdSegmentSim(posB, sourcePos, endPos).x;
    float beamB = 1.0 - smoothstep(0.0, currentWidth, distB);
    beamB = pow(beamB, 1.2);
    
    float density = w0 / currentWidth;
    float flux = density * density;
    float distFromSource = length(position - sourcePos);
    float falloff = 1.0 / (1.0 + distFromSource * 0.005);
    
    half3 lightColor = half3(beamR, beamG, beamB);
    
    float outerSpreadFactor = spreadFactor * 8.0;
    float outerWidth = w0 + distAlongAxis * outerSpreadFactor * startSmoothing;
    float outerBeam = 1.0 - smoothstep(0.0, outerWidth, distG);
    outerBeam = pow(outerBeam, 3.5);
    
    float outerIntensity = 0.05 * intensity * falloff;
    
    half3 mainBeamColor = lightColor * half(intensity * flux * falloff);
    half3 outerBeamColor = half3(outerBeam) * half(outerIntensity);
    
    half3 combinedLight = mainBeamColor + outerBeamColor;
    
    half4 original = layer.sample(position);
    half3 color = original.rgb + combinedLight;
    
    const half a = 2.51;
    const half b = 0.03;
    const half c = 2.43;
    const half d = 0.59;
    const half e = 0.14;
    
    half3 mapped = clamp((color * (a * color + b)) / (color * (c * color + d) + e), 0.0, 1.0);
    
    return half4(mapped, original.a);
}

// MARK: - Gradient Shader (GradientShader)
[[ stitchable ]] half4 noisyGradient(float2 pos, SwiftUI::Layer l, float4 bounds, float time) {
    float2 size = bounds.zw;
    float2 uv = pos / size;
    
    half3 peach = half3(0.9, 0.4, 0.3);
    half3 purple = half3(0.2, 0.1, 0.6);
    half3 teal = half3(0.0, 0.8, 0.8);

    float t = uv.y + 0.2 * sin(time + uv.x * 3.0);
    float p = uv.x + 0.2 * cos(time + uv.y * 6.0);
    
    half3 bottomColor = mix(purple, teal, half(clamp(p, 0.0, 1.0)));
    half3 color = mix(bottomColor, peach, half(clamp(t, 0.0, 1.0)));
    
    return half4(color, 1.0);
}

// MARK: - Metal Playground Shaders (MetalPlayground)
[[ stitchable ]] half4 wave(float2 position, SwiftUI::Layer l, float progress) {
    position.x += sin(progress + position.y / 20.0) * 50.0;
    return l.sample(position);
}

[[ stitchable ]] half4 colorfilter(float2 position, SwiftUI::Layer l, float progress) {
    half4 color = l.sample(position);
    half luminance = dot(color.rgb, half3(0.299, 0.587, 0.114));
    half4 grayscale = half4(luminance, luminance, luminance, color.a);
    return mix(color, grayscale, progress);
}

static float rf_maprange(float value, float inMin, float inMax, float outMin, float outMax) {
    return ((value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin);
}

[[ stitchable ]] half4 distortion(float2 position, SwiftUI::Layer l, float progress, float4 boundingRect) {
    float2 size = boundingRect.zw;
    float2 uv = position / size;
    
    float distortionFactor = rf_maprange(uv.x - 0.5, -0.5, 0.5, -1.0, 1.0);
    distortionFactor *= (1.0 - uv.y);
    distortionFactor *= progress;
    
    uv.y += 1.3 * progress;
    uv.x += distortionFactor;

    half4 color = l.sample(uv * size);
    return color;
}

[[ stitchable ]] half4 Ripple(
    float2 position,
    SwiftUI::Layer layer,
    float2 origin,
    float time,
    float amplitude,
    float frequency,
    float decay,
    float speed
) {
    float distance = length(position - origin);
    float delay = distance / speed;

    time -= delay;
    time = max(0.0, time);

    float rippleAmount = amplitude * sin(frequency * time) * exp(-decay * time);
    float2 n = normalize(position - origin);
    float2 newPosition = position + rippleAmount * n;

    half4 color = layer.sample(newPosition);
    color.rgb += 0.3 * (rippleAmount / amplitude) * color.a;

    return color;
}

[[ stitchable ]] half4 zoom(float2 position, SwiftUI::Layer l, float4 boundingRect, float2 dragp, float progress) {
    float2 size = boundingRect.zw;
    float2 uv = position / size;
    float2 center = dragp / size;
    float2 delta = uv - center;
    float aspectRatio = size.x / size.y;

    float2 newdelta = delta;
    newdelta.x *= aspectRatio;

    float radius = 0.2;
    float distance = length(newdelta);
    float zoomFactor = 1.0;
    if (distance < radius && progress == 1.0) {
        zoomFactor = 0.8;
    }

    float2 newpos = delta * zoomFactor + center;
    half4 color = l.sample(newpos * size);
    return color;
}

// MARK: - Light and Tilt Shader (LightandTilt)
[[ stitchable ]] half4 shine(float2 pos, SwiftUI::Layer l, float4 boundingBox, float2 dragp, float time, float noise) {
    float2 size = boundingBox.zw;
    float2 uv = pos / size;
    float2 c = dragp / size;
    
    float noiseScale = noise;
    float rippleFrequency = 5.0;
    float rippleSpeed = 1.0;
    float noisePerturbation = 0.0;
    float displacementStrength = 0.3;

    float baseNoise = rf_value_noise(fract(pos / 13.0));
    float2 rippleCenter = c;

    float dist = distance(uv, rippleCenter);
    float rippleWave = cos(
        dist * rippleFrequency
        - time * rippleSpeed
        + baseNoise * noisePerturbation
    );
    float2 direction = normalize(uv - rippleCenter + 1e-5);
    float2 displacement = direction * rippleWave * displacementStrength;
    float2 displacedUv = uv + displacement;

    float finalPattern = rf_value_noise(displacedUv * noiseScale * 3.6 + float2(time * 0.5, 0.0));
    float shading = smoothstep(0.0, 0.15, rippleWave) * 0.5 - 0.5;
    
    float2 newpos = uv;
    float brightness = finalPattern + shading;
    newpos += brightness;
    half4 color = l.sample(newpos * size);
    color += brightness * 1.3;
    return color;
}

// MARK: - Light Card Shader (LightCard)
[[ stitchable ]] half4 splash(float2 position, SwiftUI::Layer l, float4 boundingRect, float2 dragp, float strength) {
    float2 size = float2(boundingRect[2], boundingRect[3]);
    float2 uv = position / size;
    float2 udp = dragp / size;
    float2 d = uv - udp;
    float radius = strength;
    
    float2 newpos = uv;
    half3 color = l.sample(newpos * size).rgb;
    half3 splat = exp(-dot(d, d) / radius) * color;
    half3 newcolor = color + splat;

    return half4(newcolor, 1.0);
}

// MARK: - Metal Domain Warping Shader (Metal-Domain-Warping)
static float randomWithSeed(float2 st) {
    return fract(sin(dot(st, float2(12.9898, 78.233))) * 43758.5453123);
}

static float noise2D(float2 st) {
    float2 i = floor(st);
    float2 f = fract(st);

    float a = randomWithSeed(i);
    float b = randomWithSeed(i + float2(1.0, 0.0));
    float c = randomWithSeed(i + float2(0.0, 1.0));
    float d = randomWithSeed(i + float2(1.0, 1.0));

    float2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x)
         + (c - a) * u.y * (1.0 - u.x)
         + (d - b) * u.x * u.y;
}

#define RF_NUM_OCTAVES 100
static float rf_fbm(float2 st) {
    float value = 0.0;
    float amp = 0.5;

    float2 shift = float2(100.0, 100.0);

    float c = cos(0.5);
    float s = sin(0.5);
    float2x2 rot = float2x2(c, s, -s, c);

    for (int i = 0; i < RF_NUM_OCTAVES; i++) {
        value += amp * noise2D(st);
        st = rot * (st * 2.0) + shift;
        amp *= 0.5;
    }

    return value;
}

[[ stitchable ]] half4 fractalNoiseBlueWhite(
    float2 pos,
    SwiftUI::Layer l,
    float4 boundingRect,
    float progress, float scale)
{
    float2 size = float2(boundingRect[2], boundingRect[3]);
    float2 uv = pos / size * scale;
    float time = 0.1 * (-progress * 40.0);

    float2 q;
    q.x = rf_fbm(uv + 0.00 * time);
    q.y = rf_fbm(uv + float2(1.0, 0.0));

    float2 r;
    r.x = rf_fbm(uv + 1.0 * q + float2(1.7, 9.2) + 0.15 * time);
    r.y = rf_fbm(uv + 1.0 * q + float2(8.3, 2.8) + 0.126 * time);

    float f = rf_fbm(uv + r);

    float2 newpos = uv;
    newpos *= f;
    
    half3 color = half3(l.sample(newpos * size).rgb);
    return half4(color, 1.0);
}
