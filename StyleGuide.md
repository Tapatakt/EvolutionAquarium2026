# Style Guide

## General Principles

## Variable Declarations

- **Do not use `var`** unless the type name is really long and would hurt readability
- **Prefer explicit types** for clarity

```csharp
// Good
int count = 0;
string name = "example";
Simulation simulation = new Simulation();

// Acceptable when type name is long
SomeVeryLongGenericTypeName<int, string, object> result = GetResult();
// Could use var here:
var result = GetResult();
```

## Braces and Blocks

- **Skip unnecessary curly brackets** when possible
- **Use expression-bodied members** for single-statement methods and properties

```csharp
// Good
public int GetValue() => _value;

public void DoSomething()
{
    if (condition) return;
    ProcessData();
}

// Avoid
public int GetValue()
{
    return _value;
}

public void DoSomething()
{
    if (condition)
    {
        return;
    }
    ProcessData();
}
```

## Collection Expressions

- **Use collection expressions** when possible (introduced in C# 12)

```csharp
// Good
int[] numbers = [1, 2, 3];
List<string> names = ["Alice", "Bob", "Charlie"];
Span<byte> data = [0x00, 0x01, 0x02];

// Avoid
int[] numbers = new int[] { 1, 2, 3 };
List<string> names = new List<string> { "Alice", "Bob", "Charlie" };
```
