# Steam Hour Counter

counts steam hours when a non steam program is running\
so you can for example use the non steam version of blender and have steam count hours

to install you need to copy a `libsteam_api.so` file to the install-files directory\
and then run `sudo ./build-install` to install the daemon/service files\
then you can enable and start it

to uninstall stop the service and run `sudo ./uninstall`

the config is located at `~/.config/steam-hour-counter`\
it uses [qlist](https://github.com/sentrygunlv3/qlist) and the programs are listed in this format `s blender 365670`

you can view the log using `journalctl --user -u steam-hour-counter.service`
