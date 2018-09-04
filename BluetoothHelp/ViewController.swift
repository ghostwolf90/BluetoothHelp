//
//  ViewController.swift
//  BluetoothHelp
//
//  Created by Laibit on 2018/5/6.
//  Copyright © 2018年 Laibit. All rights reserved.
//

import UIKit
import CoreBluetooth

struct PeripheralModel {
    var peripheral:CBPeripheral
    var RSSI:Float
    var select:Int
}

class ViewController: UIViewController {

    let bluetoothHelp = BluetoothHelp.sharedInstance
    
    private var discoverDevices = [PeripheralModel]()
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bluetoothHelp.isInitCBCentralManager(isInit: true)
        bluetoothHelp.delegate = self
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

extension ViewController: BluetoothHelpDelegate{
    
    func bluetoothHelp(didDiscover peripheral: CBPeripheral, rssi RSSI: NSNumber) {
        print("peripheral \(peripheral)")
        
        let peripheral = PeripheralModel(peripheral:peripheral, RSSI:RSSI.floatValue, select:0)
        discoverDevices.append(peripheral)
        tableView.reloadData()
    }
}

extension ViewController:UITableViewDelegate, UITableViewDataSource{
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoverDevices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "Cell")
        
        cell.textLabel?.text = discoverDevices[indexPath.row].peripheral.name
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        bluetoothHelp.connectPeripheral(peripheral: discoverDevices[indexPath.row].peripheral)
    }
    
    
}

