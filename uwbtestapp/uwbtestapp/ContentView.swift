import SwiftUI
import EstimoteUWB

let enum_dict = [1 : "e159ca3764f64b66b0c6267879d9d627",
                 2 : "b1cfd524bce7ebe5101d0593cc08b61f",
                 3 : "b55f24147b765df50deaf90431b6473d",
                 4 : "e2f7b1f9b643c532622ce31c5de47d38",
                 5 : "55fd2c90348b3e9d28aae8244f249f0e",
                 6 : "8c55b717ba786b21978cafef9d924d06"]

struct DefaultKeys {
    static let beacon_radius = "beacon_radius"
    static let beacon_angle = "beacon_angle"
}

let m_to_pixel_mult = 50.0
let INFINITY = Double.greatestFiniteMagnitude

var beacon_dict = [String : Beacon]() // (id : Beacon object)

class Beacon : Comparable, CustomStringConvertible{
    static func < (lhs: Beacon, rhs: Beacon) -> Bool {
        return lhs.num < rhs.num
    }
    
    static func == (lhs: Beacon, rhs: Beacon) -> Bool {
        return lhs.num == rhs.num
    }
    
    public var description: String {return "Beacon: \(name), num: \(num), dist: \(dist)"}
    
    var id = ""
    var num = 0
    var angle = 0.0
    var radius = 1.0
    var dist = 1000.0
    var name = "."
    var lastUpdate = Date()
    
}

func getBeaconNumByID(id : String) -> Int{
    for (key, val) in enum_dict{
        if (val == id){
            return key
        }
    }
    
    return -1
}

struct ContentView: View {
    @ObservedObject var uwb = UWBManager()
    @State private var radiusInput = ""
    @State private var angleInput = ""
    @State private var settings_beacons_use = ""
    @State private var showingAlert : [Bool] = Array(repeating: false, count: UWBManager.max_focused)
    @State private var settingsAlert = false
    
    var body: some View {
        if uwb.update{}
        ZStack{
            
            ForEach(uwb.focused.sorted(by: <), id : \.key){ (index, beacon) in
                ZStack {
                    let circleColor = index < UWBManager.beacons_used_for_localization ? Color.blue : Color(UIColor.systemGray)
                    Circle()
                        .stroke(circleColor, lineWidth: 4)
                        .frame(width: CGFloat(beacon.dist * m_to_pixel_mult * 2), height: CGFloat(beacon.dist * m_to_pixel_mult * 2))
                    
                    Button(beacon.name){
                        showingAlert[index].toggle()
                    }
                    .alert(String("Enter '\(beacon.name)' radius and angle"), isPresented: $showingAlert[index]){
                        TextField(String(format:"radius (currently: %.2f)", beacon.radius), text: $radiusInput)

                        TextField(String(format:"angle (currently: %.2f)", beacon.angle), text: $angleInput)
                        Button("OK", action: {() in self.updateBeaconLocation(id: beacon.id)})
                    }
                    
                }
                .position(beacon_draw_coords(beaconNum: beacon.num))
                .frame(width: 0, height: 0)
            }
            
            Text("@")
                .offset(x: uwb.atX * m_to_pixel_mult, y: uwb.atY * m_to_pixel_mult)
            
            Text(String(format: "Distance to Center: %.2f", pow(uwb.atX * uwb.atX + uwb.atY * uwb.atY, 0.5)))
                .offset(x: 0, y: -200)
        }
        
        
        Button("settings"){
            settingsAlert.toggle()
        }
        .alert(String("Settings"), isPresented: $settingsAlert){
            TextField(String(format:"beacons to use (c: %d)", UWBManager.beacons_used_for_localization), text: $settings_beacons_use)

            Button("OK", action: {() in self.updateSettings()})
        }.offset(x: 0, y: 360)
        
        
    }
    func updateSettings(){
        UWBManager.beacons_used_for_localization = Int(settings_beacons_use) ?? UWBManager.beacons_used_for_localization
        settings_beacons_use = ""
    }
    func updateBeaconLocation(id: String){
        let beacon = beacon_dict[id]!
        beacon.radius = max(Double(radiusInput) ?? beacon.radius, 0.01)
        beacon.angle = max(Double(angleInput) ?? beacon.angle, 0)
        
        let defaults = UserDefaults.standard
        defaults.set(beacon.radius, forKey: String("radius_" + beacon.id))
        defaults.set(beacon.angle, forKey: String("angle_" + beacon.id))
        
        radiusInput = ""
        angleInput = ""
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

class UWBManager : ObservableObject{
    static var max_focused = 6
    static var beacons_used_for_localization = 3
    static var beacon_timeout = 1.0
    private var uwbManager: EstimoteUWBManager?
    
    @Published var focused = [Int : Beacon]()
    @Published var update = false
    
    @Published var atX = 0.0
    @Published var atY = 0.0

    let radiusBuffer = 0.05
    let smoothing_const = 0.0
    
    init() {
        setupUWB()
    }
    
    private func setupUWB() {
        uwbManager = EstimoteUWBManager(positioningObserver: self, discoveryObserver: self, beaconRangingObserver: self)
        uwbManager?.startScanning()
    }
    
    
}

// REQUIRED PROTOCOL
extension UWBManager: UWBPositioningObserver {
    
    func didUpdatePosition(for device: UWBDevice) {
        
        //print("position updated for device: \(device)")
        let beacon: Beacon = beacon_dict[device.publicId]!
        beacon.dist = Double(beacon.dist) * (smoothing_const) + Double(device.distance) * (1-smoothing_const)
        beacon.dist = max(beacon.dist, 0.01)
        beacon.lastUpdate = Date()
        
        var found = false
        let time = Date()
        for (index, object) in focused{
            if time.timeIntervalSince(beacon.lastUpdate) > UWBManager.beacon_timeout {
                beacon.dist = INFINITY
                focused[index] = nil // remove key:value pair
                break
            }
            if beacon.id == object.id{
                found = true
                var changed = true
                var i = index
                while changed == true{ // sort beacons in list
                    changed = false
                    if index > 0 && beacon.dist < focused[i - 1]?.dist ?? -1{
                        let temp = focused[i-1]
                        focused[i-1] = beacon
                        focused[i] = temp
                        changed = true
                        i = i - 1
                    }
                    if index < focused.count - 1 && beacon.dist > focused[i + 1]?.dist ?? INFINITY{
                        let temp = focused[i+1]
                        focused[i+1] = beacon
                        focused[i] = temp
                        changed = true
                        i = i + 1
                    }
                }
                update.toggle()
                break
            }
        }
        if found == false{
            if (focused.count < UWBManager.max_focused){
                focused[focused.count] = beacon
                update.toggle()
            }
            else{ // insert in order
                var insert = beacon
                var changed = false
                for i in 0...(focused.count - 1){
                    if focused[i]!.dist > insert.dist{
                        let temp = focused[i]!
                        focused[i] = insert
                        insert = temp
                        changed = true
                    }
                }
                if changed{
                    update.toggle()
                }
//                for i in 0...(focused.count - 1){
//                    print(i, focused[i]! as Any)
//                }
//                print("---")
            }
            
            // load saved beacon location
            let defaults = UserDefaults.standard
            let beacon_radius = defaults.double(forKey: String("radius_" + beacon.id))
            let beacon_angle = defaults.double(forKey: String("angle_" + beacon.id))
            
            if beacon_radius > 0.0 {
                beacon.radius = beacon_radius
                beacon.angle = beacon_angle
            }
            
        }
        if focused.count < 3{
            return
        }
        
        var use_beacons: [Beacon] = []
        for i in 0...min(focused.count - 1, UWBManager.beacons_used_for_localization){
            use_beacons.append(focused[i]!)
        }
                
        let at = localize_on_beacons(beacons: use_beacons, radiusBuffer: radiusBuffer)
        
        if at.dist >= 0.0{
            atX = at.x
            atY = at.y
        }
        
    }
}

// OPTIONAL PROTOCOL FOR BEACON BLE RANGING
extension UWBManager: BeaconRangingObserver {
    func didRange(for beacon: BLEDevice) {
//        print("beacon did range: \(beacon)")
    }
}

// OPTIONAL PROTOCOL FOR DISCOVERY AND CONNECTIVITY CONTROL
extension UWBManager: UWBDiscoveryObserver {
    var shouldConnectAutomatically: Bool {
        return true // set this to false if you want to manage when and what devices to connect to for positioning updates
    }
    
    func didDiscover(device: UWBIdentifable, with rssi: NSNumber, from manager: EstimoteUWBManager) {
        print("Discovered Device: \(device.publicId) rssi: \(rssi)")
        
        // if shouldConnectAutomatically is set to false - then you could call manager.connect(to: device)
        // additionally you can globally call discoonect from the scope where you have inititated EstimoteUWBManager -> disconnect(from: device) or disconnect(from: publicId)
    }
    
    func didConnect(to device: UWBIdentifable) {
        print("Successfully Connected to: \(device.publicId)")
        if (beacon_dict[device.publicId] == nil) { // init beacon
            let newBeacon = Beacon()
            newBeacon.id = device.publicId
            newBeacon.num = getBeaconNumByID(id: device.publicId)
            newBeacon.name = String(newBeacon.num)
            newBeacon.lastUpdate = Date()
            beacon_dict[device.publicId] = newBeacon
        }
    }
    
    func didDisconnect(from device: UWBIdentifable, error: Error?) {
        print("Disconnected from device: \(device.publicId)- error: \(String(describing: error))")
        beacon_dict[device.publicId]?.dist = 1000
    }
    
    func didFailToConnect(to device: UWBIdentifable, error: Error?) {
        print("Failed to conenct to: \(device.publicId) - error: \(String(describing: error))")
    }
}

func beacon_draw_coords(beaconNum : Int) -> CGPoint{
    var x = 0.0
    var y = 0.0
    
    let beacon = beacon_dict[enum_dict[beaconNum]!]

    let result = polar_to_rectangular(radius: beacon!.radius, angle: beacon!.angle)
    x = Double(result.0)
    y = Double(result.1)
    
    return CGPoint(x: x*m_to_pixel_mult, y: y*m_to_pixel_mult)
    
}

func localize_on_beacons(beacons: [Beacon], radiusBuffer: Double) -> (x: Double, y: Double, dist: Double){
    var bestAt = (x: 0.0, y: 0.0, dist: -1.0)
    for i in 2...beacons.count - 1{
        let c1p = (Double(beacon_draw_coords(beaconNum: beacons[0].num).x)/m_to_pixel_mult,
                   Double(beacon_draw_coords(beaconNum: beacons[0].num).y)/m_to_pixel_mult)
        
        let c2p = (Double(beacon_draw_coords(beaconNum: beacons[1].num).x)/m_to_pixel_mult,
                   Double(beacon_draw_coords(beaconNum: beacons[1].num).y)/m_to_pixel_mult)
        
        let c3p = (Double(beacon_draw_coords(beaconNum: beacons[i].num).x)/m_to_pixel_mult,
                   Double(beacon_draw_coords(beaconNum: beacons[i].num).y)/m_to_pixel_mult)
        
        let at = overlap_loc(c1r: beacons[0].dist + radiusBuffer, c1p: c1p, c2r: beacons[1].dist + radiusBuffer, c2p: c2p, c3r: beacons[i].dist + radiusBuffer, c3p: c3p)
        
        if (bestAt.dist == -1.0 || bestAt.dist > at.dist){
            bestAt = at
        }
    }
    
    return bestAt
    
    
    
}

// *** MATH ***

func polar_to_rectangular(radius: Double, angle: Double) -> (x: Double, y: Double) {
    let x = radius * cos(angle * .pi / 180)
    let y = radius * sin(angle * .pi / 180)
    return (x, y)
}

func overlap_loc(c1r: Double, c1p: (x: Double, y: Double), c2r: Double, c2p: (x: Double, y: Double), c3r: Double, c3p: (x: Double, y: Double)) -> (x: Double, y: Double, dist: Double){

    
        let r_1_2 = circle_overlap_loc(c1r: c1r, c1p: c1p, c2r: c2r, c2p: c2p)
        let r_1_3 = circle_overlap_loc(c1r: c1r, c1p: c1p, c2r: c3r, c2p: c3p)
        let r_2_3 = circle_overlap_loc(c1r: c2r, c1p: c2p, c2r: c3r, c2p: c3p)
        

    
    if r_1_2.validPoints && c3r >= c1r && c3r >= c2r{
        let dist = sqrt( pow(r_1_2.x1 - c3p.x, 2) + pow(r_1_2.y1 - c3p.y, 2) )
        let dist2 = sqrt( pow(r_1_2.x2 - c3p.x, 2) + pow(r_1_2.y2 - c3p.y, 2) )
        
        if abs(dist2 - c3r) < abs(dist - c3r){
            return (x: r_1_2.x2, y: r_1_2.y2, dist2)
        }
        else{
            return (x: r_1_2.x1, y: r_1_2.y1, dist)
        }
        
    }
    if r_1_3.validPoints && c2r >= c1r && c2r >= c3r{
        let dist = sqrt( pow(r_1_3.x1 - c2p.x, 2) + pow(r_1_3.y1 - c2p.y, 2) )
        let dist2 = sqrt( pow(r_1_3.x2 - c2p.x, 2) + pow(r_1_3.y2 - c2p.y, 2) )
        
        if abs(dist2 - c2r) < abs(dist - c2r){
            return (x: r_1_3.x2, y: r_1_3.y2, dist2)
        }
        else{
            return (x: r_1_3.x1, y: r_1_3.y1, dist)
        }
        
    }
    
    if r_2_3.validPoints && c1r >= c2r && c1r >= c3r{
        let dist = sqrt( pow(r_2_3.x1 - c1p.x, 2) + pow(r_2_3.y1 - c1p.y, 2) )
        let dist2 = sqrt( pow(r_2_3.x2 - c1p.x, 2) + pow(r_2_3.y2 - c1p.y, 2) )
        
        if abs(dist2 - c1r) < abs(dist - c1r){
            return (x: r_2_3.x2, y: r_2_3.y2, dist2)
        }
        else{
            return (x: r_2_3.x1, y: r_2_3.y1, dist)
        }
        
    }

    return (x: 0, y: 0, -1.0)
}

func circle_overlap_loc(c1r: Double, c1p: (x: Double, y: Double), c2r: Double, c2p: (x: Double, y: Double)) -> (x1: Double, y1: Double, x2: Double, y2: Double, validPoints: Bool){
    // returns the coordinates of the intersections of 2 circles, if validPoints==1 only the coordinates are valid, if validPoints==0, neither coordinate is valid

    let dist = sqrt( pow((c2p.0-c1p.0),2) + pow((c2p.1-c1p.1),2))
    if dist > c1r + c2r{
        //too far appart to intersect
        return (x1: 0.0, y1: 0.0, x2: 0.0, y2: 0.0, validPoints: false)
    }
    
    else if dist < abs(c1r - c2r){
        // one is inside the other
        return (x1: 0.0, y1: 0.0, x2: 0.0, y2: 0.0, validPoints: false)
    }
    
    else if dist == 0.0{
        // they are the same circle
        return (x1: 0.0, y1: 0.0, x2: 0.0, y2: 0.0, validPoints: false)
    }
    
    else if dist <= c1r+c2r{
        let a = ((c1r * c1r) - (c2r * c2r) +  (dist * dist)) / (2*dist)
        let h = sqrt((c1r * c1r) - (a * a))
        let b = c1p.x + a*(c2p.x - c1p.x)/dist
        let c = c1p.y + a*(c2p.y-c1p.y)/dist
        
        let x1 = b + h*(c2p.y-c1p.y)/dist
        let y1 = c - h*(c2p.x - c1p.x)/dist
        
        let x2 = b - h*(c2p.y-c1p.y)/dist
        let y2 = c + h*(c2p.x - c1p.x)/dist
        
        return (x1: x1, y1: y1, x2: x2, y2: y2, validPoints: true)
    }
    
    return (x1: 0.0, y1: 0.0, x2: 0.0, y2: 0.0, validPoints: false)
}

func point_in_circle(x: Double, y: Double, cr: Double, cp: (x: Double, y: Double)) -> Bool{
    let dist = sqrt( pow((cp.x-x),2) + pow((cp.y-y),2))
    return dist <= cr
}


