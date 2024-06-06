//
//  ContentView.swift
//  CoffeeScale
//
//  Created by Dmitry on 03.06.2024.
//

import SwiftUI
import CoreBluetooth

class CoffeeScaleViewModel: NSObject, ObservableObject {
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    private var txCharacteristic: CBCharacteristic!
    private var rxCharacteristic: CBCharacteristic!
    @Published var peripheralName: String = "LFSmart Scale"
    let smartScaleServiceCBUUID = CBUUID(string: "FFF0")
    let smartScaleWriteCharacteristicCBUUID = CBUUID(string: "FFF1")
    let smartScaleNotifyCharacteristicCBUUID = CBUUID(string: "FFF4")
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }
}

extension CoffeeScaleViewModel: CBCentralManagerDelegate {
    
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
            //print("Peripheral Name: \(String(describing: peripheral.name))")
            //print("Advertisement Data : \(advertisementData)")
            self.centralManager.stopScan()
            self.centralManager.connect(self.peripheral!, options: nil)
        }
    }
        
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "unknown device")")
        self.peripheral.discoverServices([smartScaleServiceCBUUID])
    }
        
}

extension CoffeeScaleViewModel: CBPeripheralDelegate {
    
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
              print("\(characteristic.uuid): properties contains .write")
          }
          if characteristic.properties.contains(.notify) {
              print("\(characteristic.uuid): properties contains .notify")
              peripheral.setNotifyValue(true, for: characteristic)
          }
      }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
      switch characteristic.uuid {
        case smartScaleNotifyCharacteristicCBUUID:
          var weight = weightValue(from: characteristic)
          let minusSign = minusSignValue(from: characteristic)
          if minusSign == 1 {
              weight = 0 - weight
          }
          //onWeightReceived(weight)
        default:
          print("Unhandled Characteristic UUID: \(characteristic.uuid)")
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

struct ContentView: View {
    //@ObservedObject private var coffeeScaleViewModel = CoffeeScaleViewModel()
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
