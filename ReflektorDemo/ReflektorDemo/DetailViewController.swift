//
// DetailViewController.swift
// ReflektorDemo
//
// Created by Alex Usbergo on 24/04/15.
// Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

import UIKit
import ReflektorKit;

class DetailViewController: UIViewController {

    @IBOutlet weak var detailDescriptionLabel: UILabel!
    let container = UIView(frame: CGRectZero)
    let label1 = UIButton(frame: CGRectZero)
    let label2 = UIButton(frame: CGRectZero)
    let label3 = UIButton(frame: CGRectZero)
    
    var detailItem: AnyObject?

    override func viewDidLoad() {
        super.viewDidLoad()
        //Do any additional setup after loading the view, typically from a nib.

        container.frame = self.view.bounds
        container.autoresizingMask = .FlexibleHeight | .FlexibleWidth
        container.rflk_addTrait("flex-container")
        
        label1.rflk_addTrait("flex-item-first")
        label2.rflk_addTrait("flex-item")
        label3.rflk_addTrait("flex-item")
        
        container.addSubview(label1)
        container.addSubview(label2)
        container.addSubview(label3)
        
        self.view.addSubview(container)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        //Dispose of any resources that can be recreated.
    }


}

