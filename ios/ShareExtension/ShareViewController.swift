//
//  ShareViewController.swift
//  RouteNote Share Extension
//
//  Receives text/links shared from other apps and hands them to the main
//  RouteNote app, which parses them with LocationParser.
//
import receive_sharing_intent

class ShareViewController: RSIShareViewController {

    // Redirect straight to RouteNote once the share is handled.
    override func shouldAutoRedirect() -> Bool {
        return true
    }
}
