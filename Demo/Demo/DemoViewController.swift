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
    var titleStackView: UIStackView

    let postLabel = UILabel(frame: CGRect.zero, useAppearanceProxy: true)
    
    let likeButton = UIButton(frame: CGRect.zero, useAppearanceProxy: true)
    let commentButton = UIButton(frame: CGRect.zero, useAppearanceProxy: true)
    let shareButton = UIButton(frame: CGRect.zero, useAppearanceProxy: true)
    var buttonsStackView: UIStackView
    
    var viewConstraints = [NSLayoutConstraint]()
    
    override init(frame: CGRect) {
            
        self.titleStackView = UIStackView(arrangedSubviews: [self.displayNameLabel, self.timestampLabel])
        self.buttonsStackView = UIStackView(arrangedSubviews: [self.likeButton, self.commentButton, self.shareButton])
        
        super.init(frame: frame)
    
        self.addSubview(self.avatarView)
        self.addSubview(self.titleStackView)
        self.addSubview(self.postLabel)
        self.addSubview(self.buttonsStackView)
        
        self.refl_setDefaultTraitNamesToSubviews()
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
        super.traitCollectionDidChange(previousTraitCollection)
        
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


