global using OpenTK.Graphics.OpenGL;
global using OpenTK.Mathematics;
global using OpenTK.Windowing.Common;
global using OpenTK.Windowing.Desktop;
global using OpenTK.Windowing.GraphicsLibraryFramework;
using OpenTK.Platform;

namespace EvolutionAquarium2026;

internal class Program(GameWindowSettings gameWindowSettings, NativeWindowSettings nativeWindowSettings)
    : GameWindow(gameWindowSettings, nativeWindowSettings)
{
    private Simulation? _simulation;
    private Vector2 _lastMousePos;
    private bool _isDragging = false;

    protected override void OnLoad()
    {
        base.OnLoad();
        GL.ClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        VSync = VSyncMode.On; // Ограничить до частоты монитора (обычно 60 FPS)
        var resolution = Monitors.GetPrimaryMonitor().CurrentVideoMode;
        Config config = Config.Load();
        _simulation = new(config, resolution.Width, resolution.Height);
    }
    protected override void OnRenderFrame(FrameEventArgs args)
    {
        base.OnRenderFrame(args);

        GL.Clear(ClearBufferMask.ColorBufferBit);

        _simulation?.Step();

        SwapBuffers();
    }
    protected override void OnUpdateFrame(FrameEventArgs args)
    {
        base.OnUpdateFrame(args);

        if (KeyboardState.IsKeyDown(Keys.Escape))
        {
            Close();
            return;
        }
        if (KeyboardState.IsKeyDown(Keys.D1))
            _simulation?.ChangeVisualizationMode(1);
        if (KeyboardState.IsKeyDown(Keys.D2))
            _simulation?.ChangeVisualizationMode(2);
        if (KeyboardState.IsKeyDown(Keys.D3))
            _simulation?.ChangeVisualizationMode(3);
        if (KeyboardState.IsKeyDown(Keys.D4))
            _simulation?.ChangeVisualizationMode(4);
        if (KeyboardState.IsKeyDown(Keys.D5))
            _simulation?.ChangeVisualizationMode(5);
        if (KeyboardState.IsKeyDown(Keys.D0))
            _simulation?.ChangeVisualizationMode(0);

        // Pan with arrow keys
        float panSpeed = 0.01f;
        if (KeyboardState.IsKeyDown(Keys.Left)) _simulation?.Pan(-panSpeed, 0);
        if (KeyboardState.IsKeyDown(Keys.Right)) _simulation?.Pan(panSpeed, 0);
        if (KeyboardState.IsKeyDown(Keys.Up)) _simulation?.Pan(0, panSpeed);
        if (KeyboardState.IsKeyDown(Keys.Down)) _simulation?.Pan(0, -panSpeed);

        // Reset camera
        if (KeyboardState.IsKeyDown(Keys.R))
            _simulation?.SetCamera(0.5f, 0.5f, 1.0f);
    }
    protected override void OnMouseDown(MouseButtonEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button == OpenTK.Windowing.GraphicsLibraryFramework.MouseButton.Left)
        {
            _isDragging = true;
            _lastMousePos = new Vector2(MouseState.X, MouseState.Y);
        }
    }
    protected override void OnMouseUp(MouseButtonEventArgs e)
    {
        base.OnMouseUp(e);
        if (e.Button == OpenTK.Windowing.GraphicsLibraryFramework.MouseButton.Left)
        {
            _isDragging = false;
        }
    }

    protected override void OnMouseMove(OpenTK.Windowing.Common.MouseMoveEventArgs e)
    {
        base.OnMouseMove(e);
        if (_isDragging)
        {
            Vector2 currentPos = new(e.X, e.Y);
            Vector2 delta = currentPos - _lastMousePos;
            _simulation?.Pan(-delta.X / ClientSize.X, delta.Y / ClientSize.Y);
            _lastMousePos = currentPos;
        }
    }

    protected override void OnMouseWheel(MouseWheelEventArgs e)
    {
        base.OnMouseWheel(e);
        float zoomFactor = e.OffsetY > 0 ? 1.1f : 0.9f;
        _simulation?.Zoom(zoomFactor);
    }

    static void Main()
    {
        NativeWindowSettings nativeWindowSettings = new()
        {
            ClientSize = new Vector2i(1920, 1080),
            Title = "Evolution Aquarium 2026",
            WindowState = WindowState.Fullscreen,
            API = ContextAPI.OpenGL,
            APIVersion = new Version(4, 3),
            Profile = ContextProfile.Core
        };
        using Program game = new(GameWindowSettings.Default, nativeWindowSettings);
        game.Run();
    }
}
