# Alfred App Audio Switcher Workflow
This is a workflow for [Alfred](https://alfred.app/).

## About the Workflow
This workflow supports quickly switching sound input and output devices.

It offers hotkeys to quickly switch between three input favorites and output favorites.
You can also use a single hotkey to rotate among the favorites in sequence.
Those can also be triggered using Alfred Remote.

### Listing Devices
Once installed, use the `fetchaudiodevices` command in Alfred. Once you have selected either "Outputs" or "Inputs",
the workflow will copy a list of devices to the Clipboard. This is a convenience feature to support filling the
*Ignorelist*, *Output Favorites* and *Input Favorites*. (See below)

### Parameter Examples

#### Ignorelist
The value
```
External Headphones
iPhone Microphone
```
causes both listed devices not to be listed when selecting inputs or outputs.


#### Output Favorites
The value
```
MacBook Pro Speakers
RØDE Connect Virtual
External Screen
```
means the following:
- *⌘ + F1* will select MacBook Pro Speakers.
- *⌘ + F2* will select RØDE Connect Virtual.
- *⌘ + F3* will select External Screen.

#### Input Favorites
The value
```
MacBook Pro Microphone
RØDE Connect Stream
```
means the following:
- *⌥ + F1* will select MacBook Pro Microphone.
- *⌥ + F2* will select RØDE Connect Stream.
- *⌥ + F3* will have no effect.

## Like this Workflow?
[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://buymeacoffee.com/tobimende)
