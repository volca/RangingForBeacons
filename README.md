# Ranging for Beacons

Detect that the device is in a beacon region and range.

## Overview

Ranging is the process of reading the characteristics of a beacon region. Characteristics include information such as signal strength, advertising interval, and measured power.

The app opens directly into ranging: it monitors a fixed set of beacon identities and lists every beacon it sees, grouped by UUID and sorted by proximity.

- Note: This project is associated with WWDC 2019 session [705: What's New in Location](https://developer.apple.com/videos/play/wwdc19/705/).

## Range for Beacons

Launch the app and it starts scanning. The beacon identity is hardcoded in `RangeBeaconViewController.swift`: two UUIDs, `major` 1, and `minor` 7647.

``` swift
let defaultUUIDStrings = [
    "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0",
    "B5B182C7-EAB1-4988-AA99-B5C1517008D9"
]
let beaconMajor: CLBeaconMajorValue = 1
let beaconMinor: CLBeaconMinorValue = 7647
```

Add more UUIDs with the Add button in the upper corner of the screen; the major and minor values stay the same.

As in any location-based service, first request authorization. Use a `CLLocationManager` instance to request that authorization, build the constraint, then tell the instance to start monitoring and ranging.

``` swift
// Monitoring delivers region events while the device is locked, which
// requires "always" authorization.
self.locationManager.requestAlwaysAuthorization()

let constraint = CLBeaconIdentityConstraint(uuid: uuid, major: beaconMajor, minor: beaconMinor)
self.constraints.append(constraint)

/*
By monitoring for the beacon before ranging, the app is more
energy efficient if the beacon is not immediately observable.
*/
let beaconRegion = CLBeaconRegion(beaconIdentityConstraint: constraint, identifier: uuid.uuidString)
self.locationManager.startMonitoring(for: beaconRegion)
self.locationManager.startRangingBeacons(satisfying: constraint)
```

The [`locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion)`](x-source-tag://didDetermineState) delegate method starts ranging when the device is inside a region and stops it when the device leaves.

While one or more beacons are in range, the [`locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying beaconConstraint: CLBeaconIdentityConstraint)`](x-source-tag://didRange) delegate method receives their characteristics in the passed array.

## Range While the Device Is Locked

The app requests "always" authorization and declares the `location` background mode, so region monitoring keeps running while the device is locked or the app is in the background. The [`didEnterRegion`](x-source-tag://didEnterRegion) and [`didExitRegion`](x-source-tag://didExitRegion) delegate methods post a local notification, which appears on the lock screen.

Ranging itself, however, only delivers updates while the app is running in the foreground. When the app becomes active it asks for the state of every monitored region and starts ranging again for the regions the device is inside, so the table view repopulates as soon as the device is unlocked.

On iOS, beacon monitoring doesn't relaunch an app the user has force-quit from the app switcher.
