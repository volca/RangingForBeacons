/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
View controller that illustrates how to monitor and range for beacon regions,
including while the device is locked or the app is in the background.
*/

import UIKit
import CoreLocation
import UserNotifications
import os

private let beaconLog = Logger(subsystem: "com.example.apple-samplecode.BeaconSample",
                               category: "Ranging")

class RangeBeaconViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {

    @IBOutlet weak var tableView: UITableView!

    /**
     The UUIDs the app monitors and ranges by default.
     The first one is the same UUID used in ConfigureBeaconViewController
     for creating a beacon.
     */
    let defaultUUIDStrings = [
        "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0",
        "B5B182C7-EAB1-4988-AA99-B5C1517008D9"
    ]

    /// The beacon identity the app ranges for.
    let beaconMajor: CLBeaconMajorValue = 1
    let beaconMinor: CLBeaconMinorValue = 7647

    /// This location manager is used to demonstrate how to range beacons.
    let locationManager = CLLocationManager()

    /// Keeps the table view sections in a stable order.
    private var constraints = [CLBeaconIdentityConstraint]()

    /// The most recent ranging result for each constraint.
    private var beacons = [CLBeaconIdentityConstraint: [CLBeacon]]()

    /// Regions the device is currently inside, so each detection notifies once.
    private var detectedRegionIdentifiers = Set<String>()

    /// Consecutive ranging reports with no beacon, per constraint.
    private var emptyRangeReportCounts = [CLBeaconIdentityConstraint: Int]()

    /// Consecutive ranging reports with at least one beacon, per constraint.
    private var beaconReportCounts = [CLBeaconIdentityConstraint: Int]()

    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.delegate = self

        /*
        Region monitoring is what keeps working while the device is locked or
        the app is in the background, and it requires "always" authorization.
        */
        locationManager.requestAlwaysAuthorization()

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)

        startMonitoringDefaultRegions()
    }

    /// Registers monitoring for every default UUID. Safe to call more than once.
    private func startMonitoringDefaultRegions() {
        for uuidString in defaultUUIDStrings {
            if let uuid = UUID(uuidString: uuidString) {
                addConstraint(for: uuid)
            }
        }
    }

    private func addConstraint(for uuid: UUID) {
        let constraint = CLBeaconIdentityConstraint(uuid: uuid, major: beaconMajor, minor: beaconMinor)
        guard !constraints.contains(constraint) else { return }

        constraints.append(constraint)
        beacons[constraint] = []
        emptyRangeReportCounts[constraint] = 0
        beaconReportCounts[constraint] = 0

        /*
        By monitoring for the beacon before ranging, the app is more
        energy efficient if the beacon is not immediately observable.
        Monitoring also continues while the device is locked.
        */
        beaconLog.notice("monitoring uuid=\(uuid.uuidString, privacy: .public) major=\(self.beaconMajor) minor=\(self.beaconMinor)")

        let beaconRegion = CLBeaconRegion(beaconIdentityConstraint: constraint, identifier: uuid.uuidString)
        locationManager.startMonitoring(for: beaconRegion)
        locationManager.requestState(for: beaconRegion)

        // Start ranging right away so results appear as soon as the app opens.
        locationManager.startRangingBeacons(satisfying: constraint)
    }

    @objc
    private func appDidBecomeActive() {
        /*
        Ranging only delivers updates while the app is in the foreground,
        so ask for the current state of every monitored region and let
        didDetermineState restart ranging for the ones we're inside of.
        */
        refreshRegionStates()
    }

    private func refreshRegionStates() {
        for region in locationManager.monitoredRegions {
            locationManager.requestState(for: region)
        }
    }

    @IBAction func addBeacon(_ sender: Any) {
        let alert = UIAlertController(title: "Add Beacon Region",
                                      message: "Enter UUID",
                                      preferredStyle: .alert)

        var uuidTextField: UITextField!

        alert.addTextField { textField in
            textField.placeholder = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
            textField.text = self.defaultUUIDStrings.first
            uuidTextField = textField
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let addAction = UIAlertAction(title: "Add", style: .default) { alert in
            if let uuidString = uuidTextField.text, let uuid = UUID(uuidString: uuidString) {
                self.locationManager.requestAlwaysAuthorization()
                self.addConstraint(for: uuid)
            } else {
                let invalidAlert = UIAlertController(title: "Invalid UUID",
                                                     message: "Please specify a valid UUID.",
                                                     preferredStyle: .alert)

                let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                invalidAlert.addAction(okAction)
                self.present(invalidAlert, animated: true)
            }
        }

        alert.addAction(cancelAction)
        alert.addAction(addAction)

        present(alert, animated: true)
    }

    // MARK: - Location Manager Delegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Permission can be granted after the first monitoring request.
        startMonitoringDefaultRegions()

        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            refreshRegionStates()
        }
    }

    /// - Tag: didDetermineState
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        beaconLog.notice("state=\(self.stateName(state), privacy: .public) region=\(region.identifier, privacy: .public)")

        guard let beaconRegion = region as? CLBeaconRegion else { return }

        if state == .inside {
            // Start ranging when inside a region.
            manager.startRangingBeacons(satisfying: beaconRegion.beaconIdentityConstraint)
        } else if state == .outside {
            /*
            Only an explicit outside clears the detection. The unknown state
            that follows a launch carries no information about the beacon, and
            inside can be a cached value reported before the first scan, so
            neither notifies; a notification requires a real advertisement
            (ranging) or a region entry.
            */
            manager.stopRangingBeacons(satisfying: beaconRegion.beaconIdentityConstraint)
            detectedRegionIdentifiers.remove(region.identifier)
        }
    }

    private func stateName(_ state: CLRegionState) -> String {
        switch state {
        case .inside:
            return "inside"
        case .outside:
            return "outside"
        default:
            return "unknown"
        }
    }

    /// - Tag: didEnterRegion
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        beaconLog.notice("didEnterRegion region=\(region.identifier, privacy: .public)")
        /*
        This callback is delivered while the device is locked or the app is in
        the background, so surface it with a local notification.
        */
        notifyDetection(for: region.identifier)
    }

    /// - Tag: didExitRegion
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        beaconLog.notice("didExitRegion region=\(region.identifier, privacy: .public)")
        detectedRegionIdentifiers.remove(region.identifier)

        guard let beaconRegion = region as? CLBeaconRegion else { return }
        beacons[beaconRegion.beaconIdentityConstraint] = []
        emptyRangeReportCounts[beaconRegion.beaconIdentityConstraint] = 0
        beaconReportCounts[beaconRegion.beaconIdentityConstraint] = 0
        tableView.reloadData()
    }

    /// - Tag: didRange
    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying beaconConstraint: CLBeaconIdentityConstraint) {
        // A beacon can satisfy multiple constraints, so key results by constraint.
        self.beacons[beaconConstraint] = beacons

        for beacon in beacons {
            beaconLog.notice("didRange uuid=\(beacon.uuid.uuidString, privacy: .public) major=\(beacon.major.intValue) minor=\(beacon.minor.intValue) rssi=\(beacon.rssi) proximity=\(String(describing: beacon.proximity), privacy: .public)")
        }

        /*
        While the app is in the foreground, a beacon that disappears from
        ranging is treated as gone without waiting for the region exit, so
        toggling a beacon off and on notifies again. Two empty reports in a
        row are required to ignore a single dropped scan.
        */
        if beacons.isEmpty {
            beaconReportCounts[beaconConstraint] = 0

            let count = (emptyRangeReportCounts[beaconConstraint] ?? 0) + 1
            emptyRangeReportCounts[beaconConstraint] = count
            if count >= 3 {
                detectedRegionIdentifiers.remove(beaconConstraint.uuid.uuidString)
            }
        } else {
            emptyRangeReportCounts[beaconConstraint] = 0

            /*
            A single report can be a stray packet from a beacon that is
            switching identity, so require two sightings in a row.
            */
            let count = (beaconReportCounts[beaconConstraint] ?? 0) + 1
            beaconReportCounts[beaconConstraint] = count
            if count >= 2 {
                notifyDetection(for: beaconConstraint.uuid.uuidString)
            }
        }

        tableView.reloadData()
    }

    /// Posts one notification the first time each UUID is detected.
    private func notifyDetection(for identifier: String) {
        guard detectedRegionIdentifiers.insert(identifier).inserted else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(uuidLabel(for: identifier)) detected"
        content.body = identifier
        content.sound = .default

        beaconLog.notice("notify \(self.uuidLabel(for: identifier), privacy: .public) for \(identifier, privacy: .public)")

        let request = UNNotificationRequest(identifier: identifier + "-" + UUID().uuidString,
                                           content: content,
                                           trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Names the default UUIDs "UUID1" and "UUID2"; any added UUID keeps its string.
    private func uuidLabel(for identifier: String) -> String {
        if let index = defaultUUIDStrings.firstIndex(where: {
            $0.caseInsensitiveCompare(identifier) == .orderedSame
        }) {
            return "UUID\(index + 1)"
        }
        return identifier
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Shows the banner even while the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Table View Data Source

    func numberOfSections(in tableView: UITableView) -> Int {
        return constraints.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return constraints[section].uuid.uuidString
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedBeacons(in: section).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

        let beacon = sortedBeacons(in: indexPath.section)[indexPath.row]

        // Display the proximity, signal strength, and identity of each beacon.
        cell.textLabel?.text = "\(proximityName(beacon.proximity))  RSSI: \(beacon.rssi)"
        cell.detailTextLabel?.text = "Major: \(beacon.major) Minor: \(beacon.minor)"

        return cell
    }

    /// The beacons of one UUID, closest first.
    private func sortedBeacons(in section: Int) -> [CLBeacon] {
        let proximityOrder: [CLProximity] = [.immediate, .near, .far, .unknown]
        return (beacons[constraints[section]] ?? []).sorted {
            let lhs = proximityOrder.firstIndex(of: $0.proximity) ?? proximityOrder.count
            let rhs = proximityOrder.firstIndex(of: $1.proximity) ?? proximityOrder.count
            return lhs < rhs
        }
    }

    private func proximityName(_ proximity: CLProximity) -> String {
        switch proximity {
        case .immediate:
            return "Immediate"
        case .near:
            return "Near"
        case .far:
            return "Far"
        default:
            return "Unknown"
        }
    }
}
