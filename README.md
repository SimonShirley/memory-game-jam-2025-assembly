# Memory Game
A simple tile matching game for the Commodore 64, written in 6502 assembly.
This is a port of the BASIC version, submitted separately.

This game is a submission for the [Retro Programmers Inside (RPI) and Phaze101 Game Jam](https://itch.io/jam/memorygame).

The premise of the game is to find the matching tiles.

The game is a great educational tool to promote short-term memory re-collection.


## How to Play

Upon starting the game, all of the tiles are covered, face down in the grid.

On your turn, select two tiles to turn over, which will reveal their tile symbol.

If the tile symbols match, you get to pick two new tiles.

If the tile symbols do not match, the tiles are re-covered. If you're playing a multiplayer game, your turn will be over and play will pass to your opponent.

If you're playing a multiplayer game, either against another player or the computer, the objective is to turn over more matching pairs before your opponent.

The game can be played single player as a casual game.


## Controls

This game is played using the keyboard only.

The cursor is moved using the **cursor keys** (up, down, left and right), the **WASD** keys (W-Up, A-Left, S-Down, D-Right).

The **RETURN** key confirms the tile choice.

The keys move the highlighted frame around the relevant tile grid.

Both players in multiplayer mode use the same keys.


## Game Mode / Options
### Board Size

There are 3 sizes of pattern grid to play with:
* 5x4 - 5 tiles wide by 4 tiles tall
* 6x5 - 6 tiles wide by 5 tiles tall
* 7x6 - 7 tiles wide by 6 tiles tall

Press F1 to toggle the board size in the menu.


### Number of Players

There are 3 player modes in this game:

* 1 - The game can be played single-player
* 2 - 2 players can play against each other, taking turns
* 1VCPU - A 2 player game where the second player is controlled by the computer

Press F3 to toggle this option in the menu.

Player 1 will be shown in light green. Player 2 / The Computer will be in light red / pink. The cursor frame will update to show who currently has control.

When playing in the 1VCPU mode, the computer player has 3 probability levels for whether the computer player will remember the tiles as they are turned over.

* LOW - The computer has an 30% chance of remembering the turned over tile
* MID - The computer has an 50% chance of remembering the turned over tile
* HI - The computer has an 80% chance of remembering the turned over tile

Press F5 to toggle this option in the menu. This option is only available if **1VCPU** is highlighted in the menu.


## Loading the Game
The game can be played on a Commodore 64 or using an emulator, such as [VICE](https://vice-emu.sourceforge.io/) or [online](https://c64online.com/c64-online-emulator/).

Mount the d64 image into your Commodore's disk drive (which is usually device 8) and load using the following command:

`LOAD"*",8,1`

At the `READY` prompt, type `RUN` and press `RETURN`.


## Special Thanks

Special Thanks / Credits can be read in-game by pressing **C** at the game mode menu.

Thanks to [Retro Programmers Inside (RPI)](https://rpinside.itch.io/) and [Phaze101](https://twitch.tv/Phaze1o1) for hosting the game jam.
https://itch.io/jam/memorygame

[The Polar Pop](https://twitch.tv/The_Polar_Pop) and [DeadSheppy](https://twitch.tv/DeadSheppy) for allowing me to waffle on about how the game was built and for helping to promote the Commodore 64 games I have already submitted to the **RPI** and **Phaze101** game jams.

The source code was written in [Visual Studio Code](https://code.visualstudio.com/), assembled using the [DASM assembler](https://dasm-assembler.github.io/), debugged using [Retro Debugger](https://github.com/slajerek/RetroDebugger) and tested using the [VICE emulator](https://vice-emu.sourceforge.io/). The screen user interfaces were designed using [Petmate](https://nurpax.github.io/petmate/).


## Project files
### Source Files
* memory-game.asm - The main source file, compilable using DASM
    * (see the `.vscode/tasks.json` file for the terminal command to build this game. Substitute the DASM path for your own path to the DASM binary)

#### Include files
* 5x4.asm - the screencodes, colours and positions for the 5x4 grid
* 6x5.asm - the screencodes, colours and positions for the 6x5 grid
* 7x6.asm - the screencodes, colours and positions for the 7x6 grid
* credits-screen.asm - the screencodes for the credits screen
* instructions-screens.asm - the screencodes for the instructions screens
* menu-screen.asm - the screencodes and colour bytes for the menu screen
* title-screen.asm - the screencodes and colour bytes for the title screen

#### Extra files
* memory-game.petmate - The save file from a MacOS screen editor program, PetMate

### Output files
* memory-game-asm.prg - A copy of the built file that can be run.
* memory-game-asm.sym - The Symbols file from the DASM build.
* memory-game-asm.d64 - Same as the PRG file but made into a disk image.
* README.md - This file.