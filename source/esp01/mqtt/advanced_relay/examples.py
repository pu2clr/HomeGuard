#!/usr/bin/env python3
"""
HomeGuard Advanced Relay - Quick Control Examples
Simple examples showing how to use the AdvancedRelayController
"""

import time
import sys
import os

# Add the current directory to Python path so we can import the controller
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from advanced_relay_controller import AdvancedRelayController


def example_basic_control():
    """Example: Basic relay control"""
    print("🔄 Example: Basic Relay Control")
    print("-" * 40)
    
    # Create controller
    controller = AdvancedRelayController()
    
    # Connect
    if not controller.connect():
        print("❌ Failed to connect")
        return
    
    try:
        # Wait for connection to stabilize
        time.sleep(2)
        
        # Request initial status
        print("📊 Requesting device status...")
        controller.request_status()
        time.sleep(2)
        
        # Turn relay ON
        print("🟢 Turning relay ON...")
        controller.relay_on()
        time.sleep(3)
        
        # Turn relay OFF
        print("🔴 Turning relay OFF...")
        controller.relay_off()
        time.sleep(3)
        
        # Toggle relay
        print("🔄 Toggling relay...")
        controller.relay_toggle()
        time.sleep(3)
        
        print("✅ Basic control example completed!")
        
    except KeyboardInterrupt:
        print("\n⏹️  Example interrupted")
    
    finally:
        controller.disconnect()


def example_configuration():
    """Example: Device configuration"""
    print("🔄 Example: Device Configuration")
    print("-" * 40)
    
    controller = AdvancedRelayController()
    
    if not controller.connect():
        print("❌ Failed to connect")
        return
    
    try:
        time.sleep(2)
        
        # Set device location
        print("📍 Setting device location to 'TestLab'...")
        controller.set_location("TestLab")
        time.sleep(2)
        
        # Configure heartbeat
        print("💓 Setting heartbeat interval to 30 seconds...")
        controller.set_heartbeat_interval(30)
        time.sleep(2)
        
        # Enable status LED
        print("💡 Enabling status LED...")
        controller.enable_status_led()
        time.sleep(2)
        
        # Request status to see changes
        print("📊 Requesting updated status...")
        controller.request_status()
        time.sleep(3)
        
        print("✅ Configuration example completed!")
        
    except KeyboardInterrupt:
        print("\n⏹️  Example interrupted")
    
    finally:
        controller.disconnect()


def example_monitoring():
    """Example: Monitor device for 30 seconds"""
    print("🔄 Example: Device Monitoring")
    print("-" * 40)
    
    controller = AdvancedRelayController()
    
    if not controller.connect():
        print("❌ Failed to connect")
        return
    
    try:
        time.sleep(2)
        controller.monitoring = True
        
        print("📡 Monitoring device for 30 seconds...")
        print("💡 Try controlling the relay from another terminal or the Arduino IDE!")
        print("   Example: mosquitto_pub -h 192.168.18.6 -t home/relay1/cmnd -m 'TOGGLE' -u homeguard -P pu2clr123456")
        print("⏹️  Press Ctrl+C to stop monitoring early")
        
        # Request status every 10 seconds
        for i in range(3):
            if i > 0:
                controller.request_status()
            time.sleep(10)
            
        print("✅ Monitoring example completed!")
        
    except KeyboardInterrupt:
        print("\n⏹️  Monitoring stopped")
    
    finally:
        controller.disconnect()


def example_event_history():
    """Example: Demonstrate event history tracking"""
    print("🔄 Example: Event History Tracking")
    print("-" * 40)
    
    controller = AdvancedRelayController()
    
    if not controller.connect():
        print("❌ Failed to connect")
        return
    
    try:
        time.sleep(2)
        
        print("🎯 Generating relay events for history demonstration...")
        
        # Generate some events
        for i in range(3):
            print(f"Event {i+1}: Toggle relay")
            controller.relay_toggle()
            time.sleep(4)  # Wait for event to be processed
        
        # Show event history
        print("\n📜 Displaying event history:")
        controller.show_event_history(10)
        
        print("✅ Event history example completed!")
        
    except KeyboardInterrupt:
        print("\n⏹️  Example interrupted")
    
    finally:
        controller.disconnect()


def main():
    """Main function to run examples"""
    examples = {
        '1': ('Basic Control', example_basic_control),
        '2': ('Configuration', example_configuration),
        '3': ('Monitoring', example_monitoring),
        '4': ('Event History', example_event_history)
    }
    
    print("🎛️  HomeGuard Advanced Relay Controller - Examples")
    print("=" * 50)
    print("Choose an example to run:")
    print()
    
    for key, (name, _) in examples.items():
        print(f"  {key}. {name}")
    
    print("  q. Quit")
    print()
    
    try:
        choice = input("Enter your choice (1-4 or q): ").strip().lower()
        
        if choice == 'q':
            print("👋 Goodbye!")
            return
        
        if choice in examples:
            name, func = examples[choice]
            print(f"\n🚀 Running example: {name}")
            print("=" * 50)
            func()
        else:
            print("❌ Invalid choice!")
    
    except KeyboardInterrupt:
        print("\n👋 Goodbye!")
    except Exception as e:
        print(f"❌ Error: {e}")


if __name__ == "__main__":
    main()
