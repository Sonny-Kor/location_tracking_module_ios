//
//  UIView+.swift
//  AdminApp
//
//  Created by 승재 on 4/29/24.
//

import UIKit

// UIView Extension
extension UIView {
    
    // Set Rounded View
    func makeRounded(cornerRadius : CGFloat?){
        // UIView 의 모서리가 둥근 정도를 설정
        if let cornerRadius_ = cornerRadius {
            self.layer.cornerRadius = cornerRadius_
        }  else {
            // cornerRadius 가 nil 일 경우의 default
            self.layer.cornerRadius = self.layer.frame.height / 2
        }
        
        self.layer.masksToBounds = true
    }
    
    // Set UIView's Shadow
    func dropShadow(color: UIColor, offSet: CGSize, opacity: Float, radius: CGFloat) {
        
        // 그림자 색상 설정
        layer.shadowColor = color.cgColor
        // 그림자 크기 설정
        layer.shadowOffset = offSet
        // 그림자 투명도 설정
        layer.shadowOpacity = opacity
        // 그림자의 blur 설정
        layer.shadowRadius = radius
        layer.masksToBounds = false
    }
}
