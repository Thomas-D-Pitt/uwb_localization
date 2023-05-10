import Foundation
import UIKit
import CoreBluetooth

open class BLEConnection: NSObject, CBPeripheralDelegate, CBCentralManagerDelegate {

    // Properties
    private var centralManager: CBCentralManager! = nil
    private var bluefruitPeripheral: CBPeripheral!
    private var txCharacteristic: CBCharacteristic!
    private var rxCharacteristic: CBCharacteristic!

    func startCentralManager() {
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        print("Central Manager State: \(self.centralManager.state)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.centralManagerDidUpdateState(self.centralManager)
        }
    }

    // Handles BT Turning On/Off
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
                  case .poweredOff:
                      print("Is Powered Off.")
                  case .poweredOn:
                      print("Is Powered On.")
                      startScanning()
                  case .unsupported:
                      print("Is Unsupported.")
                  case .unauthorized:
                  print("Is Unauthorized.")
                  case .unknown:
                      print("Unknown")
                  case .resetting:
                      print("Resetting")
                  @unknown default:
                    print("Error")
                  }

       if(central.state != CBManagerState.poweredOn)
       {
           // In a real app, you'd deal with all the states correctly
           return;
       }
    }
    
    func startScanning() -> Void {
      // Start Scanning
      centralManager?.scanForPeripherals(withServices: [CBUUIDs.BLEService_UUID])
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        bluefruitPeripheral = peripheral

        bluefruitPeripheral.delegate = self

        print("Peripheral Discovered: \(peripheral)")
          print("Peripheral name: \(peripheral.name)")
        print ("Advertisement Data : \(advertisementData)")
        
        centralManager?.connect(bluefruitPeripheral!, options: nil)
            
        centralManager?.stopScan()
       }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
       bluefruitPeripheral.discoverServices([CBUUIDs.BLEService_UUID])
        
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            print("*******************************************************")

            if ((error) != nil) {
                print("Error discovering services: \(error!.localizedDescription)")
                return
            }
            guard let services = peripheral.services else {
                return
            }
            //We need to discover the all characteristic
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
            print("Discovered Services: \(services)")
        }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
           
               guard let characteristics = service.characteristics else {
              return
          }

          print("Found \(characteristics.count) characteristics.")

          for characteristic in characteristics {

            if characteristic.uuid.isEqual(CBUUIDs.BLE_Characteristic_uuid_Rx)  {

              rxCharacteristic = characteristic

              //peripheral.setNotifyValue(true, for: rxCharacteristic!)
              //peripheral.readValue(for: characteristic)

              print("RX Characteristic: \(rxCharacteristic.uuid)")
            }

            if characteristic.uuid.isEqual(CBUUIDs.BLE_Characteristic_uuid_Tx){
              
              txCharacteristic = characteristic
              
              print("TX Characteristic: \(txCharacteristic.uuid)")
            }
          }
    }
    
    func writeOutgoingValue(data: String){
          
        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue)
        
        if let bluefruitPeripheral = bluefruitPeripheral {
              
          if let txCharacteristic = txCharacteristic {
                  
            bluefruitPeripheral.writeValue(valueString!, for: txCharacteristic, type: CBCharacteristicWriteType.withResponse)
              }
          }
      }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

          var characteristicASCIIValue = NSString()

          guard characteristic == rxCharacteristic,

          let characteristicValue = characteristic.value,
          let ASCIIstring = NSString(data: characteristicValue, encoding: String.Encoding.utf8.rawValue) else { return }

          characteristicASCIIValue = ASCIIstring

          print("Value Recieved: \((characteristicASCIIValue as String))")
    }
    
    func disconnectFromDevice () {
        if bluefruitPeripheral != nil {
        centralManager?.cancelPeripheralConnection(bluefruitPeripheral!)
        }
     }

}
