import UIKit
import WebKit

final class WebEngine {
    private static let msgToken = UUID().uuidString
    static func makeWebView(delegate: WKNavigationDelegate, isDesktop: Bool = false) -> WKWebView {
        let config = WKWebViewConfiguration()
        if let handler = delegate as? WKScriptMessageHandler {
            config.userContentController.add(handler, name: "fullscreenToggle")
        }
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = []

        // 1. EARLY AD-STRIPPING, VISIBILITY & PLAYSINLINE (.atDocumentStart)
        let e1 = "(function(){try{Object.defineProperty(document,'hidden',{get:function(){return false;}});Object.defineProperty(document,'webkitHidden',{get:function(){return false;}});Object.defineProperty(document,'visibilityState',{get:function(){return 'visible';}});Object.defineProperty(document,'webkitVisibilityState',{get:function(){return 'visible';}});document.addEventListener('visibilitychange',function(e){e.stopImmediatePropagation();},true);document.addEventListener('webkitvisibilitychange',function(e){e.stopImmediatePropagation();},true);}catch(e){}"
        let e2 = "var origCreate=document.createElement;document.createElement=function(tag,opt){var el=origCreate.call(this,tag,opt);if(typeof tag==='string'&&tag.toLowerCase()==='video'){el.setAttribute('playsinline','');el.setAttribute('webkit-playsinline','');el.playsInline=true;}return el;};"
        let e3 = "function cleanAdData(o){if(!o||typeof o!=='object')return o;delete o.adPlacements;delete o.playerAds;delete o.adSlots;delete o.adBreakHeartbeatParams;return o;}"
        let e4 = "var _ytInit=undefined;try{Object.defineProperty(window,'ytInitialPlayerResponse',{configurable:true,get:function(){return _ytInit;},set:function(v){_ytInit=cleanAdData(v);}});}catch(e){}"
        let e5 = "var origParse=JSON.parse;JSON.parse=function(){return cleanAdData(origParse.apply(this,arguments));};"
        let e6 = "var origJson=Response.prototype.json;Response.prototype.json=async function(){return cleanAdData(await origJson.apply(this,arguments));};"
        let e7 = "var origOpen=XMLHttpRequest.prototype.open;XMLHttpRequest.prototype.open=function(m,u){this.__u=typeof u==='string'?u:'';return origOpen.apply(this,arguments);};var origSend=XMLHttpRequest.prototype.send;XMLHttpRequest.prototype.send=function(){if(this.__u&&(this.__u.indexOf('/youtubei/v1/player')!==-1||this.__u.indexOf('/youtubei/v1/next')!==-1)){this.addEventListener('readystatechange',function(){if(this.readyState===4&&this.responseText){try{var c=JSON.stringify(cleanAdData(origParse(this.responseText)));Object.defineProperty(this,'responseText',{get:function(){return c;}});Object.defineProperty(this,'response',{get:function(){return c;}});}catch(e){}}});}return origSend.apply(this,arguments);};})();"

        config.userContentController.addUserScript(
            WKUserScript(source: e1 + e2 + e3 + e4 + e5 + e6 + e7, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )

    // 2. NETWORK-LEVEL CONTENT BLOCKER
    let blockRules = """
    [
        {
            "trigger": {
                "url-filter": ".*(doubleclick\\\\.net|googlesyndication\\\\.com|googleadservices\\\\.com|youtube\\\\.com/pagead/|youtube\\\\.com/api/stats/ads).*"
            },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*youtube\\\\.com.*" },
            "action": {
                "type": "css-display-none",
                "selector": "ytd-ad-slot-renderer, ytd-promoted-sparkles-web-renderer, ytd-banner-promo-renderer, #masthead-ad, .ytp-ad-module, .ytp-ad-overlay-container"
            }
        }
    ]
    """
    WKContentRuleListStore.default().compileContentRuleList(
        forIdentifier: "PeekabooAdBlocker",
        encodedContentRuleList: blockRules
    ) { ruleList, _ in
        if let ruleList = ruleList {
            DispatchQueue.main.async {
                config.userContentController.add(ruleList)
            }
        }
    }

    // 3. SAFETY OVERRIDES, FALLBACK SKIPPER, UNMUTER & IFRAME CONTROLS (.atDocumentEnd)
    let s1 = "HTMLVideoElement.prototype.webkitEnterFullscreen=function(){};"
    let s2 = "HTMLVideoElement.prototype.webkitEnterFullScreen=function(){};"
    let s3 = "Element.prototype.requestFullscreen=function(){return Promise.resolve();};"
    let s4 = "Element.prototype.webkitRequestFullscreen=function(){};"
    let s4b = "window.open=function(){return null;};"
    let s5 = "var st=document.createElement('style');st.textContent='ytd-ad-slot-renderer,ytd-promoted-sparkles-web-renderer,.ytp-ad-overlay-container,.art-progress-tip,.jw-preview,.plyr__preview-thumb,[class*=\"preview\" i][class*=\"thumb\" i]{display:none!important;opacity:0!important;}';if(document.head||document.documentElement){(document.head||document.documentElement).appendChild(st);}"
    let s6 = "window.__userMuted=false;document.addEventListener('click',function(e){if(e.target&&e.target.closest('.ytp-mute-button')){var v=document.querySelector('video');if(v)window.__userMuted=!v.muted;}},true);setInterval(function(){"
    let s7 = "document.querySelectorAll('video').forEach(function(v){v.setAttribute('playsinline','');v.setAttribute('webkit-playsinline','');});"
    let s8 = "var skipBtns=document.querySelectorAll('.ytp-skip-ad-button,.ytp-ad-skip-button,.ytp-ad-skip-button-modern,.ytp-skip-ad-button__text,.ytp-ad-overlay-close-button');"
    let s9 = "skipBtns.forEach(function(s){if(window.PointerEvent){s.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true}));s.dispatchEvent(new PointerEvent('pointerup',{bubbles:true}));}s.dispatchEvent(new MouseEvent('mousedown',{bubbles:true}));s.dispatchEvent(new MouseEvent('mouseup',{bubbles:true}));s.click();});"
    let s10 = "var ad=document.querySelector('.ad-showing,.ad-interrupting');"
    let s11 = "var v=document.querySelector('#movie_player video,.html5-main-video');"
    let s12 = "if(ad&&v){v.muted=true;if(isFinite(v.duration)&&v.duration>0){v.currentTime=v.duration;}if(v.playbackRate!==16){v.playbackRate=16;}if(v.paused)v.play();}else if(v){if(v.playbackRate===16){v.playbackRate=1;if(v.paused)v.play();}if(!window.__userMuted&&v.muted){v.muted=false;v.volume=1;}}if(location.pathname.indexOf('/shorts/')===0){if(window.__lastShort!==location.pathname){window.__lastShort=location.pathname;setTimeout(function(){window.dispatchEvent(new Event('resize'));},150);}}else{window.__lastShort=null;}"
    let s13 = "},300);"
    let s14 = """
    window.addEventListener('message', function(e) {
        var d = e.data;
        if (!d || d.tok !== '\(msgToken)' || !d.cmd) return;
        var v = document.querySelector('video');

        if (d.cmd === 'iframe-fs') {
            document.querySelectorAll('iframe').forEach(function(f) {
                if (f.contentWindow === e.source) {
                    var pst = document.getElementById('if-parent-fs');
                    if (d.val) {
                        if (!pst) {
                            pst = document.createElement('style');
                            pst.id = 'if-parent-fs';
                            pst.textContent = 'html,body{margin:0!important;padding:0!important;overflow:hidden!important;}iframe[data-if-fs="1"]{position:fixed!important;inset:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;z-index:999999!important;background:#000!important;}';
                            document.head.appendChild(pst);
                        }
                        f.setAttribute('data-if-fs', '1');
                    } else {
                        f.removeAttribute('data-if-fs');
                        if (pst) pst.remove();
                    }
                }
            });
            if (window.parent && window.parent !== window) {
                window.parent.postMessage({ tok: '\(msgToken)', cmd: 'iframe-fs', val: d.val }, '*');
            } else if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.fullscreenToggle) {
                window.webkit.messageHandlers.fullscreenToggle.postMessage(Boolean(d.val));
            }
            return;
        }

        if (d.cmd === 'click') {
            var ce = document.elementFromPoint(d.x, d.y);
            if (ce) {
                var r = ce.getBoundingClientRect();
                var inCorner = (r.right > window.innerWidth - 90 && r.bottom > window.innerHeight - 90);
                var fsBtn = ce.closest('.jw-icon-fullscreen,.plyr__control[data-plyr="fullscreen"],.vjs-fullscreen-control,.art-icon-fullscreen,[aria-label*="full" i],[title*="full" i],[class*="fullscreen" i]') || (inCorner ? ce.closest('button,[role=button],svg') : null);
                if (fsBtn && window.top !== window) {
                    window.__isIfFs = !window.__isIfFs;
                    var st = document.getElementById('if-fs');
                    if (window.__isIfFs) {
                        if (!st) {
                            st = document.createElement('style');
                            st.id = 'if-fs';
                            st.textContent = 'html,body{margin:0!important;padding:0!important;width:100vw!important;height:100vh!important;overflow:hidden!important;}video{position:fixed!important;inset:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;object-fit:cover!important;z-index:1!important;}button,[role=button],.jw-controls,.jw-display,.plyr__controls,.vjs-control-bar,.art-bottom,[class*="control" i]{z-index:999999!important;}';
                            document.head.appendChild(st);
                            }
                            } else if (st) {
                            st.remove();
                            }
                            window.parent.postMessage({ tok: '(msgToken)', cmd: 'iframe-fs', val: window.__isIfFs }, '*');
                            return;
                            }
                            var bt = ce.closest('button,[role=button],a,li,input,label,[tabindex]') || ce;
                            var po = { view: window, bubbles: true, cancelable: true, clientX: d.x, clientY: d.y, pointerId: 1, pointerType: 'mouse', isPrimary: true, button: 0, buttons: 1 };
                            var mo = { view: window, bubbles: true, cancelable: true, clientX: d.x, clientY: d.y, button: 0, buttons: 1 };
                            if (window.PointerEvent) bt.dispatchEvent(new PointerEvent('pointerdown', po));
                            bt.dispatchEvent(new MouseEvent('mousedown', mo));
                            if (window.PointerEvent) bt.dispatchEvent(new PointerEvent('pointerup', po));
                            bt.dispatchEvent(new MouseEvent('mouseup', mo));
                            bt.click();
                            }
                            return;
                            }
                            if (d.cmd === 'pause') {
                            document.querySelectorAll('video,audio').forEach(function(m) { m.pause(); });
                            document.querySelectorAll('iframe').forEach(function(f) {
                            try { f.contentWindow.postMessage(d, '*'); } catch (err) {}
                            });
                            return;
                            }
                            if (d.cmd === 'fs') {
                            var st = document.getElementById('if-fs');
                            if (d.val) {
                            if (!st) {
                            st = document.createElement('style');
                            st.id = 'if-fs';
                            st.textContent = 'html,body{margin:0!important;padding:0!important;width:100vw!important;height:100vh!important;overflow:hidden!important;}video{position:fixed!important;inset:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;object-fit:cover!important;z-index:1!important;}button,[role=button],.jw-controls,.jw-display,.plyr__controls,.vjs-control-bar,.art-bottom,[class*="control" i]{z-index:999999!important;}';
                            document.head.appendChild(st);
                            }
                            } else if (st) {
                            st.remove();
                            }
                            document.querySelectorAll('iframe').forEach(function(f) {
                            try { f.contentWindow.postMessage(d, '*'); } catch (err) {}
                            });
                            return;
                            }
                            if (d.cmd === 'down') {
                            var de = document.elementFromPoint(d.x, d.y) || document.body;
                            window.__dragEl = de;
                            de.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, clientX: d.x, clientY: d.y, pointerId: 1 }));
                            de.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, clientX: d.x, clientY: d.y, button: 0, buttons: 1 }));
                            return;
                            }
                            if (d.cmd === 'move') {
                            var me = window.__dragEl || document.elementFromPoint(d.x, d.y) || document.body;
                            me.dispatchEvent(new PointerEvent('pointermove', { bubbles: true, clientX: d.x, clientY: d.y, pointerId: 1 }));
                            me.dispatchEvent(new MouseEvent('mousemove', { bubbles: true, clientX: d.x, clientY: d.y, button: 0, buttons: 1 }));
                            return;
                            }
                            if (d.cmd === 'up') {
                            var ue = window.__dragEl || document.elementFromPoint(d.x, d.y) || document.body;
                            ue.dispatchEvent(new PointerEvent('pointerup', { bubbles: true, clientX: d.x, clientY: d.y, pointerId: 1 }));
                            ue.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, clientX: d.x, clientY: d.y, button: 0, buttons: 0 }));
                            window.__dragEl = null;
                            return;
                            }
                            if (d.cmd === 'hover') {
                            var hx = d.x || 100, hy = d.y || 100;
                            var he = document.elementFromPoint(hx, hy);
                            if (window.__lastHoverEl && window.__lastHoverEl !== he) {
                            window.__lastHoverEl.dispatchEvent(new MouseEvent('mouseout', { bubbles: true, clientX: hx, clientY: hy, relatedTarget: he }));
                            window.__lastHoverEl.dispatchEvent(new MouseEvent('mouseleave', { bubbles: false, clientX: hx, clientY: hy, relatedTarget: he }));
                            }
                            window.__lastHoverEl = he;
                            var onProg = he && he.closest('.art-control-progress,.plyr__progress,.jw-slider-time,.vjs-progress-control,[class*="progress" i],[class*="timeline" i]');
                            if (!onProg) {
                            document.querySelectorAll('.art-control-progress,.plyr__progress,.jw-slider-time,.vjs-progress-control').forEach(function(p) {
                            p.dispatchEvent(new MouseEvent('mouseleave', { bubbles: false, clientX: hx, clientY: hy }));
                            p.dispatchEvent(new MouseEvent('mouseout', { bubbles: true, clientX: hx, clientY: hy }));
                            });
                            }
                            if (he && he.tagName === 'IFRAME') {
                            var hr = he.getBoundingClientRect();
                            try { he.contentWindow.postMessage({ tok: '(msgToken)', cmd: 'hover', x: hx - hr.left, y: hy - hr.top }, '*'); } catch (err) {}
                            return;
                            }
                            var t = he || v || document.body;
                            t.dispatchEvent(new MouseEvent('mousemove', { bubbles: true, clientX: hx, clientY: hy }));
                            if (window.PointerEvent) t.dispatchEvent(new PointerEvent('pointermove', { bubbles: true, clientX: hx, clientY: hy }));
                            var pl = document.querySelector('.jwplayer,.plyr,.video-js,.art-video-player');
                            if (pl) {
                            pl.classList.remove('jw-flag-user-inactive', 'plyr--hide-controls', 'vjs-user-inactive', 'art-control-hide');
                            pl.classList.add('jw-flag-user-active', 'vjs-user-active', 'art-hover');
                            clearTimeout(window.__ifHide);
                            window.__ifHide = setTimeout(function() {
                            pl.classList.add('jw-flag-user-inactive', 'plyr--hide-controls', 'vjs-user-inactive');
                            pl.classList.remove('jw-flag-user-active', 'vjs-user-active', 'art-hover');
                            }, 2500);
                            }
                            return;
                            }
                            document.querySelectorAll('iframe').forEach(function(f) {
                            try { f.contentWindow.postMessage(d, '*'); } catch (err) {}
                            });
                            if (!v) return;
                            if (d.cmd === 'toggle') {
                            v.paused ? v.play() : v.pause();
                            } else if (d.cmd === 'skip' && isFinite(v.duration)) {
                            v.currentTime = Math.min(Math.max(0, v.currentTime + d.val), v.duration);
                                       } else if (d.cmd === 'seek' && isFinite(v.duration)) {
                v.currentTime = v.duration * d.val;
            }
        });
"""
        let script = WKUserScript(
            source: s1 + s2 + s3 + s4 + s4b + s5 + s6 + s7 + s8 + s9 + s10 + s11 + s12 + s13 + s14,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
                            )
                            config.userContentController.addUserScript(script)
                            let wv = WKWebView(frame: .zero, configuration: config)
                                   wv.customUserAgent = isDesktop
            ? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
            : "Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

                            wv.backgroundColor = .black
                            wv.isOpaque = true
                            wv.scrollView.contentInsetAdjustmentBehavior = .never
                            return wv
                            }
    static func pauseAllMedia(in webViews: [WKWebView?]) {
        let js = "document.querySelectorAll('video,audio').forEach(function(m){m.pause();});document.querySelectorAll('iframe').forEach(function(f){try{f.contentWindow.postMessage({tok:'\(msgToken)',cmd:'pause'},'*');}catch(e){}});"
        webViews.forEach { $0?.evaluateJavaScript(js, completionHandler: nil) }
    }
    
    static func clickAt(point: CGPoint, in webView: WKWebView, onFullscreen: @escaping () -> Void, onInput: @escaping (String) -> Void) {
       let px = String(Double(point.x))
        let py = String(Double(point.y))
        let txtSel = "textarea,input:not([type=hidden]):not([type=file]):not([type=submit]):not([type=button]):not([type=checkbox]):not([type=radio])"
        
        let c1 = "(function(){var doc=document;var x=" + px + ";var y=" + py + ";"
        let c2 = "var el=doc.elementFromPoint(x,y);"
       let c3 = "while(el&&el.tagName==='IFRAME'){var r=el.getBoundingClientRect();x-=r.left;y-=r.top;try{doc=el.contentDocument;if(!doc)throw 1;el=doc.elementFromPoint(x,y);}catch(e){try{el.contentWindow.postMessage({tok:'\(msgToken)',cmd:'click',x:x,y:y},'*');}catch(e2){}return {isInput:false,hitFullscreen:false};}}"
        let c4 = "if(!el)return null;"
        let c5 = "var inp=el.matches('" + txtSel + "')?el:el.closest('" + txtSel + "');"
        let c6 = "if(!inp&&!el.closest('button,[role=button],a,[role=option],li')){var box=el.closest('[role=search],[role=combobox],.RNNXgb,.ytSearchboxComponentInputBox');if(box){inp=box.querySelector('" + txtSel + "');}}"
        let c7 = "if(inp){window.__lastFocusedInput=inp;inp.focus();return {isInput:true,val:(inp.value||'')};}"
        let c8 = "window.__lastFocusedInput=null;"
        let c9 = " if(el.closest('.ytp-fullscreen-button,.fullscreen-icon,.jw-icon-fullscreen,.plyr__control[data-plyr=\"fullscreen\"],.vjs-fullscreen-control,.art-icon-fullscreen,[aria-label*=\"full screen\" i],[aria-label*=\"fullscreen\" i],[title*=\"fullscreen\" i]')){return {isInput:false,hitFullscreen:true};}"
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



    private static func sendDrag(cmd: String, pe: String, me: String, point: CGPoint, in webView: WKWebView?) {
        let x = Double(point.x)
        let y = Double(point.y)
        let d1 = "(function(){var x=\(x),y=\(y),el=document.elementFromPoint(x,y)||document.body;"
        let d2 = "if(el&&el.tagName==='IFRAME'){var r=el.getBoundingClientRect();try{el.contentWindow.postMessage({tok:'\(msgToken)',cmd:'\(cmd)',x:x-r.left,y:y-r.top},'*');}catch(e){}return;}"
        let d3 = "if('\(cmd)'==='down')window.__dragEl=el;var t=window.__dragEl||el;"
        let d4 = "if(window.PointerEvent)t.dispatchEvent(new PointerEvent('\(pe)',{bubbles:true,clientX:x,clientY:y,pointerId:1}));"
        let d5 = "t.dispatchEvent(new MouseEvent('\(me)',{bubbles:true,clientX:x,clientY:y,button:0,buttons:'\(cmd)'==='up'?0:1}));"
        let d6 = "if('\(cmd)'==='up')window.__dragEl=null;})();"
        webView?.evaluateJavaScript(d1 + d2 + d3 + d4 + d5 + d6, completionHandler: nil)
    }

    static func mouseDownAt(point: CGPoint, in webView: WKWebView?) {
        sendDrag(cmd: "down", pe: "pointerdown", me: "mousedown", point: point, in: webView)
    }

    static func dragTo(point: CGPoint, in webView: WKWebView?) {
        sendDrag(cmd: "move", pe: "pointermove", me: "mousemove", point: point, in: webView)
    }

    static func mouseUpAt(point: CGPoint, in webView: WKWebView?) {
        sendDrag(cmd: "up", pe: "pointerup", me: "mouseup", point: point, in: webView)
    }



    
      static func hoverAt(point: CGPoint, in webView: WKWebView?) {
        let x = Double(point.x)
        let y = Double(point.y)
        let h1 = "var el=document.elementFromPoint(\(x),\(y));var onVid=el&&el.closest('#movie_player,.html5-video-player,video,#player-control-overlay');"
        let h2 = "var p=document.getElementById('movie_player');if(p){onVid?p.classList.remove('ytp-autohide'):p.classList.add('ytp-autohide');}"
        let h3 = "var ov=document.getElementById('player-control-overlay');if(ov){if(onVid){ov.classList.add('fadein');ov.style.opacity='1';}else{ov.classList.remove('fadein');ov.style.opacity='0';}}"
        let h3b = "if(el){el.dispatchEvent(new MouseEvent('mousemove',{bubbles:true,clientX:\(x),clientY:\(y)}));if(window.PointerEvent)el.dispatchEvent(new PointerEvent('pointermove',{bubbles:true,clientX:\(x),clientY:\(y)}));}"
        let h3c = "if(el&&el.tagName==='IFRAME'){var r=el.getBoundingClientRect();try{el.contentWindow.postMessage({tok:'\(msgToken)',cmd:'hover',x:\(x)-r.left,y:\(y)-r.top},'*');}catch(e){}}"
        let h4 = "clearTimeout(window.__ytHideT);if(onVid){window.__ytHideT=setTimeout(function(){"
        let h5 = "if(p)p.classList.add('ytp-autohide');if(ov){ov.classList.remove('fadein');ov.style.opacity='0';}},2500);}"
        webView?.evaluateJavaScript(h1 + h2 + h3 + h3b + h3c + h4 + h5, completionHandler: nil)
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


       let k3 = "if(v&&isFinite(v.duration)){v.currentTime=Math.min(Math.max(0,v.currentTime+" + sec + "),v.duration);}document.querySelectorAll('iframe').forEach(function(f){try{f.contentWindow.postMessage({tok:'\(msgToken)',cmd:'skip',val:" + sec + "},'*');}catch(e){}});})();"

        
        webView?.evaluateJavaScript(k1 + k2 + k3, completionHandler: nil)
    }
    
    static func seekVideo(fraction: Double, in webView: WKWebView?) {
        let frac = String(fraction)
        let k1 = "(function(){var vids=Array.from(document.querySelectorAll('video'));"// In skipVideo, seekVideo, and getVideoProgress:
let k2 = " var v=vids.find(function(x){return !x.paused&&x.duration>0;})||document.querySelector('#movie_player video')||vids[0];"


        let k3 = "if(v&&isFinite(v.duration)&&v.duration>0){v.currentTime=v.duration*" + frac + ";}document.querySelectorAll('iframe').forEach(function(f){try{f.contentWindow.postMessage({tok:'\(msgToken)',cmd:'seek',val:" + frac + "},'*');}catch(e){}});})();"

        webView?.evaluateJavaScript(k1 + k2 + k3, completionHandler: nil)
    }
    
    static func togglePlayPause(in webView: WKWebView?) {
        let p1 = "(function(){var vids=Array.from(document.querySelectorAll('video'));"
        let p2 = "var v=vids.find(function(x){return x.duration>0;})||vids[0];"
       let p3 = "if(v){v.paused?v.play():v.pause();}document.querySelectorAll('iframe').forEach(function(f){try{f.contentWindow.postMessage({tok:'\(msgToken)',cmd:'toggle'},'*');}catch(e){}});})();"

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
        let f5 = "style.textContent='body{overflow:hidden!important;}iframe,#movie_player,.html5-video-player{position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;z-index:999999!important;background:#000!important;}#movie_player video,.html5-video-container,.html5-main-video{position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;z-index:1!important;object-fit:cover!important;}.ytp-chrome-bottom,.ytp-chrome-top,.ytp-gradient-bottom,.ytp-gradient-top,#player-control-overlay,.player-controls-content{z-index:1000000!important;}ytd-masthead,#secondary,#below,#guide,#inline-preview-player,ytm-mobile-topbar-renderer,ytm-engagement-panel-section-list-renderer{display:none!important;}';"
        let f6 = "document.head.appendChild(style);}"
        let f7 = "}else{if(style){style.remove();}}document.querySelectorAll('iframe').forEach(function(f){try{f.contentWindow.postMessage({tok:'\(msgToken)',cmd:'fs',val:" + fullFlag + "},'*');}catch(e){}});window.dispatchEvent(new Event('resize'));})();"
        webView?.evaluateJavaScript(f1 + f2 + f3 + f4 + f5 + f6 + f7, completionHandler: nil)
    }

}
