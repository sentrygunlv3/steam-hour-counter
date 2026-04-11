# Steam Hour Counter

> [!CAUTION]
> this needs a rewrite/cleanup and might have bugs\
> but it has been running on my pc every day without problems

counts steam hours when a non steam program is running\
so you can for example use the non steam version of blender and have steam count hours

to install you need to copy a `libsteam_api.so` file to the install-files directory\
and then run `sudo ./build-install` to install the daemon/service files\
then you can enable and start it

to uninstall stop the service and run `sudo ./uninstall`

the config is located at `~/.config/steam-hour-counter`\
it [this](https://github.com/sentrygunlv3/yet) format

you can view the log using `journalctl --user -u steam-hour-counter.service`
