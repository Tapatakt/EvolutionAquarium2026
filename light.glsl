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