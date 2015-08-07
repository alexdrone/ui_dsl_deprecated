//
//  DemoViewController.swift
//  Demo
//
//  Created by Alex Usbergo on 07/08/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import UIKit
import ReflektorKitSwift

class DemoContainerView : UIView {
    

    
}

class DemoViewController: UIViewController {
    
    private let containerView = DemoContainerView(frame:  CGRect(x: 100, y: 100, width: 200, height: 200), useAppearanceProxy: true, hookToViewLifecycle: true)

    override func viewDidLoad() {
        
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.view.backgroundColor = UIColor.whiteColor()
        self.view.addSubview(self.containerView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    



}
