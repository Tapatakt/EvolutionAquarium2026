namespace EvolutionAquarium2026;
internal class Flattened2dArray<T>(int x, int y)
{
    public int X { get; } = x;
    public int Y { get; } = y;
    public T[] Data { get; } = new T[x * y];
    public T this[int i, int j]
    {
        get => Data[j * X + i];
        set => Data[j * X + i] = value;
    }
}
