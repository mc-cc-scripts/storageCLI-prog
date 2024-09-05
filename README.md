# storageCLI-prog

> [!NOTE]
> This is a very minimal example of an interface for the [storageManager](https://github.com/mc-cc-scripts/storageManager-prog/tree/master)
> There are still bugs and errors are not properly caught.

# Commands
## extract
Extract an item with a specific amount from the storage chest into the output chest.
```
x <item> <amount>
```
# put
Puts an item with a specific amount from the input chest into the storage.
```
p <item> <amount>
```
# dump
Dumps all items of the input chest into the storage.
```
d
```
# find
Searches for substring. Chest is optional.
```
f <item> [<chest: input|output|storage (default)>]
```
# network
Lists all network devices (connected peripherals).
```
n
```
# select
Selects a given peripheral as input, output or storage chest.
```
s <chest: input|output|storage> <peripheral>
```
# help
Shows this list of commands.
```
h
```