//
//  PresentedViewController.swift
//  LifeCycleDemo
//
//  Created by 王瑞吉 on 2018/11/21.
//  Copyright © 2018 王瑞吉. All rights reserved.
//

import UIKit

class PresentedViewController: UIViewController {
    
    // MARK: - Managing the View
    
    override func loadView() {
        super.loadView()
        print("Presented -- loadView")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("Presented -- viewDidLoad")
    }
    
    // MARK: - Responding to View Events
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("Presented -- viewWillAppear")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("Presented -- viewDidAppear")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("Presented -- viewWillDisappear")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("Presented -- viewDidDisappear")
    }
    
    // MARK: - Configuring the View’s Layout Behavior
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        print("Presented -- updateViewConstraints")
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        print("Presented -- viewWillLayoutSubviews")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("Presented -- viewDidLayoutSubviews")
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        print("viewSafeAreaInsetsDidChange")
    }

    @IBAction func dismissVC(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
}

