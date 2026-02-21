#version 430 core

uniform usampler2D speciesTexture;
uniform usampler2D worldStateTexture;
uniform vec2 worldSize;
uniform uint stepNumber;
uniform uint visualizationMode;

layout(std430, binding = 1) buffer ColorsBuffer {
    uint colors[]; // Упакованные RGB
};

out vec4 fragColor;

const float PI = 3.14159265359;
const float SUN_SPEED = 0.02;

// Вычисление уровня света для данной позиции
uint calculateLight(ivec2 pos)
{
    float x = float(pos.x);
    float y = float(pos.y);

    float phase = 2.0 * PI * (x / worldSize.x + float(stepNumber) * SUN_SPEED);
    float seasonBig = 1.0 + sin(float(stepNumber) / 1037) * 0.1;
    float seasonSmall = 1.0 + sin(float(stepNumber) / 11) * 0.1;
    float lightValue = clamp(0.5 + sin(phase), 0.0, 1.0) * seasonBig * seasonSmall * y / worldSize.y;

    // Нормализуем от [0, 1] в [0, 255]
    return uint(lightValue * 255.0);
}

void main()
{
    ivec2 pos = ivec2(gl_FragCoord.xy);
    uvec4 worldState = texelFetch(worldStateTexture, pos, 0);
    uint minerals = (worldState.b >> 8) & 0xFFu;
    uint speciesID = texelFetch(speciesTexture, pos, 0).r;

    if (speciesID == 0u)
    {
        float yellow = 1.0 / 2048.0 * calculateLight(pos); // max 1/8
        float red = float(minerals) / 1024.0; // max 1/4
        fragColor = vec4(red + yellow, yellow, 0.5 - red - 2*yellow, 1.0);
        return;
    }
    if (visualizationMode == 0) // Показать только фон
    {
        float yellow = 1.0 / 2048.0 * calculateLight(pos); // max 1/8
        float red = float(minerals) / 1024.0; // max 1/4
        fragColor = vec4(red + yellow, yellow, 0.5 - red - 2 * yellow, 1.0);
    }
    else if (visualizationMode == 1) // Показать цвета видов
    {
        // Читаем упакованный цвет
        uint packedColor = colors[speciesID];
        //uint opcode = worldState.b & 0xFFu;

        // Распаковываем
        float r = float(packedColor & 0xFFu) / 255.0;
        float g = float((packedColor >> 8) & 0xFFu) / 255.0;
        float b = float((packedColor >> 16) & 0xFFu) / 255.0;
        fragColor = vec4(r, g, b, 1.0);
    }
    else if (visualizationMode == 2) // Показать энергию
    {
        uint energy = worldState.g & 0xFFu;
        float yellow = float(energy) / 256.0;
        fragColor = vec4(yellow, yellow, 0.0, 1.0);
    }
    else if (visualizationMode == 3) // Показать последнее действие
    {
        const uint OP_PHOTOSYNTHESIS = 0x1u;
        const uint OP_CHEMOSYNTHESIS = 0x2u;
        const uint OP_MOVE = 0x3u;
        const uint OP_ATTACK = 0x4u;
        const uint OP_GROW_TEETH = 0x5u;
        const uint OP_GROW_ARMOR = 0x6u;
        const uint OP_GROW_PHOTOSYNTHESIS = 0x7u;
        const uint OP_GROW_CHEMOSYNTHESIS = 0x8u;
        const uint OP_REPRODUCE = 0x9u;
        uint opcode = worldState.b & 0xFFu;
        if (opcode == OP_PHOTOSYNTHESIS)
            fragColor = vec4(0.0, 1.0, 0.0, 1.0);
        else if (opcode == OP_CHEMOSYNTHESIS)
            fragColor = vec4(0.0, 0.0, 1.0, 1.0);
        else if (opcode == OP_MOVE)
            fragColor = vec4(1.0, 1.0, 0.0, 1.0);
        else if (opcode == OP_ATTACK)
            fragColor = vec4(1.0, 0.0, 0.0, 1.0);
        else if (opcode == OP_REPRODUCE)
            fragColor = vec4(0.0, 1.0, 1.0, 1.0);
        else if (opcode >= OP_GROW_TEETH && opcode <= OP_GROW_CHEMOSYNTHESIS)
            fragColor = vec4(1.0, 0.0, 1.0, 1.0);
        else fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
    else if (visualizationMode == 4) // Показать зубы/броню
    {
        uint parameters = (worldState.g >> 8) & 0xFFu;
        uint armorLevel = (parameters >> 2) & 0x3u;
        uint teethLevel = parameters & 0x3u;
        fragColor = vec4(0.25 * teethLevel, 0.25 * armorLevel, 0.0, 1.0);
    }
    else if (visualizationMode == 5) // Показать фотосинтез/хемосинтез
    {
        uint parameters = (worldState.g >> 8) & 0xFFu;
        uint photoLevel = (parameters >> 4) & 0x3u;
        uint chemoLevel = (parameters >> 6) & 0x3u;
        fragColor = vec4(0.25 * photoLevel, 0.25 * chemoLevel, 0.0, 1.0);
    }
}