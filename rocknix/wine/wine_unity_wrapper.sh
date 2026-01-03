#!/bin/bash
# -------- Parameters --------
# $1 - directory and executable name of the Windows program
# $2 - WINE or Proton version to execute with
# $3 - executable path of the Windows program (Optional override of $1
#
# -------- Load PortMaster environment --------
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if   [ -d "/opt/system/Tools/PortMaster/" ]; then controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ];       then controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ];   then controlfolder="$XDG_DATA_HOME/PortMaster"
else                                              controlfolder="/roms/ports/PortMaster"
fi

source "$controlfolder/control.txt"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

# -------- Paths / Variables --------
SCRIPT_NAME="$0"
GAME="$1"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
ROM_DIR="$(echo "$SCRIPT_NAME" | awk -F'_' '{print $2}')"
GAMEDIR="/$directory/$ROM_DIR/$GAME"
EXEC_DIR="$GAMEDIR"
if [ -f "$EXEC_DIR/$GAME.bat" ]; then
  EXEC_NAME="$GAME.bat"
elif [ -f "$EXEC_DIR/$GAME.exe" ]; then
  EXEC_NAME="$GAME.exe"
fi
EXEC_PATH="$EXEC_DIR/$EXEC_NAME"

# ------- Override for custom Executable locations -------
if [ -n "$3" ]; then
	EXEC_PATH="$EXEC_DIR/$3"
	EXEC_DIR=$(dirname "$EXEC_PATH")
	EXEC_NAME=$(basename "$EXEC_PATH")
fi

SPLASH="$SCRIPT_DIR/splash" # your custom splash binary

# Wine/DXVK
export BOX=box64
WINE_WINEPREFIX_HOME="$SCRIPT_DIR/wineprefixes"
WINE_VERSIONS_HOME="$SCRIPT_DIR/"
WINE_VERSION_EXECUTABLE="-amd64/bin/wine"
WINE_VERSION="$2"
WINE="$WINE_VERSIONS_HOME$WINE_VERSION$WINE_VERSION_EXECUTABLE"
if [ -e $WINE ]; then
        export WINE
else
        export WINE=wine
fi

export WINEDEBUG=-all
#
# For Unity Engine Games, use the same Unity WinePrefix else
# check for pre-existing wineprefix folder named $GAME.
#
if [ -d "$WINE_WINEPREFIX_HOME/$GAME" ]; then
  export WINEPREFIX="$WINE_WINEPREFIX_HOME/$GAME"
elif [ -d "$WINE_WINEPREFIX_HOME/unity" ]; then
  export WINEPREFIX="$WINE_WINEPREFIX_HOME/unity"
else
  export WINEPREFIX="$WINE_WINEPREFIX_HOME/unity"
fi
export WINEDLLOVERRIDES="d3d8,d3d9,d3d10core,d3d11,dxgi=n,b"   # force DXVK (if available)

# Avoid MangoHud/LD_PRELOAD issues
unset LD_PRELOAD
export MANGOHUD=0

# -------- Checks & Log --------
if [ ! -f "$EXEC_PATH" ]; then
  echo "[ERROR] '$EXEC_PATH' not found. Please place the EXE in '$EXEC_DIR'."
  exit 1
fi

mkdir -p "$GAMEDIR"
cd "$GAMEDIR"
: > "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

echo "[INFO] GAMEDIR:            $GAMEDIR"
echo "[INFO] WINE_VERSION:       $WINE_VERSION"
echo "[INFO] WINE:               $WINE"
echo "[INFO] WINEPREFIX:         $WINEPREFIX"
echo "[INFO] EXEC_DIR:           $EXEC_DIR"
echo "[INFO] EXEC_PATH:          $EXEC_PATH"
echo "[INFO] EXEC_NAME:          $EXEC_NAME"
echo "[INFO] SPLASH:             $SPLASH"

# Create Wineprefix (only on first run)
if [ ! -f "$WINEPREFIX/system.reg" ]; then
  echo "[SETUP] Creating Wineprefix at $WINEPREFIX"
  mkdir -p "$WINEPREFIX"
  $BOX $WINE wineboot
fi

# -------- Create a symbolic link in "Program Files" just in case --------.
WINEPREFIX_SYMLINK="$WINEPREFIX/drive_c/Program Files/$GAME"
echo "[INFO] WINEPREFIX_SYMLINK: $WINEPREFIX_SYMLINK"
if [ ! -L "$WINEPREFIX_SYMLINK" ]; then
  echo "[SETUP] Creating Symlink @ $WINEPREFIX_SYMLINK"
  ln -sf "$GAMEDIR" "$WINEPREFIX_SYMLINK"
fi

# -------- Show splash (your custom one) --------
if [ -e "$SPLASH" ] && [ -f "$GAMEDIR/splash.png" ]; then
  "$SPLASH" "$GAMEDIR/splash.png" 30000 &
fi

# -------- Set SDL exports, windows as the video driver for SDL -------
export SDL_VIDEODRIVER=windows
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# -------- Controller mapping (optional) --------
export TEXTINPUTPRESET="PLAYER"         # defines preset text to insert
export TEXTINPUTINTERACTIVE="Y"         # enables interactive text input mode
export TEXTINPUTNOAUTOCAPITALS="Y"      # disables automatic capitalisation of first letter of words in interactive tex>
export TEXTINPUTADDEXTRASYMBOLS="Y"     # enables additional symbols for interactive text input
export TEXTINPUTNUMBERSONLY="Y"         # only scrolls integers 0 - 9 in interactive text input mode
if [ -n "$GPTOKEYB" ] && [ -f "$GAMEDIR/$GAME.gptk" ]; then
  echo "[INFO] Loading GPTK profile"
  $GPTOKEYB "$EXEC_NAME" -c "$GAMEDIR/$GAME.gptk" &
elif [ -n "$GPTOKEYB" ]; then
  echo "[INFO] Loading GPTK without profile"
  $GPTOKEYB "$EXEC_NAME" &
fi

# -------- Save/Config bindings --------
BIND_DIRECTORY_SRC="$WINEPREFIX/drive_c/users/root/AppData/LocalLow/$GAME"
BIND_DIRECTORY_DST="$GAMEDIR/config"
mkdir -p "$BIND_DIRECTORY_SRC"
mkdir -p "$BIND_DIRECTORY_DST"
if [[ -d "$BIND_DIRECTORY_SRC" && -d "$BIND_DIRECTORY_DST" ]]; then
  if grep -q "$BIND_DIRECTORY_SRC" /proc/mounts; then
    echo "[INFO] Bind mount already exists at $BIND_DIRECTORY_SRC"
  else
    echo "[INFO] Creating bind mount from $BIND_DIRECTORY_SRC to $BIND_DIRECTORY_DST"
    mount --bind "$BIND_DIRECTORY_SRC" "$BIND_DIRECTORY_DST"
  fi
fi

# -------- Launch game --------
echo "[INFO] Launching game "
cd "$EXEC_DIR"
$BOX $WINE "./$EXEC_NAME" &
GAMEPID=$!
wait $GAMEPID

# -------- Cleanup --------
wineserver -k
pm_finish
echo "[INFO] Unmounting the bind from $BIND_DIRECTORY_SRC to $BIND_DIRECTORY_DST"
umount "$BIND_DIRECTORY_DST"
rm -f "$WINEPREFIX_SYMLINK"
