# Zigbee2Mqtt Helpers Scripts

This project is a collection of scripts to simplify and enhance your experience with Zigbee2MQTT. Currently, we feature one script, `z2m_ota.sh`, with maybe more Zigbee-related tools planned for the future. These scripts are free, open-source, and crafted with ❤️ by [soif](https://github.com/soif).


## z2m_ota.sh

The `z2m_ota.sh` script is a handy workaround for automating Over-The-Air (OTA) updates for Zigbee devices in Zigbee2MQTT. It eliminates the need to manually restart failed updates through the GUI, which is especially useful when the Zigbee adapter or network crashes during updates.

### How It Works

The script monitors the device’s update state via MQTT and automatically retries failed OTA updates. Zigbee devices retain previously updated data between attempts, so each retry builds on prior progress, ensuring the update eventually completes. 

**Note**: This process may put some stress on your Zigbee network, but it’s a reliable way to get updates finished.

### Example Usage

`./z2m_ota.sh -s 192.168.1.24 -u user -p pass "DeviceFriendlyName"`

### Help Output

```text
$ z2m_ota.sh --help
z2m_ota.sh, version 1.00
Allows to force OTA updates for Zigbee devices when the adapter/network is crashing during OTA upgrades.

USAGE  : z2m_ota.sh [-s host] [-u user] [-p password] [-t wait_time] [-h|--help] <TOPIC>
Options:
  <TOPIC>        MQTT topic (FriendlyName) of the device to be updated (REQUIRED)
  -s host        MQTT Server              (default: localhost)
  -u user        MQTT username            (default: none) --> UNTESTED, PLEASE REPORT
  -p password    MQTT password            (default: none) --> UNTESTED, PLEASE REPORT
  -t wait_time   Seconds until next retry (default: 20 sec)
  -h, --help     Displays this help message and exit
```

### Dependencies

- **`mosquitto_pub` and `mosquitto_sub`**: Required for MQTT communication.
- **`jq`** (optional, recommended): For robust JSON parsing.

*Install on Debian: `sudo apt update && sudo apt install mosquitto-clients jq`*

### Tips for Success

- **Speed Up Initial Check**: The script waits for an MQTT message to detect if an update is in progress or available. Speed this up by clicking any refresh icon in the device's "Exposes" tab in the Zigbee2MQTT GUI.
- **Ensure Update Availability**: The script requires an available update in the MQTT state message. First, check for updates in the Zigbee2MQTT GUI, as the script doesn’t initiate this.
- **Stay Close**: Keep your device close to the coordinator for reliable transmission, reducing retry steps.
- **Tweak for Stability**: If updates are unstable, increase the "Image block response delay" in Zigbee2MQTT (e.g., from 500ms to 800ms).

## Get Involved

We’d love to see this project grow with your help! Contributions are welcome via pull requests (PRs) for bug fixes, improvements, or new Zigbee2MQTT scripts.

If this script saved you time or frustration, consider buying me a beer! 🍺


[![Buy me a beer](https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20beer&emoji=🍺&slug=soif&button_colour=ff0000&font_colour=ffffff&font_family=Comic&outline_colour=000000&coffee_colour=ffffff)](https://www.buymeacoffee.com/soif)


