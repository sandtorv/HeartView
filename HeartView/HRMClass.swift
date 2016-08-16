//
//  HRMClass.swift
//  HeartView
//
//  Created by Sebastian Sandtorv on 12/08/16.
//  Copyright © 2016 Sebastian Sandtorv. All rights reserved.
//

import Foundation
import CoreBluetooth

class HRMClass: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager:CBCentralManager!
    var connectingPeripheral:CBPeripheral!
    
    override init(){
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: dispatch_get_main_queue())
    }
    
    func centralManagerDidUpdateState(central: CBCentralManager){
        switch central.state{
        case .PoweredOn:
            print("poweredOn")
            
            let serviceUUIDs:[CBUUID] = [CBUUID(string: "180D")]
            let lastPeripherals = centralManager.retrieveConnectedPeripheralsWithServices(serviceUUIDs)
            
            if lastPeripherals.count > 0{
                let device = lastPeripherals.last! as CBPeripheral;
                connectingPeripheral = device;
                centralManager.connectPeripheral(connectingPeripheral, options: nil)
            }
            else {
                centralManager.scanForPeripheralsWithServices(serviceUUIDs, options: nil)
            }
        case .PoweredOff:
            print(".PoweredOff")
            
        case .Resetting:
            print(".Resetting")
            
        case .Unauthorized:
            print(".Unauthorized")
            
        case .Unknown:
            print(".Unknown")
            
        case .Unsupported:
            print(".Unsupported")
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        connectingPeripheral = peripheral
        connectingPeripheral.delegate = self
        centralManager.connectPeripheral(connectingPeripheral, options: nil)
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        
        peripheral.discoverServices(nil)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        
        if error != nil{
            
        }
        else {
            for service in peripheral.services as [CBService]!{
                peripheral.discoverCharacteristics(nil, forService: service)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
        if error != nil{
            
        }
        else {
            
            if service.UUID == CBUUID(string: "180D"){
                for characteristic in service.characteristics! as [CBCharacteristic]{
                    switch characteristic.UUID.UUIDString{
                        
                    case "2A37":
                        // Set notification on heart rate measurement
                        print("Found a Heart Rate Measurement Characteristic")
                        peripheral.setNotifyValue(true, forCharacteristic: characteristic)
                        
                    case "2A38":
                        // Read body sensor location
                        print("Found a Body Sensor Location Characteristic")
                        peripheral.readValueForCharacteristic(characteristic)
                        
                    case "2A39":
                        // Write heart rate control point
                        print("Found a Heart Rate Control Point Characteristic")
                        
                        var rawArray:[UInt8] = [0x01];
                        let data = NSData(bytes: &rawArray, length: rawArray.count)
                        peripheral.writeValue(data, forCharacteristic: characteristic, type: CBCharacteristicWriteType.WithoutResponse)
                        
                    default:
                        print("characteristic.UUID.UUIDString: \(characteristic.UUID.UUIDString)")
                    }
                    
                }
            }
        }
    }
    
    func update(heartRateData:NSData){
        
        var buffer = [UInt8](count: heartRateData.length, repeatedValue: 0x00)
        heartRateData.getBytes(&buffer, length: buffer.count)
        
        var bpm:UInt16?
        if (buffer.count >= 2){
            if (buffer[0] & 0x01 == 0){
                bpm = UInt16(buffer[1]);
            }else {
                bpm = UInt16(buffer[1]) << 8
                bpm =  bpm! | UInt16(buffer[2])
            }
        }
        
        if let actualBpm = bpm{
            print(actualBpm)
            print("BPM: \(actualBpm)")
        }else {
            print(bpm)
            print("BPM: \(bpm)")
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        if error != nil{
            
        }else {
            switch characteristic.UUID.UUIDString{
            case "2A37":
                update(characteristic.value!)
                
            default:
                print("Default shit")
            }
        }
    }
}
