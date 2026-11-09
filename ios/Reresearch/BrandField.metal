#include <metal_stdlib>
using namespace metal;

constant float2 ringDirections[10] = {
    float2(0, -1), float2(0.5877853, -0.8090170), float2(0.9510565, -0.3090170),
    float2(0.9510565, 0.3090170), float2(0.5877853, 0.8090170), float2(0, 1),
    float2(-0.5877853, 0.8090170), float2(-0.9510565, 0.3090170),
    float2(-0.9510565, -0.3090170), float2(-0.5877853, -0.8090170)
};

// A periodic wave has no wrap seam or change of direction at the join.
static float travellingLight(float angle) {
    float crest = 0.5 + 0.5 * cos(angle);
    return crest * crest * crest * crest;
}

static float3 pigmentAt(device const float *values, int offset) {
    return float3(values[offset], values[offset + 1], values[offset + 2]);
}

// A curved, advected front replaces pigment locally. Completed fronts remain
// exactly at their destination; later fronts enter the field already present.
static void flowingPigments(float2 p, float time, device const float *values, int count,
                            thread float3 &blue, thread float3 &cyan,
                            thread float3 &violet, thread float3 &pink,
                            thread float2 &drift, thread float &glow) {
    blue = pigmentAt(values, 0); cyan = pigmentAt(values, 3);
    violet = pigmentAt(values, 6); pink = pigmentAt(values, 9);
    drift = float2(0.0); glow = 0.0;
    const float2 direction = float2(0.8, -0.6);
    const float2 tangent = float2(0.6, 0.8);
    for (int offset = 12; offset + 13 < count; offset += 14) {
        float progress = clamp((time - values[offset]) / values[offset + 1], 0.0, 1.0);
        if (progress <= 0.0) continue;
        float coverage = 1.0;
        float wake = 0.0;
        if (progress < 1.0) {
            float across = dot(p, tangent);
            float curl = 0.22 * sin(across * 2.5 - progress * 2.0)
                       + 0.08 * sin(across * 5.2 + progress * 3.0);
            float coordinate = dot(p, direction) + curl;
            float front = mix(-1.7, 1.7, smoothstep(0.0, 1.0, progress));
            coverage = 1.0 - smoothstep(front - 0.32, front + 0.32, coordinate);
            coverage *= smoothstep(0.0, 0.08, progress);
            // Only the near-white outer tail needs this final settling blend.
            coverage = mix(coverage, 1.0, smoothstep(0.88, 1.0, progress));
            float wakeDistance = (coordinate - front) / 0.38;
            wake = exp(-wakeDistance * wakeDistance) * sin(progress * 3.14159265);
            drift += tangent * wake * 0.12 * sin(across * 2.5 - progress * 2.0);
        }
        blue = mix(blue, pigmentAt(values, offset + 2), coverage);
        cyan = mix(cyan, pigmentAt(values, offset + 5), coverage);
        violet = mix(violet, pigmentAt(values, offset + 8), coverage);
        pink = mix(pink, pigmentAt(values, offset + 11), coverage);
        glow = glow * (1.0 - coverage) + wake * 0.09;
    }
}

// A continuous colour field, not a texture. White participates in both the
// lighting and edge falloff, allowing the mark to dissolve into its canvas.
static float3 orbColour(float2 p, float phase, float t, float surge,
                         float3 blue, float3 cyan, float3 violet, float3 pink) {
    float drift = t * 0.24;
    float2 flow = float2(cos(phase + drift), sin(phase + drift));
    float band = dot(p, flow);
    float3 colour = mix(blue, cyan, smoothstep(-0.6, 0.9, band) * 0.8);
    float violetWeight = exp(-3.4 * dot(p - float2(-0.14, 0.08), p - float2(-0.14, 0.08)));
    colour = mix(colour, violet, violetWeight * (0.6 + 0.32 * cos(phase)));
    float pinkWeight = pow(0.5 + 0.5 * sin(phase), 2.0);
    colour = mix(colour, pink, pinkWeight * smoothstep(-0.75, 0.65, -band) * 0.9);
    // An off-axis white light migrates through the pigment, not over a flat disk.
    float light = smoothstep(-0.3, 1.0, dot(p, float2(sin(phase + drift), -cos(phase + drift))));
    colour = mix(colour, float3(1.0), light * 0.84);
    colour = mix(colour, mix(cyan, violet, 0.5 + 0.5 * sin(phase + t)), surge * 0.2);
    // The travelling wave lights each orb from within, almost washing it out
    // to white at its crest; the original pigment returns behind the wave.
    float whiteSurge = surge * surge * (3.0 - 2.0 * surge);
    return mix(colour, float3(1.0), whiteSurge * 0.94);
}

[[ stitchable ]] half4 brandField(float2 position, half4 source, float2 size,
                                  float padding, float time, float focus, float energy,
                                  float surgeStarted, float pull,
                                  float refreshStarted, float refreshActivity, float compactAmount,
                                  device const float *colourFlow, int colourCount,
                                  float paletteChangedAt) {
    const float tau = 6.28318530718;
    const float count = 10.0;
    // Category changes stay one orb: a soft swell, lift and slight lean as
    // the new pigment arrives, followed by a longer, quieter settling tail.
    float paletteAge = time - paletteChangedAt;
    float bloom = smoothstep(0.0, 0.32, paletteAge) * (1.0 - smoothstep(0.5, 1.65, paletteAge));
    float available = (1.0 - energy) * (1.0 - pull);
    bloom *= available;
    float side = min(size.x, size.y);
    float2 uv = (position - size * 0.5 - padding) / max(side, 1.0);
    float displayScale = mix(1.0, mix(0.72, 1.30, focus), compactAmount) * (1.0 + bloom * 0.28);
    float2 world = uv / displayScale;
    world.y += bloom * 0.055;
    float lean = bloom * 0.14;
    world = float2(world.x * cos(lean) - world.y * sin(lean),
                   world.x * sin(lean) + world.y * cos(lean));
    world *= float2(1.0 - bloom * 0.055, 1.0 + bloom * 0.055);
    float3 result = float3(0.0);
    float alpha = 0.0;
    float age = time - surgeStarted;
    float surgePhase = age * tau / 4.2;
    float surgeEnvelope = smoothstep(0.0, 0.65, age) * (1.0 - smoothstep(4.5, 6.3, age));
    float refreshAge = max(0.0, time - refreshStarted);
    float charge = smoothstep(0.65, 4.1, refreshAge);

    for (int i = 0; i < 10; ++i) {
        float phase = float(i) / count * tau;
        // Resting positions stay composed. A live pull introduces a restrained
        // flutter that builds directly with the finger's distance.
        float2 centre = ringDirections[i] * 0.35;
        float flutter = pull * (1.0 - focus) * (1.0 - smoothstep(0.0, 0.5, refreshActivity));
        float flutterAngle = flutter * (0.035 * sin(time * 3.0) + 0.05 * sin(time * 4.0 + phase * 2.0));
        centre = float2(centre.x * cos(flutterAngle) - centre.y * sin(flutterAngle),
                        centre.x * sin(flutterAngle) + centre.y * cos(flutterAngle));
        centre *= 1.0 + flutter * 0.035 * sin(time * 5.0 + phase);
        float baseRadius = 0.069 * (1.0 + pull * 0.05);
        // The resting orb is the collected form of these same particles.
        // Activity opens them along gentle paths, entirely within the canvas.
        float2 tangent = float2(-ringDirections[i].y, ringDirections[i].x);
        float bend = sin(focus * 3.14159265) * (0.028 + 0.008 * sin(phase * 1.7));
        centre = centre * (1.0 - focus) + tangent * bend;
        baseRadius = mix(baseRadius, i == 0 ? 0.32205 : 0.12, focus);
        float2 candidate = (world - centre) / baseRadius;
        // Cull empty pixels before doing any wave or pigment work.
        if (dot(candidate, candidate) > 6.7) continue;
        float loadingWave = travellingLight(phase - time * tau / 3.6) * energy;
        float surge = travellingLight(phase - surgePhase);
        float wave = mix(loadingWave, surge, surgeEnvelope);
        float pullLight = travellingLight(phase - time * tau / 2.0) * pull * 0.8;
        wave = 1.0 - (1.0 - wave) * (1.0 - pullLight);
        float orbRadius = baseRadius * (1.0 + wave * 0.025 * (1.0 - focus));
        float2 local = (world - centre) / orbRadius;
        float distanceSquared = dot(local, local);
        if (distanceSquared > 6.25) continue;
        // One continuous density profile changes shape. There is no second
        // hard-edged disk to reveal, no thresholded arc and no random reseeding.
        float distance = sqrt(distanceSquared);
        float character = float(i) * 2.39996323;
        // Spend more of each independent cycle with a defined contour, while
        // retaining one continuous falloff and the full range of soft states.
        float firmness = pow(0.5 + 0.5 * sin(time * 0.11 + character * 1.61), 0.62);
        float directionality = mix(0.15, 0.9, 0.5 + 0.5 * sin(time * 0.065 + character * 1.9));
        float contourAngle = character + time * 0.09 + 0.25 * sin(time * 0.07 + character * 0.8);
        float2 contourDirection = float2(cos(contourAngle), sin(contourAngle));
        float angularSpread = 0.5 + 0.5 * dot(local / max(distance, 0.001), contourDirection);
        float localFirmness = firmness * mix(1.0, angularSpread, directionality);
        float falloffPower = mix(3.5, 15.0, localFirmness);
        float density = distanceSquared * distanceSquared / 0.78074896;
        density *= pow(max(distance / 0.94, 0.0001), (falloffPower - 4.0) * (1.0 - focus));
        float edge = exp(-density);
        if (i != 0) {
            // Blend the companions into the central field as they collect.
            // No circle is clipped by a camera boundary during the morph.
            edge *= 1.0 - smoothstep(0.05, 0.86, focus);
        }
        float3 blue, cyan, violet, pink;
        float2 pigmentDrift;
        float flowGlow;
        flowingPigments(local, time, colourFlow, colourCount,
                        blue, cyan, violet, pink, pigmentDrift, flowGlow);
        float3 pigment = orbColour(local + pigmentDrift, phase, time, wave, blue, cyan, violet, pink);
        pigment = mix(pigment, float3(1.0), flowGlow);
        float refreshing = refreshActivity;
        if (refreshing > 0.0001) {
            // Keep one shared travelling light. Pigment strengthens with
            // progress, without a second fast white rotation or flashing layer.
            float3 charged = mix(float3(1.0), pigment, 0.60 + charge * 0.40);
            pigment = mix(pigment, charged, refreshing);
        }
        result = pigment * edge + result * (1.0 - edge);
        alpha = edge + alpha * (1.0 - edge);
    }
    return half4(half3(result), half(alpha * source.a));
}
