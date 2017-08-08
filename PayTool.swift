//
//  PayTool.swift
//  PayTool
//
//  Created by KevinLex on 2017/6/8.
//  Copyright © 2017年 KevinLex. All rights reserved.
//

import Foundation
import SVProgressHUD

class PayTool {
    
    var canPay : Bool = true
    /// 支付成功回调
    var paySuccess : (()->())?
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(alipayBack), name: NSNotification.Name(rawValue: AlipayBackNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(wechatPayDidDone), name: NSNotification.Name(rawValue: WXpayBackNotification), object: nil)
    }
    
    /// 支付
    ///
    /// - Parameters:
    ///   - orderId: 订单id
    ///   - orderType:订单类型
    ///   - payType: 支付方式，1微信 2支付宝
    func pay(orderId : Int, orderType : Int, payType : Int) {
        
        if canPay == false {//还未收到返回，禁止多次提交
            return
        }
        
        canPay = false
        
        // 展示菊花
        SVProgressHUD.show()
        
        // 网络请求,自定义,需修改为项目对应的网络请求方法
        NetworkTool.sharedInstance.do_post_pay(orderId: orderId, orderType: orderType, payType: payType, success: { (result, isSuccess) in
            
            SVProgressHUD.dismiss()
            
            if isSuccess {
                let body = result["body"] as? [AnyHashable : Any] ?? [:]
                let data = body["data"] as? [AnyHashable : Any] ?? [:]
                if let payinfo = data["payinfo"] as? String {
                    if payType == 2{//支付宝支付
                        self.pay_alipay(order: payinfo, scheme: appScheme)
                    } else if payType == 1{//微信支付
                        let info = payinfo as NSString
                        if let dic = info.cz_jsonToDic(),
                            let appId = dic["appId"] as? String,
                            let partnerId = dic["partnerId"] as? String,
                            let prepayId = dic["prepayId"] as? String,
                            let nonceStr = dic["nonceStr"] as? String,
                            let timeStampStr = dic["timeStamp"] as? String,
                            let timeStamp = UInt32(timeStampStr),
                            let packageValue = dic["packageValue"] as? String,
                            let sign = dic["sign"] as? String{
                            self.pay_wx(openID: appId, partnerId: partnerId, prepayId: prepayId, nonceStr: nonceStr, timeStamp: timeStamp, package: packageValue, sign: sign)
                        } else {
                            SVProgressHUD.showError(withStatus: "支付数据错误")
                        }
                    }
                }
            }
            self.canPay = true
            
        }) { (error) in
            self.canPay = true
        }
    }
    
    // 微信支付调起
    private func pay_wx(openID : String, partnerId : String, prepayId : String, nonceStr : String, timeStamp : UInt32, package : String, sign : String) {
        
        WXApi.registerApp(openID)
        
        let req = PayReq.init()
        req.openID = openID
        req.partnerId = partnerId
        req.prepayId = prepayId
        req.nonceStr = nonceStr
        req.timeStamp = timeStamp
        req.package = package
        req.sign = sign
        
        WXApi.send(req)
    }
    
    // 支付宝支付调起
    private func pay_alipay(order : String, scheme : String) {
        let alipaySDK = AlipaySDK.defaultService()
        alipaySDK?.payOrder(order, fromScheme: scheme, callback: { (resultDic) in
            //快捷支付开发包回调函数，返回免登、支付结果。本地未安装支付宝客户端，或未成功调用支付宝客户端进行支付的情况下（走H5收银台），会通过该本callback返回支付结果。
            self.alipayPayDidDone(resultDic: resultDic ?? [:])
            self.canPay = true
        })
    }
    // 支付宝回调处理
    private func alipayPayDidDone(resultDic : [AnyHashable : Any]) -> Void{
        if let status = resultDic["resultStatus"] as? String{
            switch status {
            case "9000" :
                SVProgressHUD.showSuccess(withStatus: "支付成功")
                if self.paySuccess != nil {
                    self.paySuccess!()
                }
            case "8000" :
                SVProgressHUD.showInfo(withStatus: "正在处理中")
            case "4000" :
                SVProgressHUD.showError(withStatus: "订单支付失败")
            case "6001" :
                SVProgressHUD.showInfo(withStatus: "取消支付")
            case "6002" :
                SVProgressHUD.showError(withStatus: "网络连接出错")
            default :
                if let memo = resultDic["memo"] as? String{
                    SVProgressHUD.showError(withStatus: memo)
                } else {
                    SVProgressHUD.showError(withStatus: "支付失败")
                }
            }
        }
    }
    
    // 微信回调处理
    @objc private func wechatPayDidDone(notification : Notification){
        if let payResp = notification.object as? PayResp {
            switch payResp.errCode {
            case 0:/**< 成功    */
                SVProgressHUD.showSuccess(withStatus: "支付成功")
                 if self.paySuccess != nil {
                    self.paySuccess!()
                }
            case -1:/**< 普通错误类型    */
                break
            case -2:/**< 用户点击取消并返回    */
                SVProgressHUD.showInfo(withStatus: "取消支付")
            case -3: /**< 发送失败    */
                SVProgressHUD.showError(withStatus: "网络连接出错")
            case -4:/**< 授权失败    */
                SVProgressHUD.showError(withStatus: "授权失败")
            case -5:/**< 微信不支持    */
                SVProgressHUD.showError(withStatus: "微信不支持")
            default:
                SVProgressHUD.showError(withStatus: "支付失败")
            }
        }
    }
    
    /// 正常调用支付宝app通过appdelegate中返回结果，通过发通知在本处调用
    @objc private func alipayBack(notification : Notification) {
        
        if let resultDic = notification.object as? [AnyHashable : Any] {
            alipayPayDidDone(resultDic: resultDic)
        }
    }
    
    /// 删除通知
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: AlipayBackNotification), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: WXpayBackNotification), object: nil)
    }
    
}
