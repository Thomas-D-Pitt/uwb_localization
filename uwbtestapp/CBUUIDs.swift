import Foundation
import CoreBluetooth

struct CBUUIDs{

    static let kBLEService_UUID = "A07498CA-AD5B-474E-940D-16F1FBE7E8CD"
    static let kBLE_Characteristic_uuid_Tx = "51FF12BB-3ED8-46E5-B4F9-D64E2FEC021B"
    static let kBLE_Characteristic_uuid_Rx = "51FF12BB-3ED8-46E5-B4F9-D64E2FEC021B"

    static let BLEService_UUID = CBUUID(string: kBLEService_UUID)
    static let BLE_Characteristic_uuid_Tx = CBUUID(string: kBLE_Characteristic_uuid_Tx)//(Property = Write without response)
    static let BLE_Characteristic_uuid_Rx = CBUUID(string: kBLE_Characteristic_uuid_Rx)// (Property = Read/Notify)

}
