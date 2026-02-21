using System.Text.Json;

namespace EvolutionAquarium2026;

class Config
{
    public int WorldWidth { get; set; } = 1920;
    public int WorldHeight { get; set; } = 1080;
    public int MaxSpecies { get; set; } = 20000;
    public int MaxDnaLength { get; set; } = 256;
    public int MutationRate { get; set; } = 100;
    public int MinCreatures { get; set; } = 1000;

    public static Config Load(string path = "config.json")
    {
        if (!File.Exists(path))
            return new Config();

        string json = File.ReadAllText(path);
        return JsonSerializer.Deserialize<Config>(json) ?? new Config();
    }
}
