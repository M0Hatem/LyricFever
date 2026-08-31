//
//  ArtworkFluid.metal
//  Lyric Fever
//
//  Created by Antigravity on 2026-08-31.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[stitchable]] float2 twistDistortion(float2 position, float2 origin, float radius, float angle) {
    float2 coord = position - origin;
    float dist = length(coord);
    if (dist < radius && radius > 0.0) {
        float ratioDist = (radius - dist) / radius;
        float angleMod = ratioDist * ratioDist * angle;
        float s = sin(angleMod);
        float c = cos(angleMod);
        coord = float2(coord.x * c - coord.y * s, coord.x * s + coord.y * c);
    }
    return coord + origin;
}

[[stitchable]] half4 boostSaturation(float2 position, half4 color, float factor) {
    half luma = dot(color.rgb, half3(0.2126, 0.7152, 0.0722));
    half3 saturated = mix(half3(luma), color.rgb, half(factor));
    return half4(saturated, color.a);
}
