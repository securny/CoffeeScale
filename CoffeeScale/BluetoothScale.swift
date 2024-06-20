//
//  BluetoothScale.swift
//  CoffeeScale
//
//  Created by Dmitry on 10.06.2024.
//

import CoreBluetooth
import Foundation

class BluetoothScale: NSObject, ObservableObject {
    
    @Published var weight: Float = 0
    @Published var flowrate: Float = 0
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    private var smartScaleWriteCharacteristic: CBCharacteristic!
    private var smartScaleNotifyCharacteristic: CBCharacteristic!
    let peripheralName: String = "LFSmart Scale"
    let smartScaleServiceCBUUID = CBUUID(string: "FFF0")
    let smartScaleWriteCharacteristicCBUUID = CBUUID(string: "FFF1")
    let smartScaleNotifyCharacteristicCBUUID = CBUUID(string: "FFF4")
    private var measurementDate: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }
}

extension BluetoothScale: CBCentralManagerDelegate {

    // If we're powered on, start scanning
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            self.centralManager.scanForPeripherals(withServices: [smartScaleServiceCBUUID], options: nil)
        case .poweredOff:
            print("Bluetooth is powered off")
        case .unsupported:
            print("Is Unsupported.")
        case .unauthorized:
            print("Is Unauthorized.")
        case .unknown:
            print("Unknown")
        case .resetting:
            print("Resetting")
        @unknown default:
            print("Error: Unknown state")
        }
    }
    
    // Handles the result of the scan
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name?.contains(peripheralName) != nil {
            self.peripheral = peripheral
            self.peripheral.delegate = self
            print("Peripheral Discovered: \(peripheral)")
            print("Peripheral Name: \(String(describing: peripheral.name))")
            print("Advertisement Data : \(advertisementData)")
            self.centralManager.stopScan()
            self.centralManager.connect(self.peripheral!, options: nil)
        }
    }
        
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "unknown device")")
        self.peripheral.discoverServices([smartScaleServiceCBUUID])
    }
}

extension BluetoothScale: CBPeripheralDelegate {
  
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
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
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
      guard let characteristics = service.characteristics else { return }

      for characteristic in characteristics {
          print(characteristic)
          if characteristic.properties.contains(.write) {
              smartScaleWriteCharacteristic = characteristic
              print("\(characteristic.uuid): properties contains .write")
          }
          if characteristic.properties.contains(.notify) {
              smartScaleNotifyCharacteristic = characteristic
              print("\(characteristic.uuid): properties contains .notify")
              peripheral.setNotifyValue(true, for: characteristic)
          }
      }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
      switch characteristic.uuid {
        case smartScaleNotifyCharacteristicCBUUID:
          let prevWeight = self.weight
          self.weight = Float(weightValue(from: characteristic))/10
          let minusSign = minusSignValue(from: characteristic)
          if (minusSign == 1) {
              self.weight = 0 - self.weight
          }
          self.flowrate = 1000 * (self.weight - prevWeight) / Float(Int64(Date().timeIntervalSince1970 * 1000) - measurementDate)
          print("flowrate: \(self.flowrate); weight: \(self.weight)")
          measurementDate = Int64(Date().timeIntervalSince1970 * 1000)
        default:
          print("Unhandled Characteristic UUID: \(characteristic.uuid)")
      }
    }
    
    private func writeData(withCharacteristic characteristic: CBCharacteristic, withValue value: Data) {
                // Check if it has the write property
                if characteristic.properties.contains(.write) && peripheral != nil {
                    self.peripheral.writeValue(value, for: characteristic, type: CBCharacteristicWriteType.withResponse)
                    //peripheral.writeValue(data, for: smartScaleWriteCharacteristic, type: .withResponse)
                }
            }
    
    func sendZero() {
        if peripheral != nil {
            let bytes:[UInt8] = [ 0xFD, 0x32, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCF ]
            let command = Data(_:bytes)
            self.writeData(withCharacteristic: smartScaleWriteCharacteristic, withValue: command)
        }
    }
    
    func switchToGramms() {
        if peripheral != nil {
            let bytes:[UInt8] = [ 0xFD, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF9 ]
            let command = Data(_:bytes)
            self.writeData(withCharacteristic: smartScaleWriteCharacteristic, withValue: command)
        }
    }
    
    func disconnectFromDevice () {
        if peripheral != nil {
        centralManager?.cancelPeripheralConnection(peripheral!)
        }
     }
    
    private func weightValue(from characteristic: CBCharacteristic) -> Int {
        guard let characteristicData = characteristic.value else { return -1 }
        let byteArray = [UInt8](characteristicData)
        return (Int(byteArray[4]) << 8) + Int(byteArray[3])
    }
    
    private func minusSignValue(from characteristic: CBCharacteristic) -> Int {
        guard let characteristicData = characteristic.value else { return -1 }
        let byteArray = [UInt8](characteristicData)
        return Int(byteArray[5])
    }
    
}
