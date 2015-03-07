/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import WebKit

protocol BrowserHelper {
    class func name() -> String
    func scriptMessageHandlerName() -> String?
    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage)
}

class Browser: NSObject, WKScriptMessageHandler {
    let webView: UIWebView

    init(configuration: WKWebViewConfiguration) {
        configuration.userContentController = WKUserContentController()
        webView = UIWebView(frame: CGRectZero)
        
        webView.multipleTouchEnabled = true
        webView.scalesPageToFit = true

        // webView.allowsBackForwardNavigationGestures = true
        webView.accessibilityLabel = NSLocalizedString("Web content", comment: "Accessibility label for the main web content view")
        webView.backgroundColor = UIColor.lightGrayColor()

        super.init()
    }

    var loading: Bool {
        return webView.loading
    }

    var backList: [WKBackForwardListItem]? {
        return nil //webView.backForwardList.backList as? [WKBackForwardListItem]
    }

    var forwardList: [WKBackForwardListItem]? {
        return nil //webView.backForwardList.forwardList as? [WKBackForwardListItem]
    }

    var title: String? {
//        if let title = webView.title {
//        	return title
//        }
        //return webView.URL?.absoluteString
        if let title = webView.stringByEvaluatingJavaScriptFromString("document.title") {
            return title
        }
        
        return webView.stringByEvaluatingJavaScriptFromString("window.location.href")
    }

    var url: NSURL? {
        //return webView.URL?
        return NSURL(string: webView.stringByEvaluatingJavaScriptFromString("window.location.href")!)
    }

    var canGoBack: Bool {
        return webView.canGoBack
    }

    var canGoForward: Bool {
        return webView.canGoForward
    }

    func goBack() {
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    func goToBackForwardListItem(item: WKBackForwardListItem) {
        // webView.goToBackForwardListItem(item)
    }

    func loadRequest(request: NSURLRequest) {
        webView.loadRequest(request)
    }

    func stop() {
        webView.stopLoading()
    }

    func reload() {
        webView.reload()
    }

    private var helpers: [String: BrowserHelper] = [String: BrowserHelper]()

    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        for helper in helpers.values {
            if let scriptMessageHandlerName = helper.scriptMessageHandlerName() {
                if scriptMessageHandlerName == message.name {
                    helper.userContentController(userContentController, didReceiveScriptMessage: message)
                    return
                }
            }
        }
    }

    func addHelper(helper: BrowserHelper, name: String) {
        if let existingHelper = helpers[name] {
            assertionFailure("Duplicate helper added: \(name)")
        }

        helpers[name] = helper

        // If this helper handles script messages, then get the handler name and register it. The Browser
        // receives all messages and then dispatches them to the right BrowserHelper.
        if let scriptMessageHandlerName = helper.scriptMessageHandlerName() {
            //webView.configuration.userContentController.addScriptMessageHandler(self, name: scriptMessageHandlerName)
        }
    }

    func getHelper(#name: String) -> BrowserHelper? {
        return helpers[name]
    }

    func screenshot(size: CGSize? = nil) -> UIImage? {
        // TODO: We should adjust this if the inset is offscreen
        let top = -webView.scrollView.contentInset.top

        if let size = size {
            UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.mainScreen().scale)
        } else {
            UIGraphicsBeginImageContextWithOptions(webView.frame.size, false, UIScreen.mainScreen().scale)
        }

        webView.drawViewHierarchyInRect(CGRect(x: 0,
            y: top,
            width: webView.frame.width,
            height: webView.frame.height),
            afterScreenUpdates: false)

        var img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return img
    }

    func hideContent(animated: Bool = false) {
        webView.userInteractionEnabled = false
        if animated {
            UIView.animateWithDuration(0.25, animations: { () -> Void in
                self.webView.alpha = 0.0
            })
        } else {
            webView.alpha = 0.0
        }
    }

    func showContent(animated: Bool = false) {
        webView.userInteractionEnabled = true
        if animated {
            UIView.animateWithDuration(0.25, animations: { () -> Void in
                self.webView.alpha = 1.0
            })
        } else {
            webView.alpha = 1.0
        }
    }
}

extension WKWebView {

    func runScriptFunction(function: String, fromScript: String, callback: (AnyObject?) -> Void) {
        if let path = NSBundle.mainBundle().pathForResource(fromScript, ofType: "js") {
            if let source = NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding, error: nil) {
                evaluateJavaScript(source, completionHandler: { (obj, err) -> Void in
                    if let err = err {
                        println("Error injecting \(err)")
                        return
                    }

                    self.evaluateJavaScript("__firefox__.\(fromScript).\(function)", completionHandler: { (obj, err) -> Void in
                        self.evaluateJavaScript("delete window.__firefox__.\(fromScript)", completionHandler: { (obj, err) -> Void in })
                        if let err = err {
                            println("Error running \(err)")
                            return
                        }
                        callback(obj)
                    })
                })
            }
        }
    }
}
