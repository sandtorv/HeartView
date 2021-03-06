//
//  ViewController.swift
//  HeartView
//
//  Created by Sebastian Sandtorv on 12/08/16.
//  Copyright © 2016 Sebastian Sandtorv. All rights reserved.
//
// Progress bar: https://github.com/kaandedeoglu/KDCircularProgress

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBPeripheralDelegate, CBCentralManagerDelegate {
    var centralManager:CBCentralManager!
    var connectingPeripheral:CBPeripheral!
    
    let maxBPM:Double = 196
    
    @IBOutlet var BPM: UILabel!
    @IBOutlet var status:UILabel!
    @IBOutlet var connectBtn:UIButton!
    
    let progress = KDCircularProgress(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        BPM.hidden = true
        status.hidden = true
        progress.hidden = true
        title = "HeartView"
    }

    
    @IBAction func connectHRM(){
        centralManager = CBCentralManager(delegate: self, queue: dispatch_get_main_queue())
        connectBtn.hidden = true
        status.hidden = false
        createProgressView()
    }
    
    func createProgressView(){
        let size:CGRect = UIScreen.mainScreen().bounds
        progress.startAngle = 135
        progress.progressThickness = 0.4
        progress.trackThickness = 0
        progress.trackColor = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1)
        progress.clockwise = true
        progress.center = CGPointMake(size.midX, size.maxY - 200)
        progress.gradientRotateSpeed = 0
        progress.roundedCorners = true
        progress.glowMode = .Constant
        progress.angle = 0
        progress.setColors(UIColor.greenColor())
        view.addSubview(progress)
    }
    
    func updateStatus(msg: AnyObject){
        status.text = "\(msg)"
    }
    
    func showError(error: AnyObject){
        print("\(error)")
    }
    
    
    // Central manager stuff
    func centralManagerDidUpdateState(central: CBCentralManager){
        switch central.state{
        case .PoweredOn:
            print("poweredOn")
            updateStatus("Searching")
            
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
            showError("Bluetooth is powered off. Please turn on bluetooth")
            
        case .Resetting:
            print(".Resetting")
            
        case .Unauthorized:
            print(".Unauthorized")
            
        case .Unknown:
            print(".Unknown")
            
        case .Unsupported:
            showError("Device is unsupported")
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
                        updateStatus("Found a Heart Rate Measurement Characteristic")
                        peripheral.setNotifyValue(true, forCharacteristic: characteristic)
                        
                    case "2A38":
                        // Read body sensor location
                        updateStatus("Found a Body Sensor Location Characteristic")
                        peripheral.readValueForCharacteristic(characteristic)
                        
                    case "2A39":
                        // Write heart rate control point
                        updateStatus("Found a Heart Rate Control Point Characteristic")
                        
                        var rawArray:[UInt8] = [0x01];
                        let data = NSData(bytes: &rawArray, length: rawArray.count)
                        peripheral.writeValue(data, forCharacteristic: characteristic, type: CBCharacteristicWriteType.WithoutResponse)
                        
                    default:
                        print("Default shit")
                    }
                    
                }
            }
        }
    }
    
    func update(heartRateData:NSData){
        status.hidden = true
        progress.hidden = false
        BPM.hidden = false
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
        
        
        BPM.text = ("\(bpm!)")
        
        progress.animateFromAngle(progress.angle, toAngle: 270*(Double(bpm!)/Double(maxBPM)), duration: 0.2) { completed in
            if completed {
//                print("animation stopped, completed")
            } else {
//                print("animation stopped, was interrupted")
            }
        }
        
        if(Double(bpm!) < maxBPM*0.6){
            progress.setColors(UIColor.cyanColor())
            BPM.textColor = UIColor.cyanColor()
        } else if(Double(bpm!) < maxBPM*0.7){
            progress.setColors(UIColor.blueColor())
            BPM.textColor = UIColor.blueColor()
        } else if(Double(bpm!) < maxBPM*0.8){
            progress.setColors(UIColor.greenColor())
            BPM.textColor = UIColor.greenColor()
        } else if(Double(bpm!) < maxBPM*0.9){
            progress.setColors(UIColor.yellowColor())
            BPM.textColor = UIColor.yellowColor()
        } else {
            progress.setColors(UIColor.redColor())
            BPM.textColor = UIColor.redColor()
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