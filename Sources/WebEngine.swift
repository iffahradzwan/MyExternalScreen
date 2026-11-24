import UIKit
import WebKit

final class WebEngine {
    static func makeWebView(delegate: WKNavigationDelegate) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let s1 = "HTMLVideoElement.prototype.webkitEnterFullscreen=function(){};"
        let s2 = "HTMLVideoElement.prototype.webkitEnterFullScreen=function(){};"
        let s3 = "Element.prototype.requestFullscreen=function(){return Promise.resolve();};"
        let s4 = "Element.prototype.webkitRequestFullscreen=function(){};"
        let s4b = "window.open=function(){return null;};"
        let s5 = "var st=document.createElement('style');st.textContent='ytd-ad-slot-renderer,ytd-promoted-sparkles-web-renderer,.ytp-ad-overlay-container{display:none!important;}';if(document.head||document.documentElement){(document.head||document.documentElement).appendChild(st);}"
        let s6 = "var wasMuted=false;setInterval(function(){"
        let s7 = "document.querySelectorAll('video').forEach(function(v){v.setAttribute('playsinline','');v.setAttribute('webkit-playsinline','');});"
        let s8 = "var s=document.querySelector('.ytp-skip-ad-button,.ytp-ad-skip-button,.ytp-ad-skip-button-modern,.ytp-skip-ad-button__text');"
        let s9 = "if(s){s.click();}"
        let s10 = "var ad=document.querySelector('.ad-showing,.ad-interrupting');"
        let s11 = "var v=document.querySelector('#movie_player video,.html5-main-video');"
        let s12 = "if(ad&&v){if(!v.muted){wasMuted=false;v.muted=true;}if(v.playbackRate!==16){v.playbackRate=16;}}else if(v&&v.playbackRate===16){v.playbackRate=1;if(!wasMuted){v.muted=false;}}"
        let s13 = "},500);"
        let s14 = "window.addEventListener('message',function(e){var d=e.data;if(!d||!d.cmd)return;var v=document.querySelector('video');if(!v)return;if(d.cmd==='toggle'){v.paused?v.play():v.pause();}else if(d.cmd==='skip'&&isFinite(v.duration)){v.currentTime=Math.min(Math.max(0,v.currentTime+d.val),v.duration);}else if(d.cmd==='seek'&&isFinite(v.duration)){v.currentTime=v.duration*d.val;}});"
        let script = WKUserScript(
            source: s1 + s2 + s3 + s4 + s4b + s5 + s6 + s7 + s8 + s9 + s10 + s11 + s12 + s13 + s14,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(script)
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = delegate
        wv.customUserAgent = "Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        wv.backgroundColor = .black
        wv.isOpaque = true
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        return wv
    }
    
    static func pauseAllMedia(in webViews: [WKWebView?]) {
        let js = "document.querySelectorAll('video,audio').forEach(function(m){m.pause();});"
        webViews.forEach { $0?.evaluateJavaScript(js, completionHandler: nil) }
    }
    
    static func clickAt(point: CGPoint, in webView: WKWebView, onFullscreen: @escaping () -> Void, onInput: @escaping (String) -> Void) {
       let px = String(Double(point.x))
        let py = String(Double(point.y))
        let txtSel = "textarea,input:not([type=hidden]):not([type=file]):not([type=submit]):not([type=button]):not([type=checkbox]):not([type=radio])"
        
        let c1 = "(function(){var doc=document;var x=" + px + ";var y=" + py + ";"
        let c2 = "var el=doc.elementFromPoint(x,y);"
        let c3 = "while(el&&el.tagName==='IFRAME'){try{var r=el.getBoundingClientRect();x-=r.left;y-=r.top;doc=el.contentDocument;if(!doc)break;el=doc.elementFromPoint(x,y);}catch(e){break;}}"
        let c4 = "if(!el)return null;"
        let c5 = "var inp=el.matches('" + txtSel + "')?el:el.closest('" + txtSel + "');"
        let c6 = "if(!inp&&!el.closest('button,[role=button],a,[role=option],li')){var box=el.closest('[role=search],[role=combobox],.RNNXgb,.ytSearchboxComponentInputBox');if(box){inp=box.querySelector('" + txtSel + "');}}"
        let c7 = "if(inp){window.__lastFocusedInput=inp;inp.focus();return {isInput:true,val:(inp.value||'')};}"
        let c8 = "window.__lastFocusedInput=null;"
        let c9 = " if(el.closest('.ytp-fullscreen-button,.fullscreen-icon,[aria-label*=\"full screen\" i],[aria-label*=\"fullscreen\" i]')){return {isInput:false,hitFullscreen:true};}"
        let c10 = "var t=el.closest('a,button,[role=button],[role=option],[role=tab],[role=link],[role=menuitem],[role=menuitemradio],[role=menuitemcheckbox],.ytp-menuitem,li,select,label,yt-formatted-string,ytd-thumbnail')||el;"
        let c11 = "if(t.focus){t.focus();}"
        let c12 = "var po={view:window,bubbles:true,cancelable:true,clientX:x,clientY:y,pointerId:1,pointerType:'mouse',isPrimary:true,button:0,buttons:1};"
        let c13 = "var mo={view:window,bubbles:true,cancelable:true,clientX:x,clientY:y,button:0,buttons:1};"
        let c14 = "if(window.PointerEvent){t.dispatchEvent(new PointerEvent('pointerdown',po));}"
        let c15 = "t.dispatchEvent(new MouseEvent('mousedown',mo));"
        let c16 = "if(window.PointerEvent){t.dispatchEvent(new PointerEvent('pointerup',po));}"
        let c17 = "t.dispatchEvent(new MouseEvent('mouseup',mo));"
        let c18 = "t.dispatchEvent(new MouseEvent('click',mo));"
        let c19 = "if(t.tagName==='A'&&t.href&&t.href.indexOf('javascript:')!==0&&t.target!=='_blank'){window.location.href=t.href;}"
        let c20 = "return {isInput:false,hitFullscreen:false};})();"
        
        webView.evaluateJavaScript(c1 + c2 + c3 + c4 + c5 + c6 + c7 + c8 + c9 + c10 + c11 + c12 + c13 + c14 + c15 + c16 + c17 + c18 + c19 + c20) { res, _ in
            guard let dict = res as? [String: Any] else { return }
            if let hitFS = dict["hitFullscreen"] as? Bool, hitFS {
                onFullscreen()
                return
            }
            if let isInput = dict["isInput"] as? Bool, isInput {
                onInput((dict["val"] as? String) ?? "")
            }
        }
    }
    static func hoverAt(point: CGPoint, in webView: WKWebView?) {
    let x = Double(point.x)
    let y = Double(point.y)
    let h1 = "var el=document.elementFromPoint(\(x),\(y));var onVid=el&&el.closest('#movie_player,.html5-video-player,video,#player-control-overlay');"
    let h2 = "var p=document.getElementById('movie_player');if(p){onVid?p.classList.remove('ytp-autohide'):p.classList.add('ytp-autohide');}"
    let h3 = "var ov=document.getElementById('player-control-overlay');if(ov){if(onVid){ov.classList.add('fadein');ov.style.opacity='1';}else{ov.classList.remove('fadein');ov.style.opacity='0';}}"
        let h3b = "if(el){el.dispatchEvent(new MouseEvent('mousemove',{bubbles:true,clientX:\(x),clientY:\(y)}));if(window.PointerEvent)el.dispatchEvent(new PointerEvent('pointermove',{bubbles:true,clientX:\(x),clientY:\(y)}));}"
    let h4 = "clearTimeout(window.__ytHideT);if(onVid){window.__ytHideT=setTimeout(function(){"
    let h5 = "if(p)p.classList.add('ytp-autohide');if(ov){ov.classList.remove('fadein');ov.style.opacity='0';}},2500);}"
    webView?.evaluateJavaScript(h1 + h2 + h3 + h3b + h4 + h5, completionHandler: nil)
}

    
    static func typeText(_ text: String, submit: Bool, into webView: WKWebView?) {
        let base64 = Data(text.utf8).base64EncodedString()
        let submitFlag = submit ? "true" : "false"
        let txtSel = "textarea,input:not([type=hidden]):not([type=file]):not([type=submit]):not([type=button]):not([type=checkbox]):not([type=radio])"
        
        let t1 = "(function(){var bin=atob('" + base64 + "');var b=new Uint8Array(bin.length);"
        let t2 = "for(var i=0;i<bin.length;i++){b[i]=bin.charCodeAt(i);}"
        let t3 = "var val=new TextDecoder().decode(b);var inp=window.__lastFocusedInput||document.activeElement;"
        let t4 = "if(!inp||!inp.matches('" + txtSel + "')){inp=document.querySelector('" + txtSel + "');}"
        let t5 = "if(!inp)return;window.__lastFocusedInput=inp;inp.focus();"
        let t6 = "var s=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value');"
        let t7 = "var ts=Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype,'value');"
        let t8 = "if(inp.tagName==='TEXTAREA'&&ts&&ts.set){ts.set.call(inp,val);}else if(s&&s.set){s.set.call(inp,val);}else{inp.value=val;}"
        let t9 = "inp.dispatchEvent(new Event('input',{bubbles:true}));inp.dispatchEvent(new Event('change',{bubbles:true}));"
        let t10 = "if(" + submitFlag + "){"
        let t11 = "inp.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true}));"
        let t12 = "inp.dispatchEvent(new KeyboardEvent('keypress',{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true}));"
        let t13 = "inp.dispatchEvent(new KeyboardEvent('keyup',{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true}));"
       let t14 = "var sb=document.querySelector('button[aria-label*=\"Search\" i],.ytSearchboxComponentSearchButton,#search-icon-legacy');if(sb){sb.click();}var f=inp.closest('form');if(f){f.submit();}"
        let t15 = "}})();"
        
        webView?.evaluateJavaScript(t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11 + t12 + t13 + t14 + t15, completionHandler: nil)
    }
    
    static func hasFocusedInput(in webView: WKWebView?, completion: @escaping (Bool) -> Void) {
        let js = "Boolean(window.__lastFocusedInput)"
        webView?.evaluateJavaScript(js) { res, _ in
            completion((res as? Bool) ?? false)
        }
    }
    
    static func skipVideo(seconds: Double, in webView: WKWebView?) {
        let sec = String(seconds)
        let k1 = "(function(){var vids=Array.from(document.querySelectorAll('video'));"
        // In skipVideo, seekVideo, and getVideoProgress:
let k2 = " var v=vids.find(function(x){return !x.paused&&x.duration>0;})||document.querySelector('#movie_player video')||vids[0];"


       let k3 = "if(v&&isFinite(v.duration)){v.currentTime=Math.min(Math.max(0,v.currentTime+" + sec + "),v.duration);}document.querySelectorAll('iframe').forEach(function(f){try{f.contentWindow.postMessage({cmd:'skip',val:" + sec + "},'*');}catch(e){}});})();"

        
        webView?.evaluateJavaScript(k1 + k2 + k3, completionHandler: nil)
    }
    
    static func seekVideo(fraction: Double, in webView: WKWebView?) {
        let frac = String(fraction)
        let k1 = "(function(){var vids=Array.from(document.querySelectorAll('video'));"// In skipVideo, seekVideo, and getVideoProgress:
let k2 = " var v=vids.find(function(x){return !x.paused&&x.duration>0;})||document.querySelector('#movie_player video')||vids[0];"


        let k3 = "if(v&&isFinite(v.duration)&&v.duration>0){v.currentTime=v.duration*" + frac + ";}document.querySelectorAll('iframe').forEach(function(f){try{f.contentWindow.postMessage({cmd:'seek',val:" + frac + "},'*');}catch(e){}});})();"

        webView?.evaluateJavaScript(k1 + k2 + k3, completionHandler: nil)
    }
    
    static func togglePlayPause(in webView: WKWebView?) {
        let p1 = "(function(){var vids=Array.from(document.querySelectorAll('video'));"
        let p2 = "var v=vids.find(function(x){return x.duration>0;})||vids[0];"
       let p3 = "if(v){v.paused?v.play():v.pause();}document.querySelectorAll('iframe').forEach(function(f){try{f.contentWindow.postMessage({cmd:'toggle'},'*');}catch(e){}});})();"

        webView?.evaluateJavaScript(p1 + p2 + p3, completionHandler: nil)
    }
    
    static func getVideoProgress(in webView: WKWebView?, completion: @escaping (Double, Double) -> Void) {
        let t1 = "(function(){var vids=Array.from(document.querySelectorAll('video'));"
        let t2 = "var v=vids.find(function(x){return !x.paused&&x.duration>0;})||document.querySelector('#movie_player video')||vids[0];"
        let t3 = "if(!v||!isFinite(v.duration)||v.duration<=0)return null;return [v.currentTime,v.duration];})();"

webView?.evaluateJavaScript(t1 + t2 + t3) { result, _ in
guard let arr = result as? [Double], let cur = arr.first, let dur = arr.last, dur > 0 else { return }
completion(cur, dur)
}
}
static func toggleWebFullscreen(isFull: Bool, in webView: WKWebView?) {
let fullFlag = isFull ? "true" : "false"
let f1 = "(function(){document.querySelectorAll('video').forEach(function(v){if(v.webkitExitFullscreen){try{v.webkitExitFullscreen();}catch(e){}}});"
let f2 = "var style=document.getElementById('custom-fs-style');"
let f3 = "if(" + fullFlag + "){"
let f4 = "if(!style){style=document.createElement('style');style.id='custom-fs-style';"
let f5 = "style.textContent='body{overflow:hidden!important;}iframe,#movie_player,.html5-video-player,video{position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:999999!important;background:#000!important;object-fit:cover!important;}#player-control-overlay,.player-controls-content{position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:1000000!important;}ytd-masthead,#secondary,#below,#guide,ytm-mobile-topbar-renderer,ytm-engagement-panel-section-list-renderer{display:none!important;}';"
let f6 = "document.head.appendChild(style);}"
let f7 = "}else{if(style){style.remove();}}window.dispatchEvent(new Event('resize'));})();"
webView?.evaluateJavaScript(f1 + f2 + f3 + f4 + f5 + f6 + f7, completionHandler: nil)
}
}
