#version 430 core

uniform sampler2D renderTexture;
uniform vec2 cameraPos;      // Camera center (0-1 range)
uniform float cameraZoom;    // Zoom level (1.0 = fit screen)
uniform vec2 screenSize;     // Screen resolution
uniform vec2 worldSize;      // World resolution

out vec4 fragColor;

void main()
{
    // Convert fragment coord to normalized screen space [-1, 1]
    vec2 screenUV = gl_FragCoord.xy / screenSize;

    // Calculate aspect ratios
    float screenAspect = screenSize.x / screenSize.y;
    float worldAspect = worldSize.x / worldSize.y;

    // Center the view
    vec2 uv = screenUV - 0.5;

    // Apply zoom
    uv /= cameraZoom;

    // Adjust for aspect ratio
    if (screenAspect > worldAspect) {
        uv.x *= screenAspect / worldAspect;
    }
    else {
        uv.y *= worldAspect / screenAspect;
    }

    // Apply camera position
    uv += cameraPos;

    // Wrap X coordinate (world wraps horizontally)
    uv.x = fract(uv.x);

    // Clamp Y coordinate (world doesn't wrap vertically)
    if (uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    fragColor = texture(renderTexture, uv);
}