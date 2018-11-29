//
//  WindowViewController.swift
//  LifeCycleDemo
//
//  Created by 王瑞吉 on 2018/11/22.
//  Copyright © 2018 王瑞吉. All rights reserved.
//

import UIKit

class WindowViewController: UIViewController {
    
    public var fatherWindow: UIWindow?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func removeWindow(_ sender: UIButton) {
        if let window = fatherWindow {
            window.makeKeyAndVisible()
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
