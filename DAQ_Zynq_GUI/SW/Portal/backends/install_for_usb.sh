
#!/bin/bash


cat << EOF | sudo tee /etc/udev/rules.d/61-frapopm-usb.rules
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="03fd", ATTRS{idProduct}=="0000", MODE="0666"
EOF

sudo udevadm control --reload-rules

echo End