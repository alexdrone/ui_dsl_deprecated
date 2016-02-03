//
//  DemoViewController.swift
//  Demo
//
//  Created by Alex Usbergo on 07/08/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import UIKit
import Reflektor

class DemoContainerView : UIView {
    let avatarView = UIImageView(frame: CGRect.zero, useAppearanceProxy: true)
    let displayNameLabel = UILabel(frame: CGRect.zero, useAppearanceProxy: true)
    let timestampLabel = UILabel(frame: CGRect.zero, useAppearanceProxy: true)
    let postLabel = UILabel(frame: CGRect.zero, useAppearanceProxy: true)
    let likeButton = UIButton(frame: CGRect.zero, useAppearanceProxy: true)
    let commentButton = UIButton(frame: CGRect.zero, useAppearanceProxy: true)
    let shareButton = UIButton(frame: CGRect.zero, useAppearanceProxy: true)
    
    var myConstraint: NSLayoutConstraint?
    
    var viewConstraints = [NSLayoutConstraint]()
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
    
        self.addSubview(self.avatarView)
        self.addSubview(self.displayNameLabel)
        self.addSubview(self.timestampLabel)
        self.addSubview(self.postLabel)
        self.addSubview(self.likeButton)
        self.addSubview(self.commentButton)
        self.addSubview(self.shareButton)
        
        let buttonTrait = "DefaultButton"
        self.likeButton.refl_appearanceProxy.trait = buttonTrait
        self.commentButton.refl_appearanceProxy.trait = buttonTrait
        self.shareButton.refl_appearanceProxy.trait = buttonTrait

        self.refl_appearanceProxy.applyComputedProperties(false)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        //applies the properties from the appearance proxy
        self.refl_appearanceProxy.applyComputedProperties()
    }
    
    override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        self.refl_applyStyleRecursive()
        self.updateConstraints()
    }
    
    override func updateConstraints() {
        
        super.updateConstraints()
        
        //activate/deactivate the constraints
        NSLayoutConstraint.deactivateConstraints(self.viewConstraints)
        self.viewConstraints = self.refl_appearanceProxy.constraints;
        NSLayoutConstraint.activateConstraints(self.viewConstraints)
    }
}

class DemoViewController: UIViewController {
    
    private var constraints = [NSLayoutConstraint]()
    private let containerView = DemoContainerView(frame:  CGRect.zero, useAppearanceProxy: true)

    override func viewDidLoad() {
        
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.containerView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.containerView)
        
        self.updateViewConstraints()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        self.refl_applyStyleToViewRecursive()
        self.updateViewConstraints()
    }
    
    override func viewDidLayoutSubviews() {
        self.refl_applyStyleToViewRecursive(true)
    }

}


