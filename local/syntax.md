# Syntax

## Running a function
```lua
echo "Hello World!"
```

## Variables
```lua
test = "Hello World!"
echo $test
```

## Inlining expressions

Use the value of a function and put it into another command by wrapping it in `()`
```lua
bring (get-player-position player)
```

## Creating tables

Create a Luau table to facilitate more complex commands
```lua
patch-data zw1ce { money = 100 }
```

## Creating functions

Create a new function using the `fn` keyword. This is useful to allow players to create complex bindings and macros.
It expects two `()`, where the first one denotes arguments and the second one denotes the actual code to execute.
You can create multiline functions by separating them with a new line.
Any remaining values on the stack will be returned to the user.
```lua
blink = fn(distance) (
    cframe = get-component (get-player) Transform
    destination = mul $cframe (CFrame.new 0 0 10 )
    teleport $localplayer $destination
)
```

## Indexing

Allows indexing of values using `.` syntax and `[]`

```lua
transform = CFrame.new 0 0 0
t = table["test-data"]
```

