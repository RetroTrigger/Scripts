#!/bin/bash
sudo apt-get install -y openbox lightdm lightdm-gtk-greeter firefox obconf obmenu nitrogen leafpad lxappearance lxterminal usbmount \
xcompmgr plank menu conky terminator
sudo mkdir -p ~/.config/openbox
sudo chmod +x autostart.sh
sudo cp autostart.sh rc.xml menu.xml ~/.config/openbox
