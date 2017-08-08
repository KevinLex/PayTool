//
//  AppDelegate+CallBack.swift
//  PayTool
//
//  Created by KevinLex on 2017/6/10.
//  Copyright © 2017年 KevinLex. All rights reserved.
//

import Foundation
extension AppDelegate {
    /// iOS9.0以前的回调方法
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        return applicationOpenURL(url: url)
    }
    
    /// iOS9.0以后的回调方法
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return applicationOpenURL(url: url)
    }
    
    /// 回调
    func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
        return applicationOpenURL(url: url)
    }
    
    /// 判断支付宝还是微信
    func applicationOpenURL(url: URL) -> Bool{
        if url.scheme == WX_APPID {
            return WXApi.handleOpen(url, delegate: self)
        }
        handAlipayResult(url: url)
        return true
    }
    
    //跳转支付宝钱包进行支付，处理支付结果
    private func handAlipayResult(url: URL) {
        if url.host == "safepay" {
            AlipaySDK.defaultService().processOrder(withPaymentResult: url, standbyCallback: { (resultDic) in
                print(resultDic ?? "")
                
                // 发出支付通知
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: AlipayBackNotification), object: resultDic)
            })
            
        }
    }
    
}

/// 微信回调代理
extension AppDelegate : WXApiDelegate{
    func onResp(_ resp: BaseResp!) {
        if resp.isKind(of: PayResp.self){
            // 发出支付通知
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: WXpayBackNotification), object: resp)
        }
    }
    

}
