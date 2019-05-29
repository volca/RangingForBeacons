# Ranging for Beacons

Detect that the device is in a beacon region, then use ranging to find the beacons within the region.


## Overview

- Note: This sample code project is associated with WWDC 2019 session [705: What's New in Location](https://developer.apple.com/videos/play/wwdc19/705/).


## Running this Sample App

This sample project has two features:
* Configure your device to be a beacon. If you don't have an iBeacon device, you can turn an iOS device into a beacon by tapping Configure a Beacon in the sample app. The UUID is hardcoded; you can optionally add a major and minor value for your beacon. Select the Enabled switch on the configuration screen to start transmitting.
* Use ranging to find beacons around you. Using a different iOS device, run the sample app and tap Range for Beacons to scan for beacons near you. Add a UUID to range for by tapping the Add button in the upper corner of the screen. The hardcoded UUID appears by default, and you can overwrite it with other UUID values.

The sample code contains the following files:
* 'RangeBeaconViewController.swift' contains a view controller that ranges a set of beacon regions that the user adds.
* 'ConfigureBeaconViewController.swift' contains a view controller that configures the iOS device running this app as a beacon.
