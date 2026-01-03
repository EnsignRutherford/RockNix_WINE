#!/bin/bash
WINE_VERSIONS=( "/storage/.config/wine-10.19-amd64/bin/wine"
                "/storage/.config/wine-10.16-amd64/bin/wine"
                "/storage/.config/wine-9.16-amd64/bin/wine"
                "/storage/.config/wine-8.21-amd64/bin/wine"
                "/storage/.config/wine-proton-10.0-3-amd64/bin/wine"
                "/storage/.config/wine-proton-10.0-2-amd64/bin/wine"
                "/storage/.config/wine-proton-9.0-4-amd64/bin/wine"
        )
/roms/rocknix/wine/wine_windows_wrapper.sh Timespinner wine-proton-10.0-3


