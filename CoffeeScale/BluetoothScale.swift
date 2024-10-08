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
    @Published var measurementDate: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    @Published var state: bluetoothScaleState = .disconnected
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    private var smartScaleWriteCharacteristic: CBCharacteristic!
    private var smartScaleNotifyCharacteristic: CBCharacteristic!
    let peripheralName: String = "LFSmart Scale"
    let smartScaleServiceCBUUID = CBUUID(string: "FFF0")
    let smartScaleWriteCharacteristicCBUUID = CBUUID(string: "FFF1")
    let smartScaleNotifyCharacteristicCBUUID = CBUUID(string: "FFF4")
    enum bluetoothScaleState {
        case connected
        case disconnected
    }
    
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
            self.centralManager.scanForPeripherals(withServices: [smartScaleServiceCBUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        case .poweredOff:
            print("Bluetooth is powered off")
            state = .disconnected
        case .unsupported:
            print("Is Unsupported.")
            state = .disconnected
        case .unauthorized:
            print("Is Unauthorized.")
            state = .disconnected
        case .unknown:
            print("Unknown")
            state = .disconnected
        case .resetting:
            print("Resetting")
            self.centralManager.retrieveConnectedPeripherals(withServices: [smartScaleServiceCBUUID])
            //self.centralManager.retrievePeripherals(withIdentifiers: <#T##[UUID]#>)
        @unknown default:
            print("Error: Unknown state")
            state = .disconnected
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
        state = .connected
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if ((error) != nil) {
            print("Error connecting peripheral: \(error!.localizedDescription)")
        }
        print("didFailToConnect")
        self.centralManager.cancelPeripheralConnection(peripheral)
        state = .disconnected
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("didDisconnectPeripheral")
        self.centralManager.cancelPeripheralConnection(peripheral)
        state = .disconnected
    }
    
    func scan() {
        self.centralManager.scanForPeripherals(withServices: [smartScaleServiceCBUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
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
        if let e = error {
            print("ERROR didUpdateValue \(e)")
            return
        }
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
            self.measurementDate = Int64(Date().timeIntervalSince1970 * 1000)
        default:
            print("Unhandled Characteristic UUID: \(characteristic.uuid)")
        }
    }
    
    private func writeData(withCharacteristic characteristic: CBCharacteristic, withValue value: Data) {
        // Check if it has the write property
        if peripheral != nil && state == .connected {
            if characteristic.properties.contains(.write) && peripheral != nil {
                self.peripheral.writeValue(value, for: characteristic, type: CBCharacteristicWriteType.withResponse)
                //peripheral.writeValue(data, for: smartScaleWriteCharacteristic, type: .withResponse)
            }
        }
    }
    
    func sendZero() {
        if peripheral != nil && state == .connected {
            let bytes:[UInt8] = [ 0xFD, 0x32, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCF ]
            let command = Data(_:bytes)
            self.writeData(withCharacteristic: smartScaleWriteCharacteristic, withValue: command)
        }
    }
    
    func switchToGramms() {
        if peripheral != nil && state == .connected {
            let bytes:[UInt8] = [ 0xFD, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF9 ]
            let command = Data(_:bytes)
            self.writeData(withCharacteristic: smartScaleWriteCharacteristic, withValue: command)
        }
    }
    
    func disconnectFromDevice () {
        if peripheral != nil {
            centralManager?.cancelPeripheralConnection(peripheral!)
            state = .disconnected
        }
    }
    
    private func weightValue(from characteristic: CBCharacteristic) -> Int {
        if peripheral != nil {
            guard let characteristicData = characteristic.value else { return 0 }
            let byteArray = [UInt8](characteristicData)
            if byteArray.count > 10 { // byteArray.count = 11 if scale connected and byteArray.count = 2 if scale turned off
                return (Int(byteArray[4]) << 8) + Int(byteArray[3])
            } else {
                return 0
            }
        } else {
            return 0
        }
    }
    
    private func minusSignValue(from characteristic: CBCharacteristic) -> Int {
        if peripheral != nil {
            guard let characteristicData = characteristic.value else { return 0 }
            let byteArray = [UInt8](characteristicData)
            if byteArray.count > 10 {
                return Int(byteArray[5])
            } else {
                return 0
            }
        } else {
            return 0
        }
    }
    
    func setTime() {
        if peripheral != nil && state == .connected {
            let bytes:[UInt8] = [ 0xFD, 0x32, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCF ]
            let command = Data(_:bytes)
            self.writeData(withCharacteristic: smartScaleWriteCharacteristic, withValue: command)
        }
    }
    
}
