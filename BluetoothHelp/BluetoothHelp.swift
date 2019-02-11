//
//  BluetoothHelp.swift
//  BluetoothHelp
//
//  Created by Laibit on 2018/5/6.
//  Copyright © 2018年 Laibit. All rights reserved.
//

import UIKit
import CoreBluetooth

enum CardType{
    case none
    case mifare1k
    case creditCard
}

enum BatteryStatus:UInt {
    /** No battery. */
    case batteryStatusNone = 0
    /** The battery is full. */
    case batteryStatusFull = 0xFE
    /** The USB is plugged. */
    case batteryStatusUsbPlugged = 0xFF
}


protocol BluetoothHelpDelegate {
    func bluetoothHelp(didDiscover peripheral:CBPeripheral,rssi RSSI: NSNumber)
}

class BluetoothHelp: NSObject, CBCentralManagerDelegate {
    
    static var sharedInstance = BluetoothHelp()
    var delegate:BluetoothHelpDelegate?
    
    var manager : CBCentralManager!
    var connectedPerpheral:CBPeripheral!
    var discoveredPeripherals = [CBPeripheral]()
    
    var bluetoothReaderManager = ABTBluetoothReaderManager()
    var bluetoothReader = ABTBluetoothReader()
    var senseCardType = CardType.none
    var masterKey = Data()
    var commandApdu = Data()
    var escapeCommand = Data()
    
    private let acr1311u = "ACR1311U"
    private let acr1255u = "ACR1255U"
    
    override init() {
        super.init()
        print("init")
        bluetoothReaderManager.delegate = self
        
        masterKey = ABDHex.byteArray(fromHexString: "41 43 52 31 32 35 35 55 2D 4A 31 20 41 75 74 68")
        commandApdu = ABDHex.byteArray(fromHexString: "FF CA 01 00 00")
        escapeCommand = ABDHex.byteArray(fromHexString: "04 00")
    }
    
    func isInitCBCentralManager(isInit:Bool){
        if isInit{
            if manager == nil {
                manager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
            }
        }        
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager){
        switch central.state {
        case .unknown:
            print("CBCentralManagerStateUnknown")
        case .resetting:
            print("CBCentralManagerStateResetting")
        case .unsupported:
            print("CBCentralManagerStateUnsupported")
        case .unauthorized:
            print("CBCentralManagerStateUnauthorized")
        case .poweredOff:
            print("CBCentralManagerStatePoweredOff")
        case .poweredOn:
            print("CBCentralManagerStatePoweredOn")
            let optionDic = [CBCentralManagerScanOptionAllowDuplicatesKey:false]
            manager.scanForPeripherals(withServices: nil, options: optionDic)
        }
    }
    
    func enableBuzzer(){
        let commandBuzzer:Data = ABDHex.byteArray(fromHexString:"E0 00 00 28 01 09")
        bluetoothReader.transmitEscapeCommand(commandBuzzer)
    }
}

//MARK: 掃描/連線周邊藍芽
extension BluetoothHelp: CBPeripheralDelegate{
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber){
        let peripheralName = peripheral.name
        guard peripheralName != nil else {
            return
        }
        
        //解析能夠判斷的裝置名稱
        let comparisonPeripheralName = self.integrationName(peripheralName: peripheralName!)
        guard !(comparisonPeripheralName.isEmpty) else{
            return
        }
        
        //限定只有ACR1311U和ACR1255U能夠進入接下來要儲存的Array
        guard (comparisonPeripheralName == self.acr1311u || comparisonPeripheralName == self.acr1255u) else{
            return
        }
        
        var isExisted = false
        for aPeripheral in discoveredPeripherals {
            if (aPeripheral.identifier == peripheral.identifier){
                isExisted = true
            }
        }
        
        if !isExisted{
            discoveredPeripherals.append(peripheral)
            self.delegate?.bluetoothHelp(didDiscover: peripheral, rssi: RSSI)
        }
    }
    
    func connectPeripheral(peripheral:CBPeripheral){
        if (connectedPerpheral != nil) {
            manager.cancelPeripheralConnection(peripheral)
        }
        manager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral){
        print("didConnectPeripheral- \(peripheral)")
        
        connectedPerpheral = peripheral
        bluetoothReaderManager.detectReader(with: connectedPerpheral)
        
        //停止掃描
        manager.stopScan()
    }
    
    //MARK: Other Func
    func integrationName(peripheralName:String) -> String{
        var outPutString = ""
        if (peripheralName.count >= 8){
            let tempPeripheralName = (peripheralName as NSString).substring(to: 8)
            outPutString = tempPeripheralName
        }
        
        return outPutString
    }
    
    /**
     * Returns the description from the battery status.
     * @param batteryStatus the battery status.
     * @return the description.
     */
    func ABD_stringFromBatteryStatus(batteryStatus:UInt)->String {
        var string = ""
        switch (batteryStatus) {
        case BatteryStatus.batteryStatusNone.rawValue:
            string = "No Battery"
            break
        case BatteryStatus.batteryStatusFull.rawValue:
            string = "Full"
            break
        case BatteryStatus.batteryStatusUsbPlugged.rawValue:
            string = "USB Plugged"
            break
        default:
            string = "Low"
            break
        }
        
        return string
    }
}

extension BluetoothHelp {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?){
        for service in peripheral.services! {
            print("Service: \(service)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?){
        
        for characteristic in service.characteristics! {
            print("\(service.uuid.uuidString)服務下的特性:\(characteristic)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?){
        // 操作的characteristic 保存
        print("\nCharateristic: \(characteristic.uuid.uuidString) \n 值: \(characteristic)")
    }
    
}

//小白盒的Delegate
extension BluetoothHelp: ABTBluetoothReaderManagerDelegate, ABTBluetoothReaderDelegate{
    
    func bluetoothReaderManager(_ bluetoothReaderManager: ABTBluetoothReaderManager!, didDetect reader: ABTBluetoothReader!, peripheral: CBPeripheral!, error: Error!) {
        guard error == nil else {
            print("didDetect Error:\(error)")
            //[self ABD_showError:error];
            return
        }
        
        bluetoothReader = reader;
        bluetoothReader.delegate = self;
        bluetoothReader.attach(peripheral)
    }
    
    func bluetoothReader(_ bluetoothReader: ABTBluetoothReader!, didAttach peripheral: CBPeripheral!, error: Error!) {
        guard error == nil else {
            print("didAttach Error:\(error)")
            //[self ABD_showError:error];
            return
        }
        print(masterKey)
        bluetoothReader.authenticate(withMasterKey: masterKey)
    }
    
    func bluetoothReader(_ bluetoothReader: ABTBluetoothReader!, didChangeBatteryStatus batteryStatus: UInt, error: Error!) {
        guard error == nil else {
            print("didChangeBatteryStatus Error:\(error)")
            //[self ABD_showError:error];
            return
        }
        
        let batteryStatusLog = ABD_stringFromBatteryStatus(batteryStatus: batteryStatus)
        print("batteryStatusLog \(batteryStatusLog)")
        if(batteryStatusLog == "20%"){
            //[self callMessageEvent:@"batteryTooLow" withAnyParam:@""];
        }
    }
    
    func bluetoothReader(_ bluetoothReader: ABTBluetoothReader!, didReturnAtr atr: Data!, error: Error!) {
        guard error == nil else {
            print("didChangeBatteryStatus Error:\(error)")
            //[self ABD_showError:error];
            return
        }
        
        let aTRlog = ABDHex.hexString(fromByteArray: atr)
        if (aTRlog  == "3B8F8001804F0CA000000306030001000000006A"){
            commandApdu = ABDHex.byteArray(fromHexString: "FF CA 00 00 00") //MIFARE Classic 1K
            senseCardType = .mifare1k
            print("MIFARE Classic 1K")
        }else{
            commandApdu = ABDHex.byteArray(fromHexString: "00 A4 04 00 0E 32 50 41 59 2E 53 59 53 2E 44 44 46 30 31 00") //2PAY.SYS.DDF01
            senseCardType = .creditCard
            print("2PAY.SYS.DDF01 START")
        }
        bluetoothReader.transmitApdu(commandApdu)
    }
    
    func bluetoothReader(_ bluetoothReader: ABTBluetoothReader!, didReturnResponseApdu apdu: Data!, error: Error!) {
        guard error == nil else {
            print("didChangeBatteryStatus Error:\(error)")
            //[self ABD_showError:error];
            return
        }
        
    }
}
