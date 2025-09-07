# ESP8266 GPIO Configuration Notes

## GPIO5 (D1 on NodeMCU) - Pin Analysis

### GPIO5 Characteristics:
- **Safe for OUTPUT**: ✅ Yes, GPIO5 is safe for digital output
- **Boot state**: Normally HIGH during boot, then can be controlled
- **Pull-up**: No internal pull-up during boot
- **Special functions**: Can be used for SPI (SCK), but not required for basic GPIO

### Relay Control Best Practices:
- GPIO5 is one of the recommended pins for relay control
- No boot-time restrictions (unlike GPIO0, GPIO2, GPIO15)
- Can drive relay modules directly with proper current limiting

### Common Issues with Relays:
1. **Power Supply**: Relays require adequate current (often more than ESP8266 can provide)
2. **Logic Levels**: Some relay modules are inverted (LOW = ON, HIGH = OFF)
3. **Current Draw**: Use external transistor/optocoupler for high-current relays

### Debugging Steps:
1. Verify relay module logic (active HIGH or LOW)
2. Check power supply to relay module
3. Test with simple digitalWrite in loop()
4. Use multimeter to verify voltage levels
5. Check relay module LED indicator

### Alternative GPIO Pins for Relay Control:
- GPIO4 (D2) - Also excellent for relay control
- GPIO12 (D6) - Good option
- GPIO13 (D7) - Good option
- GPIO14 (D5) - Good option

### Avoid for Relay Control:
- GPIO0 (D3) - Boot mode pin
- GPIO2 (D4) - Boot mode pin  
- GPIO15 (D8) - Boot mode pin
- GPIO16 (D0) - Special wake-up pin, limited functionality
