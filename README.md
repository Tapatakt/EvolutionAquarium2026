# Evolution Aquarium 2026

A GPU-accelerated artificial life and evolution simulation where virtual creatures with DNA-based behavior compete, reproduce, and evolve in a 2D (side-view) ecosystem.

## 🎮 Controls

| Key | Action |
|-----|--------|
| `Esc` | Exit application |
| `0-5` | Change visualization mode |
| `←↑↓→` | Pan camera |
| `R` | Reset camera |
| `Mouse Drag` | Pan camera |
| `Mouse Wheel` | Zoom in/out |

### Visualization Modes

| Mode | Description |
|------|-------------|
| `0` | Only background (light + minerals) |
| `1` | Species colors (default) |
| `2` | Energy levels |
| `3` | Last actions |
| `4` | Teeth and armor |
| `5` | Photosynthesis and chemosynthesis |

## 🌿 Simulation Mechanics

### Creatures
Each creature has:
- **DNA** - 256 bytes determining behavior
- **Energy** - required for survival and actions
- **Direction** - facing up, right, down, or left
- **Organs** - teeth, armor, photosynthesis, chemosynthesis (each 0-3 level)

### Actions
Creatures execute one action per simulation step:
- **Photosynthesis** - gain energy from light (more effective at top of world)
- **Chemosynthesis** - convert ground minerals to energy
- **Move** - advance one cell forward
- **Attack** - fight creature in front, absorb its energy
- **Reproduce** - create offspring in front cell
- **Grow Organs** - improve teeth, armor, or synthesis efficiency
- **Rotate** - turn clockwise or counter-clockwise
- **Check Conditions** - jump in DNA based on energy, light, minerals, or forward cell

### Evolution
- Creatures die when energy reaches zero or from old age (max 255)
- Dead creatures release minerals to the water
- New species emerge through mutation (configurable attempts per frame)
- Each mutation copies parent DNA with 1-4 random changes and similar color
- Evolution distance matrix tracks genetic divergence using most recent data
- Auto-spawns random creatures if population falls below minimum
- Each creature has an age that increments each step

### Environment
- **Light** varies by horizontal position (moving wave), vertical position (brighter at top), and time (seasonal cycles)
- **Minerals** appear from the bottom and dead creatures and move upwards with slight diffusion

## 💾 Data Format

Creature and world state is stored in an RGBA16UI texture (8 bytes per cell):

| Channel | Bits | Meaning |
|---------|------|---------|
| **R** | 0-7 | DNA position (0-255) |
| **R** | 8-15 | Direction (0=N, 1=E, 2=S, 3=W) |
| **G** | 0-7 | Energy (0-255) |
| **G** | 8-15 | Organ levels (2 bits each):<br>bits 0-1: teeth<br>bits 2-3: armor<br>bits 4-5: photosynthesis<br>bits 6-7: chemosynthesis |
| **B** | 0-7 | Last action / opcode |
| **B** | 8-15 | Minerals (0-255) |
| **A** | 0-15 | Directed action flags:<br>bit 0: attack flag<br>bits 1-2: attack direction<br>bit 4: move flag<br>bits 5-6: move direction<br>bit 8: reproduce flag<br>bits 9-10: reproduce direction |

**Age Texture** (separate R8UI texture, 1 byte per cell):
- Creature age (0-255), increments each step, death at 255

Additional data in Shader Storage Buffer Objects (SSBOs):
- DNA sequences (256 bytes per species)
- Species colors
- Evolution distance matrix
- Birth/death counters (atomic operations)
- Creation timestamps

## 🚀 Getting Started

### Prerequisites
- .NET 10.0 SDK or later
- OpenGL 4.3 compatible GPU

### Build & Run
```bash
dotnet build
dotnet run
```

### Configuration
Edit `config.json` to change simulation parameters:
```json
{
  "WorldWidth": 1920,
  "WorldHeight": 1080,
  "MaxSpecies": 20000,
  "MaxDnaLength": 256,
  "MutationRate": 100,
  "MinCreatures": 1000
}
```

| Parameter | Description |
|-----------|-------------|
| `WorldWidth/Height` | Simulation world size in cells |
| `MaxSpecies` | Maximum different species IDs |
| `MaxDnaLength` | DNA bytes per species |
| `MutationRate` | How many mutation attempts per frame |
| `MinCreatures` | Auto-spawn random creatures if population drops below this |

## 🙏 Acknowledgments

This project is inspired by the incredible artificial life simulations of **[foo52 ТехноШаман](https://www.youtube.com/@foo52ru)**. His work has been a major influence on the design and mechanics of this project.

## 📝 Technical Details

- **Language**: C# 13 with OpenTK
- **Graphics**: OpenGL 4.3 Core Profile
- **Simulation**: Fragment shaders (GLSL 430) for parallel creature processing
- **Buffering**: Double-buffered ping-pong texture pattern
- **Performance**: GPU handles all creature updates; CPU manages mutations and statistics

## 📄 License

MIT
