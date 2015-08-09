//
//  DemoViewController.swift
//  Demo
//
//  Created by Alex Usbergo on 07/08/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import UIKit
import ReflektorKitSwift

class DemoContainerView : UILabel {
    

    
}

class DemoViewController: UIViewController {
    
    private let containerView = DemoContainerView(frame:  CGRect(x: 100, y: 100, width: 200, height: 200), useAppearanceProxy: true)

    override func viewDidLoad() {
        
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
//        self.containerView.text = "Test"
        
//        let text = self.containerView.refl_appearanceProxy.property("text") as? String
//        self.containerView.text = text

        self.view.backgroundColor = UIColor.whiteColor()
        self.view.addSubview(self.containerView)
        
        print(self.containerView)
        
        UIView.animateWithDuration(5) { () -> Void in
            self.containerView.refl_appearanceProxy.trait = "blueAndRounded"
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
       self.refl_applyStyleToViewRecursive()
    }
    
    override func viewDidLayoutSubviews() {
        self.refl_applyStyleToViewRecursive(true)
    }

}
