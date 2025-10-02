#!/bin/bash
# HomeGuard - Instalação do monitor de rede elétrica com ESP32-C3
# Uso: ./install.sh
# Do it before:
# pip install adafruit-ampy
# Download firmware from: https://micropython.org/download/esp32c3/
# Connect the ESP32-C3 via USB and check the port (e.g., /dev/ttyUSB0 or /dev/cu.usbmodem14101)
# how to check the port of your ESP32-C: run esptool flash_id    


# Examples of MQTT commands to control the device:
# mosquitto_pub -h 100.87.71.125  -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR_C3B/command" -m "OFF"
# mosquitto_pub -h 100.87.71.125  -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR_C3B/command" -m "ON"
# mosquitto_pub -h 100.87.71.125  -u homeguard -P pu2clr123456 -t "home/grid/GRID_MONITOR_C3B/command" -m "AUTO"    


esptool --chip esp32c3 erase_flash
esptool --chip esp32c3 --baud 460800 write_flash -z 0x0 ~/Downloads/ESP32_GENERIC_C3-20250911-v1.26.1.bin

ampy --port /dev/cu.usbmodem14101 put ./main.py
ampy --port /dev/cu.usbmodem14101 put ./simple.py