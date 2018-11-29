//
//  ViewController.swift
//  LifeCycleDemo
//
//  Created by 王瑞吉 on 2018/11/19.
//  Copyright © 2018 王瑞吉. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    // MARK: - Managing the View
    
    override func loadView() {
        super.loadView()
        print("loadView")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad")
    }
    
    // MARK: - Responding to View Events
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("viewWillAppear")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("viewWillDisappear")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("viewDidDisappear")
    }

    // MARK: - Configuring the View’s Layout Behavior
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        print("updateViewConstraints")
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        print("viewWillLayoutSubviews")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("viewDidLayoutSubviews")
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        print("viewSafeAreaInsetsDidChange")
    }
    
    var window = UIWindow(frame: UIScreen.main.bounds)
    @IBAction func addWindow(_ sender: UIButton) {
        window.backgroundColor = UIColor.black
        let windowVC = self.storyboard?.instantiateViewController(withIdentifier: "WindowViewController") as! WindowViewController
        windowVC.fatherWindow = self.view.window
        window.rootViewController = windowVC
        window.makeKeyAndVisible()
    }
}

