/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
View controller that illustrates how to monitor and range for beacon regions,
including while the device is locked or the app is in the background.
*/

import UIKit
import CoreLocation
import UserNotifications

class RangeBeaconViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CLLocationManagerDelegate {

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

    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.delegate = self

        /*
        Region monitoring is what keeps working while the device is locked or
        the app is in the background, and it requires "always" authorization.
        */
        locationManager.requestAlwaysAuthorization()

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

        /*
        By monitoring for the beacon before ranging, the app is more
        energy efficient if the beacon is not immediately observable.
        Monitoring also continues while the device is locked.
        */
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
        guard let beaconRegion = region as? CLBeaconRegion else { return }

        if state == .inside {
            // Start ranging when inside a region.
            manager.startRangingBeacons(satisfying: beaconRegion.beaconIdentityConstraint)
        } else {
            // Stop ranging when not inside a region.
            manager.stopRangingBeacons(satisfying: beaconRegion.beaconIdentityConstraint)
        }
    }

    /// - Tag: didEnterRegion
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        /*
        This callback is delivered while the device is locked or the app is in
        the background, so surface it with a local notification.
        */
        postNotification(for: region, entered: true)
    }

    /// - Tag: didExitRegion
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        postNotification(for: region, entered: false)

        guard let beaconRegion = region as? CLBeaconRegion else { return }
        beacons[beaconRegion.beaconIdentityConstraint] = []
        tableView.reloadData()
    }

    /// - Tag: didRange
    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying beaconConstraint: CLBeaconIdentityConstraint) {
        // A beacon can satisfy multiple constraints, so key results by constraint.
        self.beacons[beaconConstraint] = beacons
        tableView.reloadData()
    }

    private func postNotification(for region: CLRegion, entered: Bool) {
        // The table view already shows the result while the app is on screen.
        guard UIApplication.shared.applicationState != .active else { return }

        let content = UNMutableNotificationContent()
        content.title = entered ? "Beacon Region Entered" : "Beacon Region Exited"
        content.body = region.identifier
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                           content: content,
                                           trigger: nil)
        UNUserNotificationCenter.current().add(request)
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
